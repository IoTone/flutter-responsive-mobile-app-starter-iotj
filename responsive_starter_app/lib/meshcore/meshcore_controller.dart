// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:meshcore/meshcore.dart';

import 'background_keepalive.dart';
import 'background_prefs.dart';
import 'default_channel_store.dart';
import 'ble_connector.dart';
import 'chat_message.dart';
import 'chat_store.dart';
import 'discovered_node.dart';
import 'dm_read_store.dart';
import 'favorite_store.dart';
import 'known_store.dart';
import 'node_tags_store.dart';
import 'mesh_event.dart';
import 'meshcore_connection.dart';
import 'own_location.dart';
import 'coverage_store.dart';
import 'paired_device_history.dart';
import 'paired_device_store.dart';
import 'reconnect_policy.dart';
import '../perms/location_service.dart';
import '../util/geo.dart' as geo;

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
    BackgroundKeepalive? backgroundKeepalive,
    LocationService? locationService,
  })  : _transportFactory =
            transportFactory ?? BleConnector.autoConnect,
        _keepalive =
            backgroundKeepalive ?? const NoopBackgroundKeepalive(),
        _connection = connection ?? MeshcoreConnection(),
        _reconnect = reconnectPolicy ?? ReconnectPolicy(),
        _delay = reconnectDelay ?? Future<void>.delayed,
        _location = locationService ?? NoopLocationService() {
    _statesSub = _connection.states.listen((MeshcoreConnectionState s) {
      _state = s;
      notifyListeners();
      if (s == MeshcoreConnectionState.ready) {
        _reconnectAttempt = 0;
        // Post R41 bug fix: hydrate paired-name / -remote-id from
        // prefs every time we reach ready. BleConnector._finish has
        // already persisted the pairing by this point, but the
        // controller's cached fields are only set by
        // autoConnectIfPaired() / connectToPickedDevice() — neither
        // of which fires for a "Connect" tap on the dashboard slab
        // that goes through a fresh scan. Without this rehydrate
        // the Device sheet read "No device paired" right after a
        // successful manual connect.
        unawaited(_hydratePairedFromPrefs());
        // These radios have no persistent RTC; without this every
        // device-sourced timestamp (contact last-heard, message
        // times) is in an unset clock, so "in range" and ordering
        // are meaningless. Standard companion-app behaviour.
        _syncDeviceTime();
        // Also READ the device clock: if SET_DEVICE_TIME is rejected
        // (some firmware returns ERR), we still learn the offset and
        // judge "in range" against the device's own clock.
        _requestDeviceTime();
        _requestDeviceInfo();
        // R38 — read the device's custom-var map (gps, gps_interval,
        // …). Also: if the user already has advertLocPolicy=GPS but
        // the firmware's GPS module is disabled, auto-enable it so
        // `sensors.node_lat/lon` actually start tracking. This is
        // the silent on-boarding step the official companion app
        // performs.
        _requestCustomVars();
        _startBatteryPolling();
        _startSelfInfoPolling();
        _probeChannels();
        // Drain anything the device queued before/while we connected
        // (heard contacts/adverts + received messages).
        _drainStart();
        // Keep the process alive in the background so the link +
        // drain survive Doze (Android only; no-op elsewhere).
        if (_bgKeepaliveEnabled) unawaited(_keepalive.start());
        // R33 — if the user has a saved default channel slot,
        // switch to it now. The device persists its own active
        // slot too; this preference wins on app launch so a
        // user with multiple radios always lands on their
        // preferred slot rather than whatever each device
        // happens to remember. One-shot per ready transition
        // (subsequent in-session reconnects don't re-apply).
        if (!_appliedDefaultChannel) {
          _appliedDefaultChannel = true;
          unawaited(_applyDefaultChannel());
        }
      } else if (s == MeshcoreConnectionState.reconnecting ||
          s == MeshcoreConnectionState.failed) {
        _maybeScheduleReconnect();
      }
    });
    _inboundSub = _connection.inbound.listen((MeshcoreInbound f) {
      _lastFrame = f;
      _trackDeviceClock(f);
      _trackBattery(f);
      _trackDeviceInfo(f);
      _trackCustomVars(f);
      // R25+1 — own movement trail. Every inbound frame might have
      // bumped ownLocation (SelfInfoFrame's lat/lon), so sample
      // here. Deduped internally by movement threshold.
      _trackOwnLocationForTrail();
      _ingestKnown(f);
      _ingestDm(f);
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
    _loadChatHistory();
    _loadBackgroundPref();
    _loadDefaultChannel();
    _loadFavorites();
    _loadKnown();
    _loadTags();
    _loadCoverage();
    unawaited(_dmReadStore.load().then((_) {
      // Notify so any UI watching unread counts (Nodes badge, etc.)
      // re-renders once the persisted last-read timestamps are in.
      notifyListeners();
    }));
  }

  final DmReadStore _dmReadStore = DmReadStore();

  // --- "Known" nodes (R18) ---
  // Nodes we've had direct/attributable communication with (a
  // received DM, or a direct exchange) — drives the steady pulse on
  // the hyperlocal grid. Distinct from `favorites` (= "contacts",
  // rapid blink) and from the broader **fabric** of merely-seen
  // nodes.

  final Set<String> _known = <String>{};

  Set<String> get known => Set<String>.unmodifiable(_known);

  bool isKnown(String pubKeyHex) => _known.contains(pubKeyHex);

  Future<void> markKnown(String pubKeyHex) async {
    if (!_known.add(pubKeyHex)) return;
    notifyListeners();
    await KnownStore.save(_known);
  }

  Future<void> _loadKnown() async {
    final Set<String> v = await KnownStore.load();
    if (v.isEmpty) return;
    _known
      ..clear()
      ..addAll(v);
    notifyListeners();
  }

  // --- Favourites = "contacts" in the UX sense (R18 dependency) ---

  final Set<String> _favorites = <String>{};

  /// Read-only view of favourited node pubkey-hexes (the user's
  /// **contacts** in our UX sense; **fabric** = all seen).
  Set<String> get favorites => Set<String>.unmodifiable(_favorites);

  bool isFavorite(String pubKeyHex) => _favorites.contains(pubKeyHex);

  /// Toggle, persist, notify.
  Future<void> toggleFavorite(String pubKeyHex) async {
    if (!_favorites.add(pubKeyHex)) _favorites.remove(pubKeyHex);
    notifyListeners();
    await FavoriteStore.save(_favorites);
  }

  Future<void> _loadFavorites() async {
    final Set<String> v = await FavoriteStore.load();
    if (v.isEmpty) return;
    _favorites
      ..clear()
      ..addAll(v);
    notifyListeners();
  }

  // --- R28 — free-text tags per node ---
  //
  // Tags live alongside favourites but are orthogonal: a node can be
  // tagged "Mt. Hood Repeater" without being a favourite, and vice
  // versa. Multiple tags per node. Persisted as a single JSON blob.

  final Map<String, List<String>> _tags = <String, List<String>>{};

  /// Read-only view of every node's tag list. Empty list when the
  /// node has no tags (mirrors how `[]` is the natural "no tags"
  /// rendering).
  List<String> tagsFor(String pubKeyHex) =>
      List<String>.unmodifiable(_tags[pubKeyHex] ?? const <String>[]);

  /// Union of every tag ever attached anywhere, sorted for stable
  /// surface in autocomplete / "filter by tag" UI. Lowercased for
  /// dedup but original case preserved by picking the first variant.
  List<String> get allTags {
    final Map<String, String> seen = <String, String>{};
    for (final List<String> list in _tags.values) {
      for (final String t in list) {
        seen.putIfAbsent(t.toLowerCase(), () => t);
      }
    }
    final List<String> out = seen.values.toList()
      ..sort(
          (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  /// Add [tag] to [pubKeyHex]. Trimmed; case-insensitive dedup
  /// within the node (so "HAM" and "ham" can't coexist on the same
  /// node — the existing variant wins). No-op for empty input.
  Future<void> addTagTo(String pubKeyHex, String tag) async {
    final String t = tag.trim();
    if (t.isEmpty) return;
    final List<String> cur =
        List<String>.from(_tags[pubKeyHex] ?? const <String>[]);
    final String lower = t.toLowerCase();
    if (cur.any((String e) => e.toLowerCase() == lower)) return;
    cur.add(t);
    _tags[pubKeyHex] = cur;
    notifyListeners();
    await NodeTagsStore.save(_tags);
  }

  /// Remove [tag] from [pubKeyHex] (case-insensitive). No-op if not
  /// present. Drops the node from the map when its last tag goes so
  /// the persisted blob stays clean.
  Future<void> removeTagFrom(String pubKeyHex, String tag) async {
    final List<String>? cur = _tags[pubKeyHex];
    if (cur == null) return;
    final String lower = tag.trim().toLowerCase();
    final int before = cur.length;
    cur.removeWhere((String e) => e.toLowerCase() == lower);
    if (cur.length == before) return;
    if (cur.isEmpty) {
      _tags.remove(pubKeyHex);
    } else {
      _tags[pubKeyHex] = cur;
    }
    notifyListeners();
    await NodeTagsStore.save(_tags);
  }

  Future<void> _loadTags() async {
    final Map<String, List<String>> v = await NodeTagsStore.load();
    if (v.isEmpty) return;
    _tags
      ..clear()
      ..addAll(v);
    notifyListeners();
  }

  Future<void> _loadBackgroundPref() async {
    _bgKeepaliveEnabled = await BackgroundKeepalivePrefs.enabled();
    notifyListeners();
  }

  /// Whether the Android background keep-alive foreground service is
  /// enabled (R17 / U8). No-op on non-Android.
  bool get backgroundKeepaliveEnabled => _bgKeepaliveEnabled;

  Future<void> setBackgroundKeepaliveEnabled(bool v) async {
    _bgKeepaliveEnabled = v;
    notifyListeners();
    await BackgroundKeepalivePrefs.setEnabled(v);
    if (v && isReady) {
      await _keepalive.start();
    } else if (!v) {
      await _keepalive.stop();
    }
  }

  /// Restore persisted chat history (the protocol can't re-fetch it;
  /// the device queue is drained destructively). Loaded entries are
  /// older than anything received during the async gap, so they go
  /// at the front.
  Future<void> _loadChatHistory() async {
    final List<ChatMessage> hist = await ChatStore.load();
    if (hist.isEmpty) return;
    _messages.insertAll(0, hist);
    if (_messages.length > _messagesCap) {
      _messages.removeRange(0, _messages.length - _messagesCap);
    }
    _invalidateMessagesCache();
    notifyListeners();
  }

  void _persistChat() =>
      unawaited(ChatStore.save(List<ChatMessage>.from(_messages)));

  /// R20 / U11 — delete a single message **locally**. The OTA copy
  /// has already been delivered; MeshCore has no recall semantic, so
  /// the UI must convey that the remote/other recipients still have
  /// the message. Returns true if a row matched.
  bool deleteMessageById(String id) {
    final int before = _messages.length;
    _messages.removeWhere((ChatMessage m) => m.id == id);
    if (_messages.length == before) return false;
    _invalidateMessagesCache();
    _persistChat();
    notifyListeners();
    return true;
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
  final BackgroundKeepalive _keepalive;
  bool _bgKeepaliveEnabled = true; // default on (user-accepted)
  final MeshcoreConnection _connection;

  StreamSubscription<MeshcoreConnectionState>? _statesSub;
  StreamSubscription<MeshcoreInbound>? _inboundSub;
  MeshcoreTransport? _transport;

  final ReconnectPolicy _reconnect;
  final Future<void> Function(Duration) _delay;
  final LocationService _location;
  OwnLocation? _phoneFix;

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

  /// Our own node's 64-char pubkey hex (lower-case, no spaces), or
  /// `null` until `SelfInfo` arrives. Used to filter ourselves out
  /// of the fabric on /grid and the Nodes list (we don't want to
  /// DM ourselves) and to suppress the Message action in
  /// `NodeDetailSheet` when the tapped node IS us.
  String? get ownPubKeyHex {
    final SelfInfo? si = selfInfo;
    if (si == null) return null;
    final StringBuffer b = StringBuffer();
    for (final int byte in si.publicKey) {
      b.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }

  /// Own location resolved **device-first**, then phone-fallback.
  /// The MeshCore `SelfInfo` response carries a `latitude`/`longitude`
  /// pair which the device populates from its onboard GPS (or from a
  /// manually-pinned advert location). We treat exactly `(0, 0)` as
  /// unset — the canonical "no fix yet" sentinel the firmware
  /// initialises to.
  ///
  /// When the device reports unset (or hasn't responded yet), we
  /// fall back to a one-shot phone fix captured by
  /// [requestPhoneLocationFix] (Phase B / R22).
  OwnLocation? get ownLocation {
    final SelfInfo? si = selfInfo;
    if (si != null &&
        !(si.latitude.abs() < 1e-9 && si.longitude.abs() < 1e-9)) {
      return OwnLocation(
        latitude: si.latitude,
        longitude: si.longitude,
        // SelfInfo doesn't carry altitude over the wire (the
        // companion protocol has lat/lon only), so we borrow the
        // most-recent phone-GPS altitude when one is cached.
        // The phone is in our hand at roughly the same elevation
        // as the paired device — close enough for the elevation-
        // profile view and any "altitude readout" UI.
        altitudeMeters: _phoneFix?.altitudeMeters,
        source: OwnLocationSource.deviceReported,
      );
    }
    return _phoneFix;
  }

  /// The cached one-shot phone-GPS fix, if any. Cleared by
  /// [clearPhoneLocationFix]. Used as the fallback inside
  /// [ownLocation] when the device hasn't reported a fix.
  OwnLocation? get phoneLocationFix => _phoneFix;

  /// R22 / U13 — capture a single phone-GPS fix and cache it as
  /// our fallback own-location. The caller is expected to have
  /// already obtained the location permission (typically via
  /// `PermissionsService.requestLocation`); this method just talks
  /// to the [LocationService]. Returns true on success.
  Future<bool> requestPhoneLocationFix({
    Duration timeLimit = const Duration(seconds: 15),
  }) async {
    final PhoneFix? fix = await _location.currentFix(timeLimit: timeLimit);
    if (fix == null) return false;
    _phoneFix = OwnLocation(
      latitude: fix.latitude,
      longitude: fix.longitude,
      altitudeMeters: fix.altitudeMeters,
      source: OwnLocationSource.phoneFix,
    );
    // R25+1 — record into the trail. Phone fixes are a primary
    // source of ownLocation when the device GPS is off or stale.
    _trackOwnLocationForTrail();
    notifyListeners();
    return true;
  }

  /// Wipes the cached phone fix (so [ownLocation] reverts to
  /// device-reported, or null if neither is available).
  void clearPhoneLocationFix() {
    if (_phoneFix == null) return;
    _phoneFix = null;
    notifyListeners();
  }

  /// Cache an externally-acquired [PhoneFix] as our phone-side
  /// own-location. Used by `AutoPublishController` (R36) which
  /// already calls `_location.currentFix()` periodically — pumping
  /// every fix through here means `ownLocation.altitudeMeters` and
  /// the elevation-profile view stay live without a dedicated
  /// background subscription. Dedup is cheap because the same
  /// PhoneFix re-cached is a no-op aside from notifyListeners.
  void cachePhoneFix(PhoneFix fix) {
    _phoneFix = OwnLocation(
      latitude: fix.latitude,
      longitude: fix.longitude,
      altitudeMeters: fix.altitudeMeters,
      source: OwnLocationSource.phoneFix,
    );
    _trackOwnLocationForTrail();
    notifyListeners();
  }

  /// Great-circle distance (m) from our own location to the given
  /// point, or `null` when we don't have an own location yet.
  /// Lazy by construction — call this from a `ListView.builder`
  /// row and only visible rows pay the (microsecond) cost.
  double? distanceMetersTo(double targetLat, double targetLon) {
    final OwnLocation? own = ownLocation;
    if (own == null) return null;
    return geo.haversineMeters(
        own.latitude, own.longitude, targetLat, targetLon);
  }

  // --- R25+1 movement trail ---------------------------------------
  //
  // Rolling in-memory record of our own GPS fixes, used by the
  // equal-grid view to draw a "where I've been" polyline. Trail
  // grows passively as new ownLocation samples arrive (called from
  // _trackOwnLocationForTrail in the inbound listener); deduped by
  // movement so a stationary device doesn't fill the buffer with
  // identical points.
  //
  // Buffer is capped to keep the polyline render cheap and the
  // memory footprint trivial — at the default cap of 60 points and
  // 25 m dedup threshold that's roughly 1.5 km of recent path.

  static const int _trailCap = 60;
  static const double _trailMinMoveMeters = 25.0;
  final List<({double latitude, double longitude, int unixSec})>
      _ownTrail =
      <({double latitude, double longitude, int unixSec})>[];

  /// Read-only view of the most-recent own-location samples, oldest
  /// first. Empty until at least one ownLocation has been resolved.
  List<({double latitude, double longitude, int unixSec})>
      get ownTrail => List<
              ({
                double latitude,
                double longitude,
                int unixSec
              })>.unmodifiable(_ownTrail);

  /// Append the current ownLocation to [_ownTrail] if it has moved
  /// > [_trailMinMoveMeters] from the last sample. Safe to call on
  /// every inbound frame; cheap when no movement happened.
  void _trackOwnLocationForTrail() {
    final OwnLocation? own = ownLocation;
    if (own == null) return;
    if (_ownTrail.isNotEmpty) {
      final last = _ownTrail.last;
      final double d = geo.haversineMeters(
          last.latitude, last.longitude, own.latitude, own.longitude);
      if (d < _trailMinMoveMeters) return;
    }
    _ownTrail.add((
      latitude: own.latitude,
      longitude: own.longitude,
      unixSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ));
    while (_ownTrail.length > _trailCap) {
      _ownTrail.removeAt(0);
    }
    // F8 — every sampled own-location is a "the mesh reaches here"
    // observation, since the trail only updates while we have a
    // working link to the device.
    _recordCoverage(own.latitude, own.longitude);
  }

  // --- F8 coverage map -------------------------------------------
  //
  // Persistent record of cells where we've observed mesh activity.
  // Each inbound frame contributes a cell (we know the mesh exists
  // somewhere reachable while we're online) and each known peer's
  // lat/lon contributes a cell (the mesh extends to where they are).
  // Stored as `Map<cellKey, lastObservedUnix>` so the FabricSurveyView
  // can fade older cells.

  final Map<String, int> _coverage = <String, int>{};
  bool _coverageDirty = false;
  Timer? _coverageSaveTimer;

  /// Read-only snapshot of observed coverage cells, keyed by
  /// `latBucket,lonBucket` strings (see [CoverageStore.cellKey]).
  /// Each value is the most-recent UNIX-second timestamp the cell
  /// was observed.
  Map<String, int> get coverageCells =>
      Map<String, int>.unmodifiable(_coverage);

  Future<void> _loadCoverage() async {
    final Map<String, int> v = await CoverageStore.load();
    if (v.isEmpty) return;
    _coverage
      ..clear()
      ..addAll(v);
    notifyListeners();
  }

  /// Wipe the coverage record. Used by tests + a "reset coverage"
  /// affordance in the FabricSurveyView's overflow menu.
  Future<void> resetCoverage() async {
    _coverage.clear();
    _coverageDirty = false;
    _coverageSaveTimer?.cancel();
    await CoverageStore.clear();
    notifyListeners();
  }

  /// Record a single observation. Bucketed by [CoverageStore.cellDeg];
  /// repeated calls on the same cell within a second are a no-op
  /// (timestamp resolution). Persistence is batched on a 5-second
  /// timer so a long drive doesn't pound shared_preferences.
  void _recordCoverage(double lat, double lon) {
    final ({int latBucket, int lonBucket}) b =
        CoverageStore.bucketFor(lat, lon);
    final String key = CoverageStore.cellKey(b.latBucket, b.lonBucket);
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_coverage[key] == now) return;
    _coverage[key] = now;
    while (_coverage.length > CoverageStore.maxCells) {
      // Drop the oldest entry by min-timestamp scan. O(N) per
      // eviction but only happens when we overflow the cap.
      String? oldestKey;
      int oldestTs = 1 << 62;
      _coverage.forEach((String k, int t) {
        if (t < oldestTs) {
          oldestTs = t;
          oldestKey = k;
        }
      });
      if (oldestKey == null) break;
      _coverage.remove(oldestKey);
    }
    _coverageDirty = true;
    _coverageSaveTimer ??= Timer(
        const Duration(seconds: 5), _flushCoveragePersist);
  }

  Future<void> _flushCoveragePersist() async {
    _coverageSaveTimer = null;
    if (!_coverageDirty) return;
    _coverageDirty = false;
    await CoverageStore.save(_coverage);
  }

  /// Spatial-aware "is this node nearby?" classification used by the
  /// IN RANGE / FAR badges. See [NodeProximity] for the band
  /// definitions. The temporal-only `recentlyHeard` fallback only
  /// fires when neither side has GPS — once we have both, distance
  /// alone decides.
  ///
  /// Thresholds picked from LoRa practical-reach experience: 10 km
  /// is comfortably "in your area" even on narrow-band tuples; 50 km
  /// is well beyond a typical direct link, so labelling those as
  /// FAR is informative.
  static const double _nearThresholdMeters = 10000;
  static const double _farThresholdMeters = 50000;

  NodeProximity proximityFor(DiscoveredNode n) {
    if (n.hasLocation) {
      final double? d = distanceMetersTo(n.latitude!, n.longitude!);
      if (d != null) {
        if (d < _nearThresholdMeters) return NodeProximity.near;
        if (d > _farThresholdMeters) return NodeProximity.far;
        return NodeProximity.mid;
      }
    }
    // No spatial info — fall back to recency. Calling
    // n.recentlyHeard avoids the deprecated alias warning.
    if (n.recentlyHeard) return NodeProximity.recent;
    return NodeProximity.unknown;
  }
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
    MeshEvent? ev;
    if (f is AdvertFrame) {
      final Advert a = f.advert;
      ev = MeshEvent(kind: MeshEventKind.advert, args: <String, String>{
        'name': a.name ?? _hex(a.publicKey).substring(0, 8),
      });
    } else if (f is ChannelMessageFrame) {
      final ChannelMessage m = f.message;
      ev = MeshEvent(
          kind: MeshEventKind.channelMsg,
          args: <String, String>{
            'channel': '${m.channelIdx}',
            'text': m.text,
          });
    } else if (f is ContactMessageFrame) {
      ev = MeshEvent(kind: MeshEventKind.dm, args: <String, String>{
        'text': f.message.text,
      });
    } else if (f is ContactFrame) {
      ev = MeshEvent(kind: MeshEventKind.contact, args: <String, String>{
        'name': f.contact.name,
      });
    } else if (f is BatteryStorageFrame) {
      ev = MeshEvent(kind: MeshEventKind.battery, args: <String, String>{
        'volts': f.battery.batteryVolts.toStringAsFixed(2),
      });
    } else if (f is ErrorFrame) {
      // Squelch the recent-activity surface for ERRs we know we
      // caused with a probing setCustomVar (e.g. writing
      // `gps_interval` on firmware where the sensors module
      // doesn't accept it returns ILLEGAL_ARG). Logging-only
      // — the codec error is still observable to anyone watching
      // the raw inbound stream.
      if (_squelchNextDeviceError > 0) {
        _squelchNextDeviceError--;
        // ignore: avoid_print
        print(
            '[meshcore] squelching expected device ERR code=${f.code}');
        return;
      }
      ev = MeshEvent(
          kind: MeshEventKind.deviceError,
          args: <String, String>{'code': '${f.code ?? '?'}'});
    } else if (f is CurrentTimeFrame) {
      final int skew = _deviceClockOffsetSec.abs();
      ev = skew > 5
          ? MeshEvent(
              kind: MeshEventKind.deviceClockSkew,
              args: <String, String>{
                'seconds': '$_deviceClockOffsetSec',
              })
          : MeshEvent(kind: MeshEventKind.deviceClockSynced);
    } else if (f is MsgSentFrame) {
      ev = MeshEvent(kind: MeshEventKind.msgSent, args: <String, String>{
        'ack': '${f.sent.expectedAck}',
      });
    } else if (f is DeviceInfoFrame) {
      ev = MeshEvent(
          kind: MeshEventKind.deviceInfo,
          args: <String, String>{'version': f.info.firmwareVersion});
    } else if (f is SelfInfoFrame) {
      final SelfInfo si = f.selfInfo;
      // print() so it routes to I/flutter on Android → captured by
      // `flutter logs`. developer.log was silent in the previous
      // field log capture.
      // ignore: avoid_print
      print('[meshcore.loc] SelfInfoFrame in: '
          'lat=${si.latitude} lon=${si.longitude} '
          'pol=${si.advertLocPolicy} name=${si.name}');
      ev = MeshEvent(kind: MeshEventKind.selfInfo, args: <String, String>{
        'name': si.name,
      });
    }
    if (ev == null) return;
    _pushEvent(ev);
  }

  /// Append an event to the rolling RECENT-feed buffer.
  void _pushEvent(MeshEvent ev) {
    _events.add(ev);
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

  /// Cache of the **per-slot 16-byte PSK** as reported by the device
  /// (RESP_CODE_CHANNEL_INFO). Lets the Edit dialog reveal the
  /// current key for a slot without a second device round-trip.
  /// Slot 0 (Public) is pre-seeded so we never have to ask the
  /// device for the well-known key.
  final Map<int, List<int>> _channelPsks = <int, List<int>>{
    0: List<int>.unmodifiable(kPublicChannelPsk),
  };

  /// 16-byte AES-128 PSK currently set on [idx], or null if we
  /// haven't observed a `ChannelInfoFrame` for that slot yet.
  /// The list is unmodifiable; copy if you need to mutate.
  List<int>? channelPsk(int idx) => _channelPsks[idx];

  /// Probe this many channel slots on link-up (typical meshes use a
  /// handful; the radio answers only the ones it has).
  static const int _channelProbeCount = 4;

  int _activeChannel = 0;

  /// Currently selected chat channel index.
  int get activeChannel => _activeChannel;

  /// Cached sorted view of `_channels`. Invalidated whenever the
  /// underlying map mutates, so `context.select<MC, channels>` can
  /// short-circuit rebuilds when the channel list is unchanged.
  List<MapEntry<int, String>>? _channelsCache;

  void _invalidateChannelsCache() => _channelsCache = null;

  /// Known channels, ascending by index.
  List<MapEntry<int, String>> get channels {
    final List<MapEntry<int, String>>? cached = _channelsCache;
    if (cached != null) return cached;
    final List<MapEntry<int, String>> v = _channels.entries.toList()
      ..sort((MapEntry<int, String> a, MapEntry<int, String> b) =>
          a.key.compareTo(b.key));
    _channelsCache = v;
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

  // R33 — user-preferred default channel slot to land on at app
  // launch. `_appliedDefaultChannel` latches so we only apply the
  // preference once per controller lifetime (i.e. once per cold
  // launch); mid-session reconnects keep whatever the user has
  // since switched to.
  int? _defaultChannelIdx;
  bool _appliedDefaultChannel = false;

  int? get defaultChannelIdx => _defaultChannelIdx;

  /// True iff [idx] is the user-saved default slot.
  bool isDefaultChannel(int idx) => _defaultChannelIdx == idx;

  /// Persist [idx] as the default slot. Pass `null` to clear the
  /// preference. Does not change the active slot live; the new
  /// default applies on the next cold launch (when the device
  /// reaches `ready` and `_applyDefaultChannel` runs).
  Future<void> setDefaultChannelIdx(int? idx) async {
    if (idx == _defaultChannelIdx) return;
    _defaultChannelIdx = idx;
    notifyListeners();
    await DefaultChannelStore.write(idx);
  }

  /// Pre-load the saved default so the Channels-mgmt UI can show
  /// the "★ default" indicator before the device has connected.
  Future<void> _loadDefaultChannel() async {
    _defaultChannelIdx = await DefaultChannelStore.read();
    notifyListeners();
  }

  /// One-shot at first reach-ready: if a default slot has been
  /// saved, switch the active channel to it. No-op if the
  /// preference is unset or already matches.
  Future<void> _applyDefaultChannel() async {
    final int? saved = _defaultChannelIdx ?? await DefaultChannelStore.read();
    if (saved == null) return;
    if (saved != _activeChannel) setActiveChannel(saved);
  }

  /// Create/overwrite a channel slot (`SET_CHANNEL` 0x20) then refresh
  /// it (`GET_CHANNEL`). [psk] is the 16-byte channel key. No-op if
  /// not connected.
  Future<void> setChannel({
    required int idx,
    required String name,
    required List<int> psk,
  }) async {
    if (!isReady) return;
    await send(MeshcoreFrameCodec.setChannel(
        channelIdx: idx, name: name, psk: psk));
    if (name.isNotEmpty) {
      _channels[idx] = name; // optimistic
      _invalidateChannelsCache();
    }
    // Optimistic PSK cache — the GET_CHANNEL below will confirm.
    _channelPsks[idx] = List<int>.unmodifiable(psk);
    notifyListeners();
    unawaited(send(MeshcoreFrameCodec.getChannel(idx)).catchError((_) {}));
  }

  /// "Clear" a slot. The companion protocol has no destructive
  /// `CLEAR_CHANNEL` opcode, so the pragmatic implementation is to
  /// overwrite the slot back to the well-known Public defaults
  /// (`"Public"` + `kPublicChannelPsk`). For slot 0 this is a no-op
  /// since that's already the Public channel; for higher slots it
  /// makes them indistinguishable from a fresh device and lets the
  /// shared Public channel work through that slot too.
  Future<void> clearChannel(int idx) async {
    if (!isReady) return;
    await setChannel(
      idx: idx,
      name: 'Public',
      psk: List<int>.from(kPublicChannelPsk),
    );
  }

  /// Per-channel cache of the filtered message list. Filled lazily on
  /// `messagesFor`; invalidated on every `_messages` mutation. Returning
  /// a stable list ref lets `Selector` / `context.select` short-circuit
  /// rebuilds when nothing on that channel changed.
  final Map<int, List<ChatMessage>> _messagesByChannel =
      <int, List<ChatMessage>>{};

  void _invalidateMessagesCache([int? idx]) {
    if (idx == null) {
      _messagesByChannel.clear();
    } else {
      _messagesByChannel.remove(idx);
    }
  }

  /// Messages for [idx] (default: the active channel), oldest first.
  /// Cached per channel; the cache is invalidated whenever the
  /// underlying `_messages` list mutates.
  List<ChatMessage> messagesFor([int? idx]) {
    final int c = idx ?? _activeChannel;
    return _messagesByChannel.putIfAbsent(
        c,
        () => _messages
            .where((ChatMessage m) => m.channelIdx == c)
            .toList(growable: false));
  }

  final StreamController<ChatMessage> _incomingCh =
      StreamController<ChatMessage>.broadcast();

  /// Inbound channel messages (for TTS / notifications). Outgoing
  /// messages are not emitted here.
  Stream<ChatMessage> get incomingChannelMessages => _incomingCh.stream;

  /// Operations that failed (send / advert / scan / set-* throws).
  /// `CueBridge` listens to this and fires `CueKind.taskError`.
  /// Emitted as the operation name (e.g. "sendChannel", "sendDm",
  /// "scan", "advert") so callers can label snackbars too.
  final StreamController<String> _taskErrors =
      StreamController<String>.broadcast();
  Stream<String> get taskErrors => _taskErrors.stream;

  /// Convenience for code paths that want to flag a failure without
  /// throwing into the void.
  void _emitTaskError(String op) {
    if (!_taskErrors.isClosed) _taskErrors.add(op);
  }

  void _addMessage(ChatMessage m) {
    _messages.add(m);
    if (_messages.length > _messagesCap) {
      _messages.removeAt(0);
      // The cap-eviction may have removed a row from any channel,
      // not just `m.channelIdx`. Conservative: clear the whole cache
      // when we evict; otherwise just invalidate the affected slot.
      _invalidateMessagesCache();
    } else {
      _invalidateMessagesCache(m.channelIdx);
    }
    _persistChat();
  }

  // --- Direct messages (P2P) ---

  final StreamController<ChatMessage> _incomingDm =
      StreamController<ChatMessage>.broadcast();

  /// Inbound DMs (broadcast). Outgoing DMs are NOT emitted here.
  Stream<ChatMessage> get incomingDirectMessages => _incomingDm.stream;

  /// All DM messages for a peer (by full pubkey hex, or 12-hex
  /// prefix when only the prefix was resolvable on receive), oldest
  /// first.
  List<ChatMessage> dmHistoryFor(String peerPubKeyHex) {
    final String prefix = peerPubKeyHex.length >= 12
        ? peerPubKeyHex.substring(0, 12)
        : peerPubKeyHex;
    return _messages
        .where((ChatMessage m) =>
            m.peerPubKeyHex != null &&
            (m.peerPubKeyHex == peerPubKeyHex ||
                m.peerPubKeyHex == prefix))
        .toList(growable: false);
  }

  /// Total count of DM messages exchanged with a peer (incoming +
  /// outgoing). Used by the Nodes screen to render the per-row
  /// "💬 N" badge — Option D DM-presence surfacing.
  int dmCountFor(String peerPubKeyHex) =>
      dmHistoryFor(peerPubKeyHex).length;

  /// Count of **inbound** DMs from this peer that arrived after the
  /// last time we marked the thread read. Drives the unread state of
  /// the Nodes-row DM badge.
  int unreadDmCountFor(String peerPubKeyHex) {
    final int last = _dmReadStore.lastReadAtMs(peerPubKeyHex);
    int n = 0;
    for (final ChatMessage m in dmHistoryFor(peerPubKeyHex)) {
      if (m.outgoing) continue;
      if (m.at.millisecondsSinceEpoch > last) n++;
    }
    return n;
  }

  /// Mark all current DM messages with [peerPubKeyHex] as read. Called
  /// from `DmScreen.initState` so opening a thread clears its unread
  /// badge. Fire-and-forget — never blocks the UI.
  void markDmRead(String peerPubKeyHex) {
    unawaited(_dmReadStore.markRead(peerPubKeyHex).then((_) {
      notifyListeners();
    }));
  }

  /// Send a DM (`CMD_SEND_TXT_MSG` 0x02, addressed by 6-byte pubkey
  /// prefix). Optimistically appends an outgoing line. No-op if not
  /// ready, text is blank, or the peer hex is shorter than 12 chars.
  Future<void> sendDirectText(
      String peerPubKeyHex, String text) async {
    final String t = text.trim();
    if (t.isEmpty || !isReady || peerPubKeyHex.length < 12) return;
    final List<int> prefix = <int>[
      for (int i = 0; i < 12; i += 2)
        int.parse(peerPubKeyHex.substring(i, i + 2), radix: 16),
    ];
    final int ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      await send(MeshcoreFrameCodec.sendTextMessage(
        pubKeyPrefix: prefix,
        timestamp: ts,
        text: t,
      ));
    } catch (_) {
      _emitTaskError('sendDm');
      return;
    }
    _addMessage(ChatMessage(
      channelIdx: -1,
      text: t,
      outgoing: true,
      peerPubKeyHex: peerPubKeyHex,
    ));
    notifyListeners();
  }

  /// Ingest an inbound DM into the message store + emit on the
  /// stream. Resolves the 6-byte sender prefix to a known fabric
  /// node's full pubkey if possible; falls back to storing under
  /// the 12-hex prefix.
  void _ingestDm(MeshcoreInbound f) {
    if (f is! ContactMessageFrame) return;
    final ContactMessage cm = f.message;
    final String prefixHex = _hex(cm.pubKeyPrefix);
    String? peer;
    for (final DiscoveredNode n in _nodes.values) {
      if (n.pubKeyHex.startsWith(prefixHex)) {
        peer = n.pubKeyHex;
        break;
      }
    }
    final ChatMessage m = ChatMessage(
      channelIdx: -1,
      text: cm.text,
      outgoing: false,
      snrDb: cm.snrDb,
      isFlood: cm.isFlood,
      peerPubKeyHex: peer ?? prefixHex,
    );
    _addMessage(m);
    if (!_incomingDm.isClosed) _incomingDm.add(m);
  }

  /// On a received DM (`ContactMessageFrame`), mark any fabric node
  /// whose pubkey starts with the sender's 6-byte prefix as **known**
  /// (R18: direct/attributable comms → pulse on the grid). If no
  /// matching node yet exists, the mark won't apply until the contact
  /// is surfaced (a future polish could queue pending prefixes).
  void _ingestKnown(MeshcoreInbound f) {
    if (f is! ContactMessageFrame) return;
    final String prefix = _hex(f.message.pubKeyPrefix);
    bool changed = false;
    for (final DiscoveredNode n in _nodes.values) {
      if (n.pubKeyHex.startsWith(prefix) &&
          !_known.contains(n.pubKeyHex)) {
        _known.add(n.pubKeyHex);
        changed = true;
      }
    }
    if (changed) unawaited(KnownStore.save(_known));
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
      if (ci.name.isNotEmpty) {
        _channels[ci.channelIdx] = ci.name;
        _invalidateChannelsCache();
      }
      // Cache the PSK so the Edit dialog can offer "Show current
      // key" without re-querying the device every time. The codec
      // carries 16 bytes — the AES-128 key. We store a defensive
      // copy because Uint8List can be a view.
      _channelPsks[ci.channelIdx] = List<int>.unmodifiable(ci.psk);
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

  /// SelfInfo refresh timer. The MeshCore companion protocol doesn't
  /// auto-push fresh SelfInfo when the device's onboard GPS updates,
  /// so a long-running session with `advertLocPolicy = Device GPS`
  /// would show a frozen location on the dashboard. Earlier we
  /// re-sent `appStart` here, but field testing showed the firmware
  /// returns a **cached** SelfInfo to appStart — the lat/lon only
  /// refreshes when the device actually **builds an outbound
  /// advert** (which is when it reads GPS into the advert payload).
  ///
  /// The refresh sequence is now: zero-hop `sendSelfAdvert`
  /// (forces firmware to read GPS into the just-built advert) +
  /// `appStart` (pulls the freshly-updated SelfInfo back). Cadence
  /// is 60 s — bigger than the old 30 s because the advert is
  /// actual OTA traffic (single zero-hop frame, no flood, low
  /// impact but real).
  Timer? _selfInfoTimer;

  void _startSelfInfoPolling() {
    _selfInfoTimer?.cancel();
    _selfInfoTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (isReady) unawaited(refreshSelfInfo());
    });
  }

  /// Public API for forcing a SelfInfo refresh from the device.
  /// Sends a **zero-hop self-advert** to force the firmware to
  /// re-read its GPS into the advert payload, then `appStart` to
  /// pull the refreshed SelfInfoFrame back through the inbound
  /// listener. Safe to call repeatedly; errors are swallowed.
  Future<void> refreshSelfInfo() async {
    if (!isReady) return;
    final SelfInfo? before = selfInfo;
    // ignore: avoid_print
    print('[meshcore.loc] refreshSelfInfo fired '
        '(before: ${before == null ? 'null' : 'lat=${before.latitude} '
            'lon=${before.longitude} pol=${before.advertLocPolicy}'})');
    // **Option B** — re-send the *existing* advertLocPolicy as a
    // no-op `setOtherParams` call. The v37 trace showed the
    // firmware returning byte-identical SelfInfo across multiple
    // sendSelfAdvert+appStart cycles, suggesting the advert build
    // doesn't actually re-read GPS. Some firmware variants do
    // refresh GPS into selfInfo when handling `setOtherParams`
    // though — sending the same policy back as a no-op may shake
    // the cache loose without changing any state.
    if (before != null) {
      await setAdvertLocPolicy(before.advertLocPolicy)
          .catchError((_) {});
    }
    // 1) Zero-hop advert triggers firmware GPS read + state update
    //    (theoretically — confirmed by the v37 capture that this
    //    alone wasn't enough).
    await sendSelfAdvert(flood: false).catchError((_) {});
    // 2) appStart re-fetches the SelfInfo response.
    await send(MeshcoreFrameCodec.appStart(
      appName: _connection.appName,
    )).catchError((_) {});
  }

  // --- Device info + identity/advert (R7) ---

  DeviceInfo? _deviceInfo;

  /// Decoded DEVICE_INFO (firmware/build/manufacturer/limits), null
  /// until the DEVICE_QUERY reply arrives.
  DeviceInfo? get deviceInfo => _deviceInfo;

  void _requestDeviceInfo() {
    unawaited(
        send(MeshcoreFrameCodec.deviceQuery()).catchError((_) {}));
  }

  void _trackDeviceInfo(MeshcoreInbound f) {
    if (f is DeviceInfoFrame) _deviceInfo = f.info;
  }

  // --- R38: device custom variables (gps, gps_interval, …) ---
  //
  // The companion-radio firmware stores a handful of string-keyed
  // settings outside the SelfInfo bundle, queried via
  // `CMD_GET_CUSTOM_VARS` (0x28) and written one at a time with
  // `CMD_SET_CUSTOM_VAR` (0x29). The two we care about today are
  // `gps` (0/1, powers the on-board GPS module) and `gps_interval`
  // (seconds 0..86400, how often the module is polled into
  // `sensors.node_lat/lon`). Other names are surfaced verbatim so
  // future firmware additions show up in the diagnostics panel
  // without code changes.

  Map<String, String> _customVars = const <String, String>{};

  /// Counter: when > 0, the next inbound ErrorFrame is dropped from
  /// the recent-activity feed (still surfaced in raw inbound + logs).
  /// Used to absorb known-rejectable probes like setting
  /// `gps_interval` on firmware that doesn't expose the key.
  int _squelchNextDeviceError = 0;

  /// Latest device-reported custom vars (e.g. `{gps: "1",
  /// gps_interval: "30"}`). Empty until the first
  /// `CMD_GET_CUSTOM_VARS` reply.
  Map<String, String> get customVars =>
      Map<String, String>.unmodifiable(_customVars);

  /// True iff the device reports `gps=1`. Null when the device hasn't
  /// answered the custom-var query yet (or doesn't have the key).
  bool? get deviceGpsEnabled {
    final String? v = _customVars['gps'];
    if (v == null) return null;
    return v.trim() == '1';
  }

  /// Device GPS polling interval (seconds), or null if unknown.
  int? get deviceGpsIntervalSec {
    final String? v = _customVars['gps_interval'];
    if (v == null) return null;
    return int.tryParse(v.trim());
  }

  /// True if the firmware build advertises `gps_interval` as a
  /// settable custom var. Some hardware (notably the T1000-E
  /// v1.15.0 sensors implementation) only exposes `gps` and rejects
  /// writes to `gps_interval` with ERR_CODE_ILLEGAL_ARG; the
  /// polling cadence on those builds is fixed by the firmware.
  /// Null when the device hasn't replied to the initial query yet.
  bool? get supportsGpsInterval {
    if (_customVars.isEmpty) return null;
    return _customVars.containsKey('gps_interval');
  }

  void _requestCustomVars() {
    unawaited(
        send(MeshcoreFrameCodec.getCustomVars()).catchError((Object _) {}));
  }

  /// Write a single custom var. No-op if not ready. Refreshes the
  /// local cache afterwards so getters reflect the new state.
  ///
  /// If the firmware build doesn't expose [name] as a settable
  /// sensors-module key, the device replies with `ERR_CODE_ILLEGAL_ARG`
  /// (6). Set [absorbErrorFromUserFeed] to keep that ERR out of the
  /// dashboard's recent-activity feed (probing path).
  Future<void> setCustomVar({
    required String name,
    required String value,
    bool absorbErrorFromUserFeed = false,
  }) async {
    if (!isReady) return;
    if (absorbErrorFromUserFeed) _squelchNextDeviceError++;
    await send(MeshcoreFrameCodec.setCustomVar(name: name, value: value));
    // The device acknowledges with OK on accept, ERR on reject;
    // either way re-query so getters reflect the canonical state
    // (firmware constrains gps_interval to 0..86400, etc.).
    _requestCustomVars();
  }

  bool _autoEnabledGpsOnce = false;

  /// One-shot auto-heal: if the user has `advertLocPolicy=2` (GPS)
  /// but the firmware reports `gps=0`, push `gps=1` + a sane
  /// `gps_interval=30` so the GPS module actually starts updating
  /// `sensors.node_lat/lon`. Without this, picking "Device GPS" in
  /// our Device Config screen has no effect — the firmware just
  /// keeps broadcasting whatever cached lat/lon it last had.
  Future<void> _maybeAutoEnableGps() async {
    if (_autoEnabledGpsOnce) return;
    final SelfInfo? si = selfInfo;
    if (si == null) return;
    if (si.advertLocPolicy != 2) return; // user hasn't asked for GPS
    final bool? on = deviceGpsEnabled;
    if (on != false) return; // already on, or unknown — leave alone
    _autoEnabledGpsOnce = true;
    // ignore: avoid_print
    print('[meshcore.loc] auto-enabling on-board GPS '
        '(advertLocPolicy=2 but gps=0)');
    await setCustomVar(name: 'gps', value: '1');
    // We intentionally don't write `gps_interval` here. On at least
    // the T1000-E v1.15.0 build the sensors module only exposes
    // `gps` and rejects `gps_interval` with ERR_CODE_ILLEGAL_ARG —
    // the firmware then surfaces a confusing "device error 6" to
    // the user. Polling cadence on hardware that doesn't accept
    // `gps_interval` is fixed by the firmware build; on hardware
    // that does accept it, the user can pick a value from the
    // Device Config screen's interval picker (only shown when the
    // device advertises the key).
  }

  void _trackCustomVars(MeshcoreInbound f) {
    if (f is! CustomVarsFrame) return;
    _customVars = Map<String, String>.from(f.values);
    // ignore: avoid_print
    print('[meshcore.loc] CustomVarsFrame in: $_customVars');
    // Defer auto-enable to the microtask queue so SelfInfo (which
    // tells us the policy) has likely landed already on a fresh
    // connect.
    unawaited(Future<void>.microtask(_maybeAutoEnableGps));
  }

  /// Set this node's advertised name (`SET_ADVERT_NAME`). The change
  /// propagates to neighbours on the next advert. No-op if not ready.
  Future<void> setAdvertName(String name) async {
    final String n = name.trim();
    if (n.isEmpty || !isReady) return;
    await send(MeshcoreFrameCodec.setAdvertName(n));
  }

  /// Set this node's advertised location (`SET_ADVERT_LATLON`), in
  /// degrees. No-op if not ready.
  ///
  /// R44 — accepts an optional [altitudeMeters]. The codec sends a
  /// 3rd i32 (alt × 1e6) when present; firmware stores it for
  /// future use. As of the v1.15.0 advert wire-format the device
  /// does **not** rebroadcast altitude in adverts (the
  /// `ADV_LATLON` block is still 2×i32), so this is forward-
  /// compatibility plumbing: when firmware grows an altitude slot,
  /// our nodes' adverts will populate it for free without an app
  /// update.
  Future<void> setAdvertLatLon({
    required double latitude,
    required double longitude,
    double? altitudeMeters,
  }) async {
    if (!isReady) return;
    await send(MeshcoreFrameCodec.setAdvertLatLon(
      latitudeMicros: (latitude * 1e6).round(),
      longitudeMicros: (longitude * 1e6).round(),
      altitudeMicros: altitudeMeters == null
          ? null
          : (altitudeMeters * 1e6).round(),
    ));
  }

  /// Set the device's **advert location policy** via `CMD_SET_OTHER_PARAMS`
  /// (`0x26`). The policy determines what the device broadcasts:
  ///   `0` = no location, `1` = pinned (manual), `2` = live GPS.
  /// (Exact integer values vary by firmware revision — the codec
  /// passes the byte through.)
  ///
  /// `SET_OTHER_PARAMS` is a *bundle* command: it always carries the
  /// first two fields (manualAddContacts, telemetryModePacked) so the
  /// device doesn't reset them. We read those + `multiAcks` back from
  /// the cached `SelfInfo` to avoid clobbering unrelated settings.
  /// No-op if not ready or if SelfInfo hasn't been received yet.
  Future<void> setAdvertLocPolicy(int policy) async {
    if (!isReady) return;
    final SelfInfo? si = selfInfo;
    if (si == null) return;
    await send(MeshcoreFrameCodec.setOtherParams(
      manualAddContacts: si.manualAddContacts ? 1 : 0,
      telemetryModePacked: si.telemetryModeRaw,
      advertLocPolicy: policy,
      multiAcks: si.multiAcks,
    ));
  }

  /// Toggle whether the device requires the user to **manually add**
  /// heard nodes as contacts (instead of auto-promoting every advert).
  /// Wraps `CMD_SET_OTHER_PARAMS` (0x26); preserves the other three
  /// fields by reading them off the cached `SelfInfo`.
  Future<void> setManualAddContacts(bool v) async {
    if (!isReady) return;
    final SelfInfo? si = selfInfo;
    if (si == null) return;
    await send(MeshcoreFrameCodec.setOtherParams(
      manualAddContacts: v ? 1 : 0,
      telemetryModePacked: si.telemetryModeRaw,
      advertLocPolicy: si.advertLocPolicy,
      multiAcks: si.multiAcks,
    ));
  }

  /// Set the device's **telemetry mode** byte. The protocol packs
  /// several flags into this single byte; semantics are firmware-
  /// dependent (env/battery/location reporting cadence + format).
  /// We expose it as a raw int so power users can match what their
  /// MeshCore docs say. 0 = telemetry off.
  Future<void> setTelemetryMode(int packed) async {
    if (!isReady) return;
    final SelfInfo? si = selfInfo;
    if (si == null) return;
    await send(MeshcoreFrameCodec.setOtherParams(
      manualAddContacts: si.manualAddContacts ? 1 : 0,
      telemetryModePacked: packed & 0xFF,
      advertLocPolicy: si.advertLocPolicy,
      multiAcks: si.multiAcks,
    ));
  }

  /// Set the device's **multi-acks** count. The radio can be asked
  /// to expect up to N additional acks before considering a send
  /// confirmed; typical range 0–3. 0 = single ack (default).
  Future<void> setMultiAcks(int n) async {
    if (!isReady) return;
    final SelfInfo? si = selfInfo;
    if (si == null) return;
    final int clamped = n.clamp(0, 7);
    await send(MeshcoreFrameCodec.setOtherParams(
      manualAddContacts: si.manualAddContacts ? 1 : 0,
      telemetryModePacked: si.telemetryModeRaw,
      advertLocPolicy: si.advertLocPolicy,
      multiAcks: clamped,
    ));
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
    try {
      await send(MeshcoreFrameCodec.sendChannelTextMessage(
        channelIdx: _activeChannel,
        timestamp: ts,
        text: t,
      ));
    } catch (_) {
      _emitTaskError('sendChannel');
      return;
    }
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

  /// True while the controller is in the middle of a SYNC drain
  /// (post-handshake: pulling queued contacts/adverts/messages off the
  /// radio). Exposed so the Dashboard can flag the initial 1–3 s
  /// post-connect lag as "syncing…" rather than letting it feel like
  /// a freeze.
  bool get isDraining => _draining;

  void _setDraining(bool v) {
    if (_draining == v) return;
    _draining = v;
    notifyListeners();
  }

  void _drainStart() {
    if (_draining) return;
    _setDraining(true);
    _drainSteps = 0;
    _drainStep();
  }

  void _drainStep() {
    if (++_drainSteps > _drainStepCap) {
      _setDraining(false);
      return;
    }
    unawaited(send(MeshcoreFrameCodec.syncNextMessage()).catchError((_) {
      _setDraining(false);
    }));
  }

  void _maybeDrain(MeshcoreInbound f) {
    if (f is MessagesWaitingFrame) {
      _pushEvent(MeshEvent(
        kind: MeshEventKind.queuedWaiting,
        args: f.count == null
            ? const <String, String>{}
            : <String, String>{'count': '${f.count}'},
      ));
      _drainStart();
      return;
    }
    if (!_draining) return;
    if (f is NoMoreMessagesFrame) {
      _setDraining(false); // queue emptied
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
      // R44 — forward-compat: today a.altitudeMeters is always null
      // because the advert payload doesn't carry altitude over the
      // wire. Kept in the propagation path so UIs depending on
      // DiscoveredNode.altitudeMeters Just Work once firmware adds
      // an alt slot.
      altitudeMeters: a.altitudeMeters ?? prev?.altitudeMeters,
      snrDb: snr ?? prev?.snrDb,
      rssi: rssi ?? prev?.rssi,
      viaAdvert: true,
    );
    // F8 — peer's advertised position is a "the mesh extends to
    // here" observation. Same coverage bucket as own-location
    // samples; the FabricSurveyView shades both.
    if (a.latitude != null && a.longitude != null) {
      _recordCoverage(a.latitude!, a.longitude!);
    }
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

  /// Call when the app returns to the foreground (R17 — the app is
  /// usually backgrounded/screen-locked). If still linked, pull
  /// anything the radio queued while we were away; if the link
  /// dropped and a device is paired, bring it back (reaching `ready`
  /// auto-drains). Respects a user-initiated [disconnect].
  Future<void> onAppResumed() async {
    if (_manualDisconnect) return; // user chose to stay disconnected
    if (isReady) {
      _drainStart(); // drain backlog buffered while backgrounded
      return;
    }
    if (_connecting) return; // a (re)connect is already in flight
    if (hasPairedDevice) await connect();
  }

  /// User-initiated disconnect. Latches off auto-reconnect until the
  /// next explicit [connect].
  ///
  /// Bug fix (post R41): explicitly flip [_state] → disconnected and
  /// notify listeners. The underlying [MeshcoreConnection] state
  /// stream may not emit a state change reliably when the transport
  /// is closed from above (it's designed to react to a remote drop,
  /// not a local one), so the dashboard would otherwise still read
  /// "READY" until something else triggered a rebuild. Setting
  /// state inline is idempotent with any later stream-driven update.
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectGen++; // cancel any pending scheduled retry
    _battTimer?.cancel();
    _selfInfoTimer?.cancel();
    unawaited(_keepalive.stop());
    await _transport?.close();
    _transport = null;
    _state = MeshcoreConnectionState.disconnected;
    notifyListeners();
  }

  /// Label of the saved paired device (loaded lazily for the UI).
  String? get pairedName => _pairedName;
  String? _pairedName;
  bool get hasPairedDevice => _pairedName != null;

  /// Saved remote ID for the currently-paired device, or null when
  /// nothing is paired. Hydrated alongside [_pairedName]; used by
  /// the device-manager UI to highlight which history row is
  /// "current".
  String? get pairedRemoteId => _pairedRemoteId;
  String? _pairedRemoteId;

  /// R41+1 — rolling history of recently-paired devices (last 5).
  /// Populated from prefs at construction; mutates whenever the
  /// BLE layer records a successful pair or the user forgets an
  /// entry. UI reads via [pairedHistory].
  List<PairedDeviceHistoryEntry> _pairedHistory =
      const <PairedDeviceHistoryEntry>[];
  List<PairedDeviceHistoryEntry> get pairedHistory =>
      List<PairedDeviceHistoryEntry>.unmodifiable(_pairedHistory);

  Future<void> _refreshHistory() async {
    _pairedHistory = await PairedDeviceHistoryStore.load();
    notifyListeners();
  }

  /// Post R41 bug fix — re-read the persisted pairing into the
  /// cached `_pairedName` / `_pairedRemoteId` fields. Fired from the
  /// ready-state listener so a fresh scan-and-connect (which writes
  /// the pairing low in the BLE stack) also surfaces the device's
  /// name in the Device sheet. Also refreshes history so the new
  /// pairing appears at the top of "Recently paired".
  Future<void> _hydratePairedFromPrefs() async {
    final PairedDevice? p = await PairedDeviceStore.read();
    if (p == null) return;
    if (_pairedName == p.name && _pairedRemoteId == p.remoteId) return;
    _pairedName = p.name;
    _pairedRemoteId = p.remoteId;
    await _refreshHistory(); // also notifies
  }

  /// Call once at startup: if a device was previously paired,
  /// auto-reconnect to it (direct connect, scan fallback). Safe to
  /// call when nothing is paired (no-op).
  Future<void> autoConnectIfPaired() async {
    // Eagerly hydrate the history alongside the active pair so the
    // device-manager sheet has its "Recently paired" list ready on
    // first open — no second roundtrip needed.
    final PairedDevice? p = await PairedDeviceStore.read();
    _pairedHistory = await PairedDeviceHistoryStore.load();
    if (p == null) {
      notifyListeners();
      return;
    }
    _pairedName = p.name;
    _pairedRemoteId = p.remoteId;
    notifyListeners();
    await connect();
  }

  /// Forget the saved radio and disconnect — no more auto-reconnect
  /// until the user pairs again. R41+1: also drops the current
  /// device's entry from the recently-paired history; the user
  /// chose "forget", we should not leave a one-tap reconnect
  /// breadcrumb pointing back at it.
  Future<void> forgetDevice() async {
    final String? rid = _pairedRemoteId;
    await PairedDeviceStore.clear();
    if (rid != null) await PairedDeviceHistoryStore.remove(rid);
    _pairedName = null;
    _pairedRemoteId = null;
    await disconnect();
    await _refreshHistory();
  }

  /// R41+1 — drop a *specific* entry from the recently-paired list.
  /// When [remoteId] is the currently-active pair, this also
  /// triggers a full [forgetDevice] so the UI stays consistent.
  Future<void> forgetHistoryEntry(String remoteId) async {
    if (remoteId == _pairedRemoteId) {
      await forgetDevice();
      return;
    }
    await PairedDeviceHistoryStore.remove(remoteId);
    await _refreshHistory();
  }

  /// R41+1 — reconnect to a device the user previously paired with,
  /// looked up by remote ID in the rolling history. Same code path
  /// as [connectToPickedDevice]; the entry is also touched so it
  /// pops to the top of the history list.
  Future<void> connectFromHistory(String remoteId) async {
    for (final PairedDeviceHistoryEntry e in _pairedHistory) {
      if (e.remoteId == remoteId) {
        await connectToPickedDevice(
            remoteId: e.remoteId, name: e.name);
        return;
      }
    }
  }

  /// R41 — pair to (and connect to) a specific BLE device the user
  /// picked from the scan results. Tears down any existing link,
  /// writes the new pairing to [PairedDeviceStore] so auto-reconnect
  /// uses it from now on, clears the manual-disconnect latch, and
  /// kicks a fresh [connect]. The transport factory was set at
  /// construction time and reads the paired remote ID on each
  /// [BleConnector.autoConnect] call — so saving + reconnecting is
  /// all that's needed; we don't have to swap the factory.
  Future<void> connectToPickedDevice({
    required String remoteId,
    required String name,
  }) async {
    await disconnect();
    await PairedDeviceStore.save(remoteId, name);
    // R41+1 — touch eagerly so the manager sheet sees the chosen
    // device promoted to the top of history even if the BLE
    // discover/notify path that runs `BleConnector._finish` later
    // hasn't landed yet (UX latency improvement).
    await PairedDeviceHistoryStore.touch(remoteId, name);
    _pairedName = name;
    _pairedRemoteId = remoteId;
    _manualDisconnect = false;
    await _refreshHistory();
    await connect();
  }

  @override
  void dispose() {
    _manualDisconnect = true;
    _reconnectGen++; // invalidate any pending scheduled retry
    _scanTimer?.cancel();
    _battTimer?.cancel();
    _selfInfoTimer?.cancel();
    _statesSub?.cancel();
    _inboundSub?.cancel();
    _rawSub?.cancel();
    _persistChat(); // final flush
    unawaited(_keepalive.stop());
    unawaited(_incomingCh.close());
    unawaited(_incomingDm.close());
    unawaited(_taskErrors.close());
    unawaited(_transport?.close());
    unawaited(_connection.dispose());
    super.dispose();
  }
}
