import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:meshcore/meshcore.dart';

import 'ble_connector.dart';
import 'discovered_node.dart';
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
      } else if (s == MeshcoreConnectionState.reconnecting ||
          s == MeshcoreConnectionState.failed) {
        _maybeScheduleReconnect();
      }
    });
    _inboundSub = _connection.inbound.listen((MeshcoreInbound f) {
      _lastFrame = f;
      _ingestNode(f);
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

  String _hex(List<int> b) =>
      b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

  void _ingestNode(MeshcoreInbound f) {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (f is ContactFrame) {
      final Contact c = f.contact;
      _nodes[_hex(c.publicKey)] = DiscoveredNode(
        pubKeyHex: _hex(c.publicKey),
        name: c.name,
        type: c.type,
        lastHeardUnix:
            c.lastAdvertTimestamp == 0 ? now : c.lastAdvertTimestamp,
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
      lastHeardUnix: a.timestamp == 0 ? now : a.timestamp,
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
    } catch (_) {
      // Surface via state/error elsewhere; scan window still elapses.
    }
  }

  /// User-initiated disconnect. Latches off auto-reconnect until the
  /// next explicit [connect].
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectGen++; // cancel any pending scheduled retry
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
    _statesSub?.cancel();
    _inboundSub?.cancel();
    _rawSub?.cancel();
    unawaited(_transport?.close());
    unawaited(_connection.dispose());
    super.dispose();
  }
}
