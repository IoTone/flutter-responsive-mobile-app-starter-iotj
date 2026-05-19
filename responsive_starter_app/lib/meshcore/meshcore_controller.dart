import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:meshcore/meshcore.dart';

import 'ble_connector.dart';
import 'chat_message.dart';
import 'discovered_node.dart';
import 'mesh_event.dart';
import 'meshcore_connection.dart';
import 'paired_device_store.dart';
import 'reconnect_policy.dart';

/// App-facing facade over [MeshcoreConnection], exposed via Provider.
///
/// The transport is obtained through [transportFactory]; the default
/// scans/connects over BLE, but tests inject a fake transport so the
/// whole controller path is `flutter test`-covered without hardware.
class MeshcoreController extends ChangeNotifier {
  MeshcoreController({
    Future<MeshcoreTransport> Function()? transportFactory,
    MeshcoreConnection? connection,
    ReconnectPolicy? reconnectPolicy,
    Future<void> Function(Duration)? reconnectDelay,
  })  : _transportFactory =
            transportFactory ?? BleConnector.autoConnect,
        _connection = connection ?? MeshcoreConnection(),
        _reconnect = reconnectPolicy ?? ReconnectPolicy(),
        _delay = reconnectDelay ?? Future<void>.delayed {
    _statesSub = _connection.states.listen((MeshcoreConnectionState s) {
      _state = s;
      notifyListeners();
      if (s == MeshcoreConnectionState.ready) {
        _reconnectAttempt = 0;
        // These radios have no persistent RTC; without this every
        // device-sourced timestamp (contact last-heard, message
        // times) is in an unset clock, so "in range" and ordering
        // are meaningless. Standard companion-app behaviour.
        _syncDeviceTime();
        // Also READ the device clock: if SET_DEVICE_TIME is rejected
        // (some firmware returns ERR), we still learn the offset and
        // judge "in range" against the device's own clock.
        _requestDeviceTime();
        _startBatteryPolling();
        _probeChannels();
        // Drain anything the device queued before/while we connected
        // (heard contacts/adverts + received messages).
        _drainStart();
      } else if (s == MeshcoreConnectionState.reconnecting ||
          s == MeshcoreConnectionState.failed) {
        _maybeScheduleReconnect();
      }
    });
    _inboundSub = _connection.inbound.listen((MeshcoreInbound f) {
      _lastFrame = f;
      _trackDeviceClock(f);
      _trackBattery(f);
      _maybeDrain(f);
      _ingestNode(f);
      _ingestChat(f);
      _logEvent(f);
      notifyListeners();
    });
    _rawSub = _connection.rawInbound.listen((Uint8List bytes) {
      final String hex = bytes
          .map((int b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      _capture.add(hex);
      if (_capture.length > _captureCap) _capture.removeAt(0);
    });
  }

  /// Recent raw inbound frames (hex), newest last. Bounded ring buffer
  /// for the M6 interop capture workflow.
  final List<String> _capture = <String>[];
  static const int _captureCap = 256;
  StreamSubscription<Uint8List>? _rawSub;

  List<String> get captureLog => List<String>.unmodifiable(_capture);

  /// Most recent `0x88` RF-log frame hex, or null.
  String? get lastRfLogHex {
    for (int i = _capture.length - 1; i >= 0; i--) {
      if (_capture[i].startsWith('88')) return _capture[i];
    }
    return null;
  }

  /// Build a `grp_txt_capture` interop fixture (see
  /// `packages/meshcore/test/vectors/interop/SCHEMA.md`). Pass the
  /// captured `0x88` frame hex (default: [lastRfLogHex]).
  String exportGrpTxtFixture({
    required String pskHex,
    required String knownPlaintextUtf8,
    String channelName = 'Public',
    String description = '',
    String firmware = '',
    String? rfLogFrameHex,
  }) {
    final String? hex = rfLogFrameHex ?? lastRfLogHex;
    if (hex == null) {
      throw StateError('no 0x88 RF-log frame captured');
    }
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'kind': 'grp_txt_capture',
      'description': description,
      'firmware': firmware,
      'channel_name': channelName,
      'psk_hex': pskHex,
      'known_plaintext_utf8': knownPlaintextUtf8,
      'rf_log_frame_hex': hex,
    });
  }

  final Future<MeshcoreTransport> Function() _transportFactory;
  final MeshcoreConnection _connection;

  StreamSubscription<MeshcoreConnectionState>? _statesSub;
  StreamSubscription<MeshcoreInbound>? _inboundSub;
  MeshcoreTransport? _transport;

  final ReconnectPolicy _reconnect;
  final Future<void> Function(Duration) _delay;

  MeshcoreConnectionState _state = MeshcoreConnectionState.disconnected;
  MeshcoreInbound? _lastFrame;
  String? _error;
  bool _connecting = false;
  bool _manualDisconnect = false;
  bool _gaveUp = false;
  int _reconnectAttempt = 0;
  int _reconnectGen = 0;

  MeshcoreConnectionState get state => _state;
  MeshcoreInbound? get lastFrame => _lastFrame;
  SelfInfo? get selfInfo => _connection.selfInfo;
  String? get error => _error;
  bool get isConnecting => _connecting;
  bool get isReady => _state == MeshcoreConnectionState.ready;

  /// Number of reconnect attempts since the last successful link.
  int get reconnectAttempt => _reconnectAttempt;

  /// True once the reconnect policy has exhausted [ReconnectPolicy
  /// .maxAttempts] without recovering.
  bool get gaveUp => _gaveUp;

  void _maybeScheduleReconnect() {
    if (_manualDisconnect || _connecting) return;
    final int next = _reconnectAttempt + 1;
    if (!_reconnect.shouldRetry(next)) {
      if (!_gaveUp) {
        _gaveUp = true;
        notifyListeners();
      }
      return;
    }
    _reconnectAttempt = next;
    final int gen = _reconnectGen;
    final Duration d = _reconnect.delayForAttempt(next);
    unawaited(_delay(d).then((_) {
      // Drop stale schedules (a newer connect/disconnect superseded us).
      if (gen != _reconnectGen || _manualDisconnect || _connecting) return;
      if (_state == MeshcoreConnectionState.ready) return;
      unawaited(connect(isRetry: true));
    }));
  }

  /// Acquire a transport and start the handshake. Safe to call again
  /// after a failure. A user-initiated call ([isRetry] false) clears
  /// the manual-disconnect latch and resets the backoff.
  Future<void> connect({bool isRetry = false}) async {
    if (_connecting) return;
    _connecting = true;
    if (!isRetry) {
      _manualDisconnect = false;
      _gaveUp = false;
      _reconnectAttempt = 0;
      _reconnectGen++;
    }
    _error = null;
    notifyListeners();
    Object? failure;
    try {
      await _transport?.close();
      final MeshcoreTransport t = await _transportFactory();
      _transport = t;
      _connection.attach(t);
      // Success: the handshake now drives state via the connection
      // stream. Do NOT inspect _state here — that transition is
      // delivered asynchronously and would still read `failed`.
    } catch (e) {
      failure = e;
      _error = e.toString();
      _state = MeshcoreConnectionState.failed;
    }
    _connecting = false;
    notifyListeners();
    // Transport acquisition failed (the connection stream never sees
    // this, so drive the backoff from here).
    if (failure != null) _maybeScheduleReconnect();
  }

  /// Send a raw command frame (e.g. from [MeshcoreFrameCodec]).
  Future<void> send(Uint8List frame) => _connection.sendCommand(frame);

  // --- Discovery: nodes "in the area" (contacts + adverts) ---

  final Map<String, DiscoveredNode> _nodes = <String, DiscoveredNode>{};

  /// Discovered nodes, most-recently-heard first.
  List<DiscoveredNode> get nodes {
    final List<DiscoveredNode> v = _nodes.values.toList()
      ..sort((DiscoveredNode a, DiscoveredNode b) =>
          b.lastHeardUnix.compareTo(a.lastHeardUnix));
    return v;
  }

  // --- Recent activity feed (Dashboard) ---

  final List<MeshEvent> _events = <MeshEvent>[];
  static const int _eventsCap = 40;

  /// Recent decoded events, newest first.
  List<MeshEvent> get recentEvents => _events.reversed.toList();

  void _logEvent(MeshcoreInbound f) {
    String? text;
    if (f is AdvertFrame) {
      final Advert a = f.advert;
      text = 'advert · ${a.name ?? _hex(a.publicKey).substring(0, 8)}';
    } else if (f is ChannelMessageFrame) {
      final ChannelMessage m = f.message;
      text = 'ch${m.channelIdx} · "${m.text}"';
    } else if (f is ContactMessageFrame) {
      text = 'dm · "${f.message.text}"';
    } else if (f is ContactFrame) {
      text = 'contact · ${f.contact.name}';
    } else if (f is BatteryStorageFrame) {
      text = 'battery ${f.battery.batteryVolts.toStringAsFixed(2)}V';
    } else if (f is ErrorFrame) {
      text = 'device error (code ${f.code ?? '?'})';
    } else if (f is CurrentTimeFrame) {
      final int skew = _deviceClockOffsetSec.abs();
      text = skew > 5
          ? 'device clock read (offset ${_deviceClockOffsetSec}s)'
          : 'device clock in sync';
    } else if (f is MsgSentFrame) {
      text = 'msg sent (ack ${f.sent.expectedAck})';
    } else if (f is DeviceInfoFrame) {
      text = 'device ${f.info.firmwareVersion}';
    } else if (f is SelfInfoFrame) {
      text = 'self-info · ${f.selfInfo.name}';
    }
    if (text == null) return;
    _logEventText(text);
  }

  void _logEventText(String text) {
    _events.add(MeshEvent(text));
    if (_events.length > _eventsCap) _events.removeAt(0);
  }

  String _hex(List<int> b) =>
      b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

  // --- Channel chat (R6) ---

  final List<ChatMessage> _messages = <ChatMessage>[];
  static const int _messagesCap = 250;

  /// Known channels by index → name. Channel 0 ("Public") always
  /// exists; the rest are filled in from `CHANNEL_INFO` replies.
  final Map<int, String> _channels = <int, String>{0: 'Public'};

  /// Probe this many channel slots on link-up (typical meshes use a
  /// handful; the radio answers only the ones it has).
  static const int _channelProbeCount = 4;

  int _activeChannel = 0;

  /// Currently selected chat channel index.
  int get activeChannel => _activeChannel;

  /// Known channels, ascending by index.
  List<MapEntry<int, String>> get channels {
    final List<MapEntry<int, String>> v = _channels.entries.toList()
      ..sort((MapEntry<int, String> a, MapEntry<int, String> b) =>
          a.key.compareTo(b.key));
    return v;
  }

  /// Name of the active channel (falls back to its index).
  String get activeChannelName =>
      _channels[_activeChannel] ?? 'CH $_activeChannel';

  void setActiveChannel(int idx) {
    if (idx == _activeChannel) return;
    _activeChannel = idx;
    notifyListeners();
  }

  /// Messages for [idx] (default: the active channel), oldest first.
  List<ChatMessage> messagesFor([int? idx]) {
    final int c = idx ?? _activeChannel;
    return _messages
        .where((ChatMessage m) => m.channelIdx == c)
        .toList(growable: false);
  }

  final StreamController<ChatMessage> _incomingCh =
      StreamController<ChatMessage>.broadcast();

  /// Inbound channel messages (for TTS / notifications). Outgoing
  /// messages are not emitted here.
  Stream<ChatMessage> get incomingChannelMessages => _incomingCh.stream;

  void _addMessage(ChatMessage m) {
    _messages.add(m);
    if (_messages.length > _messagesCap) _messages.removeAt(0);
  }

  void _ingestChat(MeshcoreInbound f) {
    if (f is ChannelMessageFrame) {
      final ChannelMessage cm = f.message;
      final ChatMessage m = ChatMessage(
        channelIdx: cm.channelIdx,
        text: cm.text,
        outgoing: false,
        snrDb: cm.snrDb,
        isFlood: cm.isFlood,
      );
      _addMessage(m);
      if (!_incomingCh.isClosed) _incomingCh.add(m);
    } else if (f is ChannelInfoFrame) {
      final ChannelInfo ci = f.info;
      if (ci.name.isNotEmpty) _channels[ci.channelIdx] = ci.name;
    }
  }

  /// Set the device clock to the phone's wall clock so device-sourced
  /// timestamps (contact `lastAdvertTimestamp`, message times) are
  /// comparable to "now" — fixes nodes showing "known" but never
  /// "in range". Best-effort.
  void _syncDeviceTime() {
    final int nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    unawaited(
        send(MeshcoreFrameCodec.setDeviceTime(nowUnix)).catchError((_) {}));
  }

  /// Phone-clock minus device-clock, in seconds. 0 until a CURR_TIME
  /// reply is seen; once known it translates device-sourced
  /// timestamps (contact `lastAdvertTimestamp`) to phone "now" so
  /// "in range" is correct even when SET_DEVICE_TIME was rejected.
  int _deviceClockOffsetSec = 0;

  void _requestDeviceTime() {
    unawaited(
        send(MeshcoreFrameCodec.getDeviceTime()).catchError((_) {}));
  }

  void _trackDeviceClock(MeshcoreInbound f) {
    if (f is! CurrentTimeFrame || f.unixSeconds <= 0) return;
    final int phoneNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _deviceClockOffsetSec = phoneNow - f.unixSeconds;
    // Re-derive freshness for contacts that arrived before we knew
    // the offset (GET_CONTACTS reply can precede CURR_TIME).
    for (final DiscoveredNode n in _nodes.values) {
      final int? adv = n.deviceAdvertUnix;
      if (adv != null && adv != 0) {
        n.lastHeardUnix = adv + _deviceClockOffsetSec;
      }
    }
  }

  // --- Battery (R16) ---

  BatteryStorage? _battery;
  final List<List<int>> _battSamples = <List<int>>[]; // [mv, atUnix]
  static const int _battSampleCap = 6;
  bool? _charging;
  Timer? _battTimer;

  /// Latest battery/storage reading, null until the first GET_BATTERY.
  BatteryStorage? get battery => _battery;
  int? get batteryMillivolts => _battery?.batteryMillivolts;
  double? get batteryVolts => _battery?.batteryVolts;

  /// Approx single-cell Li-ion charge (3.30 V→0 %, 4.20 V→100 %).
  /// Indicative only — the companion protocol exposes voltage, not a
  /// fuel gauge.
  int? get batteryPercent {
    final int? mv = batteryMillivolts;
    if (mv == null) return null;
    return ((mv - 3300) / (4200 - 3300) * 100).clamp(0, 100).round();
  }

  /// True only on a clear, sustained voltage rise; false on a clear
  /// fall; null when steady/unknown. companion-v1.15.0 has no
  /// charge-state bit, so this never asserts charging on ADC noise
  /// (R16: never show a false charging state).
  bool? get charging => _charging;

  void _requestBattery() {
    unawaited(
        send(MeshcoreFrameCodec.getBatteryStorage()).catchError((_) {}));
  }

  void _startBatteryPolling() {
    _battTimer?.cancel();
    _requestBattery();
    _battTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (isReady) _requestBattery();
    });
  }

  void _trackBattery(MeshcoreInbound f) {
    if (f is! BatteryStorageFrame) return;
    _battery = f.battery;
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _battSamples.add(<int>[f.battery.batteryMillivolts, now]);
    if (_battSamples.length > _battSampleCap) _battSamples.removeAt(0);
    if (_battSamples.length >= 2) {
      final int newest = _battSamples.last[0];
      final int oldest = _battSamples.first[0];
      const int margin = 40; // mV — above ADC / temperature noise
      _charging = (newest - oldest) >= margin
          ? true
          : (oldest - newest) >= margin
              ? false
              : null;
    }
  }

  void _probeChannels() {
    for (int i = 0; i < _channelProbeCount; i++) {
      // Best-effort: ignore failures (radio replies only for the
      // channels it actually has configured).
      unawaited(send(MeshcoreFrameCodec.getChannel(i)).catchError((_) {}));
    }
  }

  /// Send a text message on the active channel (`SEND_CHANNEL_TXT_MSG`,
  /// 0x03). The radio does the OTA channel encryption; we append an
  /// optimistic outgoing line. No-op if not ready or text is blank.
  Future<void> sendChannelText(String text) async {
    final String t = text.trim();
    if (t.isEmpty || !isReady) return;
    final int ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await send(MeshcoreFrameCodec.sendChannelTextMessage(
      channelIdx: _activeChannel,
      timestamp: ts,
      text: t,
    ));
    _addMessage(ChatMessage(
      channelIdx: _activeChannel,
      text: t,
      outgoing: true,
    ));
    notifyListeners();
  }

  // --- Inbound queue drain (CMD_SYNC_NEXT_MESSAGE) ---
  //
  // The companion firmware does NOT push every received item in real
  // time. When it has queued inbound items (newly heard contacts /
  // adverts AND received text messages) it sends
  // `PUSH_CODE_MSGS_WAITING` (0x83); the app must then pull them one
  // at a time with `CMD_SYNC_NEXT_MESSAGE` until the device replies
  // `RESP_CODE_NO_MORE_MESSAGES`. Without this loop, discovered nodes
  // and incoming messages never reach the app.

  bool _draining = false;
  int _drainSteps = 0;
  static const int _drainStepCap = 512; // runaway guard

  void _drainStart() {
    if (_draining) return;
    _draining = true;
    _drainSteps = 0;
    _drainStep();
  }

  void _drainStep() {
    if (++_drainSteps > _drainStepCap) {
      _draining = false;
      return;
    }
    unawaited(send(MeshcoreFrameCodec.syncNextMessage()).catchError((_) {
      _draining = false;
    }));
  }

  void _maybeDrain(MeshcoreInbound f) {
    if (f is MessagesWaitingFrame) {
      _logEventText(
          'queued items waiting${f.count == null ? '' : ' (${f.count})'}');
      _drainStart();
      return;
    }
    if (!_draining) return;
    if (f is NoMoreMessagesFrame) {
      _draining = false; // queue emptied
    } else {
      // The frame we just received was the reply to our SYNC (a
      // queued contact/advert/message); pull the next one.
      _drainStep();
    }
  }

  void _ingestNode(MeshcoreInbound f) {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (f is ContactFrame) {
      final Contact c = f.contact;
      final int adv = c.lastAdvertTimestamp;
      // `adv` is in the device clock; translate via the learned
      // offset (0 until CURR_TIME, re-derived in _trackDeviceClock).
      _nodes[_hex(c.publicKey)] = DiscoveredNode(
        pubKeyHex: _hex(c.publicKey),
        name: c.name,
        type: c.type,
        lastHeardUnix: adv == 0 ? now : adv + _deviceClockOffsetSec,
        deviceAdvertUnix: adv == 0 ? null : adv,
        latitude: c.latitudeMicros == 0 ? null : c.latitudeMicros / 1e6,
        longitude: c.longitudeMicros == 0 ? null : c.longitudeMicros / 1e6,
        viaAdvert: false,
      );
    } else if (f is AdvertFrame) {
      _upsertAdvert(f.advert);
    } else if (f is RfLogFrame) {
      // RF-log captures carry the raw OTA packet *with* SNR/RSSI —
      // the signal needed to judge "what's in my area".
      final Advert? a = f.log.packet?.advert;
      if (a != null) {
        _upsertAdvert(a, snr: f.log.snrDb, rssi: f.log.rssi);
      }
    }
  }

  void _upsertAdvert(Advert a, {double? snr, int? rssi}) {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String k = _hex(a.publicKey);
    final DiscoveredNode? prev = _nodes[k];
    _nodes[k] = DiscoveredNode(
      pubKeyHex: k,
      name: a.name ?? prev?.name ?? k.substring(0, 8),
      type: a.type,
      // Receiving an advert push (0x80) or RF-log (0x88) means we
      // heard this node *now*. `a.timestamp` is the sender's clock at
      // advert creation — often unset/stale/skewed vs. the phone — so
      // it must NOT drive the "in range" freshness check.
      lastHeardUnix: now,
      latitude: a.latitude ?? prev?.latitude,
      longitude: a.longitude ?? prev?.longitude,
      snrDb: snr ?? prev?.snrDb,
      rssi: rssi ?? prev?.rssi,
      viaAdvert: true,
    );
  }

  /// Ask the radio for its synced contact list (`CMD_GET_CONTACTS`).
  Future<void> requestContacts() =>
      send(MeshcoreFrameCodec.getContacts());

  /// Broadcast our own advert so neighbours discover us.
  Future<void> sendSelfAdvert({bool flood = true}) =>
      send(MeshcoreFrameCodec.sendSelfAdvert(flood: flood));

  bool _scanning = false;
  Timer? _scanTimer;

  /// True while a [scan] is actively soliciting/collecting adverts.
  bool get isScanning => _scanning;

  /// Detect what's in the area: flood our advert (so neighbours
  /// respond) and pull the radio's contact list, then keep collecting
  /// inbound adverts. The window is just UI feedback — adverts keep
  /// arriving passively afterwards.
  Future<void> scan({
    Duration window = const Duration(seconds: 10),
  }) async {
    if (!isReady) return;
    _scanning = true;
    notifyListeners();
    _scanTimer?.cancel();
    _scanTimer = Timer(window, () {
      _scanning = false;
      notifyListeners();
    });
    try {
      await sendSelfAdvert(flood: true);
      await requestContacts();
      // Pull anything the device has already queued (heard adverts
      // may be sitting behind MSGS_WAITING, not pushed live).
      _drainStart();
    } catch (_) {
      // Surface via state/error elsewhere; scan window still elapses.
    }
  }

  /// User-initiated disconnect. Latches off auto-reconnect until the
  /// next explicit [connect].
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectGen++; // cancel any pending scheduled retry
    _battTimer?.cancel();
    await _transport?.close();
    _transport = null;
  }

  /// Label of the saved paired device (loaded lazily for the UI).
  String? get pairedName => _pairedName;
  String? _pairedName;
  bool get hasPairedDevice => _pairedName != null;

  /// Call once at startup: if a device was previously paired,
  /// auto-reconnect to it (direct connect, scan fallback). Safe to
  /// call when nothing is paired (no-op).
  Future<void> autoConnectIfPaired() async {
    final PairedDevice? p = await PairedDeviceStore.read();
    if (p == null) return;
    _pairedName = p.name;
    notifyListeners();
    await connect();
  }

  /// Forget the saved radio and disconnect — no more auto-reconnect
  /// until the user pairs again.
  Future<void> forgetDevice() async {
    await PairedDeviceStore.clear();
    _pairedName = null;
    await disconnect();
    notifyListeners();
  }

  @override
  void dispose() {
    _manualDisconnect = true;
    _reconnectGen++; // invalidate any pending scheduled retry
    _scanTimer?.cancel();
    _battTimer?.cancel();
    _statesSub?.cancel();
    _inboundSub?.cancel();
    _rawSub?.cancel();
    unawaited(_incomingCh.close());
    unawaited(_transport?.close());
    unawaited(_connection.dispose());
    super.dispose();
  }
}
