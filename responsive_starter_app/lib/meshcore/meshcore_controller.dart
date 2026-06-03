// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:meshcore/meshcore.dart';

import 'background_keepalive.dart';
import 'background_prefs.dart';
import 'battery_history_store.dart';
import 'battery_model.dart';
import 'default_channel_store.dart';
import 'device_power_specs.dart';
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
import 'message_heat.dart';
import 'node_telemetry.dart';
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
    Duration? deliveryTimeoutOverride,
  })  : _deliveryTimeoutOverride = deliveryTimeoutOverride,
        _transportFactory =
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
        // Pull self-telemetry once on ready — the only thing
        // CMD_SET_OTHER_PARAMS's telemetry mode controls is whether
        // the device *broadcasts* it on the air; the companion path
        // (CMD_SEND_TELEMETRY_REQ → PUSH_CODE_TELEMETRY_RESPONSE) is
        // always available and returns immediately for the self case.
        // Used to populate altitude in ownLocation.
        requestSelfTelemetry();
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
      _trackTelemetry(f);
      // R25+1 — own movement trail. Every inbound frame might have
      // bumped ownLocation (SelfInfoFrame's lat/lon), so sample
      // here. Deduped internally by movement threshold.
      _trackOwnLocationForTrail();
      _ingestKnown(f);
      _ingestDm(f);
      _maybeDrain(f);
      _ingestNode(f);
      _ingestChat(f);
      _trackMessageHeat(f);
      _trackDelivery(f);
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
    _loadBatteryHistory();
    _loadPowerSpecs();
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
  ///
  /// Altitude has its own priority chain because SelfInfo doesn't
  /// carry altitude over the wire (lat/lon only). We prefer, in
  /// order:
  ///   1. Self-telemetry's GPS altitude (the device's own GPS chip,
  ///      via the CMD_SEND_TELEMETRY_REQ / 0x8B path — step 3).
  ///   2. The cached phone-GPS altitude (R22 one-shot or R36 auto-
  ///      publish hand-off).
  ///   3. None, in which case the elevation-profile view falls back
  ///      to the "?" band.
  OwnLocation? get ownLocation {
    final SelfInfo? si = selfInfo;
    final double? altFromTelemetry = selfTelemetry?.altitudeMeters;
    final double? altFromPhone = _phoneFix?.altitudeMeters;
    final double? altMerged = altFromTelemetry ?? altFromPhone;
    if (si != null &&
        !(si.latitude.abs() < 1e-9 && si.longitude.abs() < 1e-9)) {
      return OwnLocation(
        latitude: si.latitude,
        longitude: si.longitude,
        altitudeMeters: altMerged,
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
    // Guard: an advert can carry a malformed i32 lat/lon that decodes
    // to an out-of-Earth-range double (anything up to ±2147°). Without
    // this filter the bogus value gets persisted as a coverage cell
    // and trips flutter_map's polygon assertion next time the survey
    // view renders (it expects latitudes in ±90 / longitudes in ±180).
    if (!lat.isFinite || !lon.isFinite) return;
    if (lat.abs() > 90.0 || lon.abs() > 180.0) return;
    // (0,0) is the unset sentinel (Null Island) — never a real
    // observation. Drop it so the coverage quilt doesn't grow a
    // phantom cell off West Africa.
    if (lat.abs() < 1e-9 && lon.abs() < 1e-9) return;
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

  /// R49 — resolved topology chain for a peer, ordered from the
  /// first hop *from us* to the last hop *before the peer*. Each
  /// entry is the known repeater whose pubkey starts with the
  /// matching first-byte hash from `outPathHashes`.
  ///
  /// Returns:
  /// - **`[]` (empty)** when the peer is a known direct neighbour
  ///   (contact-synced with `out_path_len == 0`).
  /// - **`List<DiscoveredNode>`** when every hash resolved to a
  ///   single known repeater.
  /// - **`null`** when **any** of:
  ///   - the peer's `outPathHashes` is `null` (advert-only-heard,
  ///     no path info available — the common case);
  ///   - a hop is unresolved (no repeater heard with that first
  ///     byte);
  ///   - a hop is ambiguous (two known repeaters share the same
  ///     first byte).
  ///
  /// Caller decides whether to fall back to a direct line.
  ///
  /// Resolver scope: only nodes of `type == 2` (repeater) are
  /// candidates, so a chat node that happens to share a first byte
  /// with a repeater hash won't be falsely matched.
  List<DiscoveredNode>? topologyChainFor(String pubKeyHex) {
    final DiscoveredNode? peer = _nodes[pubKeyHex.toLowerCase()];
    if (peer == null) return null;
    final List<int>? hashes = peer.outPathHashes;
    if (hashes == null) return null; // advert-only — no path info
    if (hashes.isEmpty) return const <DiscoveredNode>[];

    // Build a hash → repeater map. O(n) per call — n is small (tens
    // to low hundreds in practice). Tracks duplicates to flag
    // ambiguous hops.
    final Map<int, DiscoveredNode> byFirstByte = <int, DiscoveredNode>{};
    final Set<int> ambiguous = <int>{};
    for (final DiscoveredNode n in _nodes.values) {
      if (n.type != kAdvTypeRepeater) continue;
      if (n.pubKeyHex.length < 2) continue;
      final int firstByte =
          int.parse(n.pubKeyHex.substring(0, 2), radix: 16);
      if (byFirstByte.containsKey(firstByte)) {
        ambiguous.add(firstByte);
      } else {
        byFirstByte[firstByte] = n;
      }
    }

    final List<DiscoveredNode> chain = <DiscoveredNode>[];
    for (final int hash in hashes) {
      if (ambiguous.contains(hash)) return null; // collision
      final DiscoveredNode? hop = byFirstByte[hash];
      if (hop == null) return null; // unresolved
      chain.add(hop);
    }
    return List<DiscoveredNode>.unmodifiable(chain);
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

  // --- Outgoing delivery tracking (QoL: per-message status glyph) ---
  //
  // Lifecycle: sending → sent → (DM only) delivered, or → failed.
  // - sending: we issued the BLE send command; a watchdog catches a
  //   device that never confirms.
  // - sent: RESP_CODE_SENT (MsgSentFrame) arrived. We correlate it to
  //   the oldest message still awaiting confirmation (sends are
  //   serialised over BLE, so FIFO order holds) and record its
  //   expectedAck tag. Channel/broadcast messages stop here — flood
  //   routing yields no recipient receipt.
  // - delivered: a DM's PUSH_CODE_ACK arrived carrying the same
  //   expectedAck tag.
  // - failed: the BLE send threw, the confirm watchdog fired, or a
  //   DM's ack-timeout elapsed with no receipt.
  //
  // Ordering: some firmware pushes the PUSH_CODE_ACK *before* the
  // RESP_CODE_SENT confirmation (the ACK can't be matched yet — we
  // don't learn the expectedAck tag until the SENT frame). So an
  // unmatched ACK is cached briefly and reconciled when the SENT
  // frame lands; otherwise the message would (wrongly) time out as
  // failed despite having been delivered.

  /// Outgoing message ids awaiting a RESP_CODE_SENT, oldest first.
  final List<String> _pendingSendIds = <String>[];

  /// Per-message lifecycle timers (confirm watchdog, then DM ack
  /// timeout), keyed by message id.
  final Map<String, Timer> _deliveryTimers = <String, Timer>{};

  /// ACK tags seen *before* their RESP_CODE_SENT (tag → epoch ms).
  /// Consumed when the matching SENT confirmation arrives. Pruned by
  /// age so a never-matched ACK can't accumulate.
  final Map<int, int> _recentAcks = <int, int>{};
  static const int _recentAckTtlMs = 30000;

  /// How long to wait for the device's send confirmation before
  /// giving up on an outgoing message.
  static const Duration _confirmWatchdog = Duration(seconds: 15);

  /// Test seam: when set, overrides BOTH the confirm watchdog and the
  /// DM ack-timeout so delivery-state transitions can be exercised
  /// without real-time waits. Null in production.
  final Duration? _deliveryTimeoutOverride;

  ChatMessage? _messageById(String id) {
    for (final ChatMessage m in _messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _registerOutgoing(ChatMessage m) {
    _pendingSendIds.add(m.id);
    _deliveryTimers[m.id]?.cancel();
    _deliveryTimers[m.id] =
        Timer(_deliveryTimeoutOverride ?? _confirmWatchdog, () {
      final ChatMessage? msg = _messageById(m.id);
      if (msg != null && msg.delivery == MessageDelivery.sending) {
        msg.delivery = MessageDelivery.failed;
        _pendingSendIds.remove(m.id);
        _deliveryTimers.remove(m.id);
        _persistChat();
        notifyListeners();
      }
    });
  }

  void _markOutgoingFailed(String id) {
    final ChatMessage? m = _messageById(id);
    if (m != null) m.delivery = MessageDelivery.failed;
    _pendingSendIds.remove(id);
    _deliveryTimers.remove(id)?.cancel();
    _persistChat();
  }

  /// DM ack-timeout = the device's estimate, padded 50 % for OTA
  /// jitter, clamped so a tiny or absurd estimate can't make the glyph
  /// flap or hang.
  Duration _ackTimeoutFor(int estMs) {
    final Duration? override = _deliveryTimeoutOverride;
    if (override != null) return override;
    final int padded = (estMs * 1.5).round();
    final int clamped = padded.clamp(5000, 120000);
    return Duration(milliseconds: clamped);
  }

  void _recordRecentAck(int tag) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    _recentAcks.removeWhere((_, int ts) => now - ts > _recentAckTtlMs);
    _recentAcks[tag] = now;
  }

  /// True if [tag] was acked within the TTL; consumes it.
  bool _consumeRecentAck(int tag) {
    final int? ts = _recentAcks.remove(tag);
    if (ts == null) return false;
    return DateTime.now().millisecondsSinceEpoch - ts <= _recentAckTtlMs;
  }

  void _trackDelivery(MeshcoreInbound f) {
    if (f is MsgSentFrame) {
      if (_pendingSendIds.isEmpty) return;
      final String id = _pendingSendIds.removeAt(0);
      final ChatMessage? m = _messageById(id);
      if (m == null) return;
      m
        ..delivery = MessageDelivery.sent
        ..expectedAck = f.sent.expectedAck;
      _deliveryTimers.remove(id)?.cancel();
      if (_consumeRecentAck(f.sent.expectedAck)) {
        // The ACK raced ahead of this SENT confirmation (firmware
        // ordering). Reconcile now — delivered, no timeout.
        m.delivery = MessageDelivery.delivered;
      } else if (!f.sent.isFlood) {
        // Direct message: wait for the recipient ACK. Channel/
        // broadcast (flood) has no receipt → terminal at sent.
        _deliveryTimers[id] = Timer(_ackTimeoutFor(f.sent.estTimeoutMs), () {
          final ChatMessage? msg = _messageById(id);
          if (msg != null && msg.delivery == MessageDelivery.sent) {
            msg.delivery = MessageDelivery.failed;
            _deliveryTimers.remove(id);
            _persistChat();
            notifyListeners();
          }
        });
      }
      _persistChat();
    } else if (f is AckFrame) {
      // Match the ack tag to the most recent still-sent message. Tags
      // are 32-bit; collisions are unlikely within a handful of
      // in-flight messages, and matching newest-first is the safe
      // choice.
      for (int i = _messages.length - 1; i >= 0; i--) {
        final ChatMessage m = _messages[i];
        if (m.outgoing &&
            m.delivery == MessageDelivery.sent &&
            m.expectedAck == f.ackCrc) {
          m.delivery = MessageDelivery.delivered;
          _deliveryTimers.remove(m.id)?.cancel();
          _persistChat();
          return;
        }
      }
      // No matching sent message yet — the ACK arrived before the
      // RESP_CODE_SENT confirmation. Remember it so the SENT frame can
      // reconcile to delivered instead of timing out.
      _recordRecentAck(f.ackCrc);
    }
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
    // Optimistic row first (status: sending) so the user sees the
    // message and its in-flight glyph immediately; promote it as the
    // device confirm / recipient ack arrive.
    final ChatMessage m = ChatMessage(
      channelIdx: -1,
      text: t,
      outgoing: true,
      peerPubKeyHex: peerPubKeyHex,
      delivery: MessageDelivery.sending,
    );
    _addMessage(m);
    _registerOutgoing(m);
    notifyListeners();
    try {
      await send(MeshcoreFrameCodec.sendTextMessage(
        pubKeyPrefix: prefix,
        timestamp: ts,
        text: t,
      ));
    } catch (_) {
      _emitTaskError('sendDm');
      _markOutgoingFailed(m.id);
      notifyListeners();
    }
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

  // -------------------------------------------------------------------
  // R51 — social activity heat (sns-cells view). Buckets observed
  // messages into geographic cells and scores them by time-decayed
  // density. DMs land at the (located) sender's cell; channel
  // messages are anonymous in MeshCore so they land at our own cell
  // (the message reached us *here*).
  // -------------------------------------------------------------------

  final MessageHeatTracker _heat = MessageHeatTracker();

  /// cellKey → hotness in [0, 1] over the last hour. Pruned on read.
  Map<String, double> messageHeatScores() => _heat.scores();

  /// Most recently observed message (drives the sns-cells toast).
  HeatPing? get lastHeatPing => _heat.lastPing;

  /// Wipe all accumulated social heat (sns-cells "clear" control).
  void clearMessageHeat() {
    _heat.clear();
    notifyListeners();
  }

  void _trackMessageHeat(MeshcoreInbound f) {
    if (f is ContactMessageFrame) {
      // DM: resolve sender by 6-byte prefix; place heat at the
      // sender's known location when we have one.
      final ContactMessage cm = f.message;
      final String prefixHex = _hex(cm.pubKeyPrefix);
      DiscoveredNode? sender;
      for (final DiscoveredNode n in _nodes.values) {
        if (n.pubKeyHex.startsWith(prefixHex)) {
          sender = n;
          break;
        }
      }
      _heat.record(
        text: cm.text,
        atUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        lat: sender?.hasLocation == true ? sender!.latitude : null,
        lon: sender?.hasLocation == true ? sender!.longitude : null,
        pubKeyHex: sender?.pubKeyHex,
        isChannel: false,
      );
    } else if (f is ChannelMessageFrame) {
      // Channel messages have no sender *field*, but MeshCore
      // firmware prepends the sender's name to the text as
      // "name: message" (sprintf "%s: " in sendGroupMessage). So we
      // can attribute by name: parse the prefix, match it to a
      // single known node, and place the heat at *that* node — same
      // as a DM. Falls back to our own cell when the name is
      // missing, unmatched, ambiguous, or the matched node has no
      // location. Attribution is advisory (channel text isn't
      // per-sender signed), which is fine for a social heat map.
      final ChannelMessage cm = f.message;
      final DiscoveredNode? sender = _resolveChannelSender(cm.text);
      final bool located = sender?.hasLocation == true;
      final OwnLocation? own = ownLocation;
      _heat.record(
        text: cm.text,
        atUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        lat: located ? sender!.latitude : own?.latitude,
        lon: located ? sender!.longitude : own?.longitude,
        pubKeyHex: located ? sender!.pubKeyHex : null,
        isChannel: true,
      );
    }
  }

  /// Parse the "name: …" prefix MeshCore prepends to channel text and
  /// resolve it to a single known node. Returns null when there's no
  /// prefix, no match, or an ambiguous (>1) match — name strings
  /// aren't unique or authenticated, so we only attribute on an
  /// unambiguous hit.
  DiscoveredNode? _resolveChannelSender(String text) {
    final String? name = parseChannelSenderName(text);
    if (name == null) return null;
    final String want = name.toLowerCase();
    DiscoveredNode? hit;
    for (final DiscoveredNode n in _nodes.values) {
      if (n.name.toLowerCase() == want) {
        if (hit != null) return null; // ambiguous — bail
        hit = n;
      }
    }
    return hit;
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

  // --- Battery-life estimation (per-device history + spec) ---
  //
  // The companion protocol only gives us pack voltage, so runtime is
  // estimated from voltage-over-time (observed drain) plus a per-
  // device nameplate cross-check. History is persisted per device so
  // the estimate survives restarts; see [BatteryHistoryStore] and
  // [estimateBattery].

  final Map<String, List<BatterySample>> _battHistory =
      <String, List<BatterySample>>{};
  bool _battHistoryDirty = false;
  Timer? _battHistorySaveTimer;
  DevicePowerSpecs _powerSpecs = DevicePowerSpecs.builtin;

  /// Own 12-hex-char pubkey prefix (pub6), or null before SelfInfo.
  String? get _ownPub6 {
    final String? hex = ownPubKeyHex;
    if (hex == null || hex.length < kPubKeyPrefixSize * 2) return null;
    return hex.substring(0, kPubKeyPrefixSize * 2);
  }

  Future<void> _loadBatteryHistory() async {
    final Map<String, List<BatterySample>> v =
        await BatteryHistoryStore.load();
    if (v.isEmpty) return;
    _battHistory
      ..clear()
      ..addAll(v);
    notifyListeners();
  }

  Future<void> _loadPowerSpecs() async {
    try {
      final String raw =
          await rootBundle.loadString('assets/data/device_power_specs.json');
      _powerSpecs = DevicePowerSpecs.parse(raw);
      notifyListeners();
    } catch (_) {
      // No asset bundle (e.g. a plain unit test) — keep the built-in
      // generic fallback. The estimator still works, observed-only.
      _powerSpecs = DevicePowerSpecs.builtin;
    }
  }

  /// Power spec resolved for the connected device, matched on the
  /// DeviceInfo manufacturer / firmware strings. Always non-null (the
  /// generic single-cell Li-ion fallback when nothing matches).
  DevicePowerSpec get resolvedPowerSpec => _powerSpecs.resolve(
        manufacturer: _deviceInfo?.manufacturer,
        firmware: _deviceInfo?.firmwareVersion,
      );

  /// Persisted voltage history for the connected device, oldest
  /// first. Empty before any reading (or before SelfInfo identifies
  /// us).
  List<BatterySample> get batteryHistory {
    final String? pub = _ownPub6;
    if (pub == null) return const <BatterySample>[];
    return List<BatterySample>.unmodifiable(
        _battHistory[pub] ?? const <BatterySample>[]);
  }

  /// Current battery-life estimate for the connected device. Folds
  /// the persisted voltage history, the resolved device spec, and the
  /// charging trend into a single [BatteryEstimate].
  BatteryEstimate get batteryEstimate {
    final List<BatterySample> hist = batteryHistory;
    if (hist.isEmpty) {
      // Fall back to the latest live reading even before it's been
      // decimated into the persisted history, so the screen isn't
      // blank on a fresh connect.
      final int? mv = batteryMillivolts;
      if (mv == null) return BatteryEstimate.empty;
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return estimateBattery(
        samples: <BatterySample>[(atUnix: now, millivolts: mv)],
        spec: resolvedPowerSpec,
        charging: _charging,
      );
    }
    return estimateBattery(
      samples: hist,
      spec: resolvedPowerSpec,
      charging: _charging,
      nowUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  void _recordBatterySample(int millivolts, int nowUnix) {
    final String? pub = _ownPub6;
    if (pub == null) return; // can't attribute without SelfInfo yet
    final List<BatterySample> list =
        _battHistory.putIfAbsent(pub, () => <BatterySample>[]);
    // Decimate: keep at most one stored sample per minInterval.
    if (list.isNotEmpty &&
        nowUnix - list.last.atUnix < BatteryHistoryStore.minIntervalSec) {
      return;
    }
    list.add((atUnix: nowUnix, millivolts: millivolts));
    while (list.length > BatteryHistoryStore.maxSamplesPerDevice) {
      list.removeAt(0);
    }
    // Evict the least-recently-updated device when over the cap.
    while (_battHistory.length > BatteryHistoryStore.maxDevices) {
      String? oldestPub;
      int oldestTs = 1 << 62;
      _battHistory.forEach((String k, List<BatterySample> s) {
        final int t = s.isEmpty ? 0 : s.last.atUnix;
        if (t < oldestTs) {
          oldestTs = t;
          oldestPub = k;
        }
      });
      if (oldestPub == null || oldestPub == pub) break;
      _battHistory.remove(oldestPub);
    }
    _battHistoryDirty = true;
    _battHistorySaveTimer ??=
        Timer(const Duration(seconds: 10), _flushBatteryHistory);
    notifyListeners();
  }

  Future<void> _flushBatteryHistory() async {
    _battHistorySaveTimer = null;
    if (!_battHistoryDirty) return;
    _battHistoryDirty = false;
    await BatteryHistoryStore.save(_battHistory);
  }

  /// Wipe the persisted battery history (all devices). Exposed for a
  /// "reset" affordance on the battery screen + tests.
  Future<void> resetBatteryHistory() async {
    _battHistory.clear();
    _battHistoryDirty = false;
    _battHistorySaveTimer?.cancel();
    _battHistorySaveTimer = null;
    await BatteryHistoryStore.clear();
    notifyListeners();
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
    // Wrapped in try/catch: the link can drop mid-refresh (these are
    // multiple awaited round-trips), and `send` throws *synchronously*
    // when disconnected — which a per-future `.catchError` can't
    // intercept. Swallow it; a refresh is always best-effort.
    try {
      if (before != null) {
        await setAdvertLocPolicy(before.advertLocPolicy);
      }
      // 1) Zero-hop advert triggers firmware GPS read + state update
      //    (theoretically — confirmed by the v37 capture that this
      //    alone wasn't enough).
      await sendSelfAdvert(flood: false);
      // 2) appStart re-fetches the SelfInfo response.
      await send(MeshcoreFrameCodec.appStart(
        appName: _connection.appName,
      ));
    } catch (_) {
      // link dropped or device busy — best-effort, ignore.
    }
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

  /// Set this node's advertised name (`SET_ADVERT_NAME`). No-op if not
  /// ready or blank.
  ///
  /// After the write we kick a [refreshSelfInfo] so the change takes
  /// effect end-to-end: the zero-hop self-advert pushes the new name
  /// onto the mesh immediately (rather than waiting for the next
  /// scheduled advert), and the follow-up appStart re-reads SelfInfo
  /// so the app's own surfaces (dashboard, Device config) reflect the
  /// rename without a reconnect. Fire-and-forget so callers can toast
  /// right after the name write.
  Future<void> setAdvertName(String name) async {
    final String n = name.trim();
    if (n.isEmpty || !isReady) return;
    await send(MeshcoreFrameCodec.setAdvertName(n));
    unawaited(refreshSelfInfo());
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

  // -------------------------------------------------------------------
  // Telemetry — CMD_SEND_TELEMETRY_REQ (0x27) / PUSH_CODE_TELEMETRY_RESPONSE
  // (0x8B). Keyed by 6-byte pubkey-prefix (12-char hex). Self-telemetry
  // is the entry under our own pubkey6; peer telemetry is everything
  // else (populated only when the app explicitly queries a peer, which
  // is out of scope for v1).
  // -------------------------------------------------------------------

  final Map<String, NodeTelemetry> _telemetry = <String, NodeTelemetry>{};

  /// Telemetry for our own device, if a 0x8B push has arrived. Null
  /// before the first self-telemetry round-trip completes.
  NodeTelemetry? get selfTelemetry {
    final String? own = ownPubKeyHex;
    if (own == null) return null;
    return _telemetry[own.substring(0, kPubKeyPrefixSize * 2)];
  }

  /// Telemetry for an arbitrary node, looked up by 6-byte pubkey
  /// prefix. Accepts either the 12-char prefix or the full 64-char
  /// pubkey hex — the controller always keys by the first 6 bytes.
  NodeTelemetry? telemetryFor(String pubKeyHex) {
    final String hex = pubKeyHex.toLowerCase();
    if (hex.length < kPubKeyPrefixSize * 2) return null;
    return _telemetry[hex.substring(0, kPubKeyPrefixSize * 2)];
  }

  /// Fire a one-shot self-telemetry request. The device replies
  /// immediately (no OTA) with a 0x8B push that lands on the inbound
  /// stream and gets ingested by [_trackTelemetry]. Public so views
  /// (e.g. the elevation profile) can re-poll our own altitude on
  /// demand.
  void requestSelfTelemetry() {
    unawaited(send(MeshcoreFrameCodec.sendTelemetryReq()).catchError((_) {}));
  }

  /// Per-peer telemetry query. Sends `CMD_SEND_TELEMETRY_REQ` (0x27)
  /// with the 32-byte pubkey appended — the device unicasts the
  /// request over the air; the peer's eventual response arrives
  /// asynchronously as a `PUSH_CODE_TELEMETRY_RESPONSE` (0x8B) and is
  /// stored against the matching 6-byte prefix.
  ///
  /// Behaviour:
  /// - No-op when we have a cached entry younger than [cacheFor].
  /// - No-op when a query is already in flight for the same peer
  ///   (the inflight flag is cleared on response or [inflightTimeout]).
  /// - Accepts either the full 64-char pubkey hex or just the 12-char
  ///   prefix — the prefix is enough for cache lookup, but the full
  ///   32 bytes are needed to actually address the peer over the air.
  ///   When only a prefix is given the call is a cache-hit no-op (we
  ///   can't reach the peer without the rest of the key).
  Future<void> requestPeerTelemetry(
    String pubKeyHex, {
    Duration cacheFor = const Duration(minutes: 5),
    Duration inflightTimeout = const Duration(seconds: 45),
    int maxAttempts = 0, // 0 = no cap
  }) async {
    if (!isReady) return;
    final String hex = pubKeyHex.toLowerCase();
    if (hex.length < kPubKeyPrefixSize * 2) return;
    final String pub6 = hex.substring(0, kPubKeyPrefixSize * 2);
    final NodeTelemetry? cached = _telemetry[pub6];
    if (cached != null &&
        DateTime.now().difference(cached.receivedAt) < cacheFor) {
      return; // fresh enough
    }
    if (_telemetryInflight.contains(pub6)) return;
    // Per-session attempt cap. Lives on the controller (not the
    // view) so swapping views or restarting the elevation/auto-
    // query screen doesn't reset the count and rebombard a peer
    // that already ignored us N times.
    if (maxAttempts > 0 &&
        (_telemetryAttempts[pub6] ?? 0) >= maxAttempts) {
      return;
    }
    if (hex.length != kPubKeySize * 2) {
      // Only a prefix — can't address the peer.
      return;
    }
    final Uint8List pubKey = Uint8List(kPubKeySize);
    for (int i = 0; i < kPubKeySize; i++) {
      pubKey[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    _telemetryInflight.add(pub6);
    _telemetryAttempts[pub6] = (_telemetryAttempts[pub6] ?? 0) + 1;
    notifyListeners();
    // Auto-clear if the peer never answers (OTA loss, peer offline,
    // or peer's privacy policy denies the request).
    Timer(inflightTimeout, () {
      if (_telemetryInflight.remove(pub6)) notifyListeners();
    });
    try {
      await send(
          MeshcoreFrameCodec.sendTelemetryReq(peerPubKey: pubKey));
    } catch (_) {
      _telemetryInflight.remove(pub6);
      notifyListeners();
    }
  }

  /// True while a peer-telemetry query is awaiting response. Drives
  /// "querying…" spinners in the UI.
  bool isQueryingTelemetry(String pubKeyHex) {
    final String hex = pubKeyHex.toLowerCase();
    if (hex.length < kPubKeyPrefixSize * 2) return false;
    return _telemetryInflight
        .contains(hex.substring(0, kPubKeyPrefixSize * 2));
  }

  /// Number of telemetry-query attempts made for this peer this
  /// process session. Survives view re-mounts (state lives on the
  /// controller, not the view). Reset on a successful telemetry
  /// receipt — see [_trackTelemetry] — so a peer that finally
  /// answers becomes eligible for fresh polling again.
  int telemetryAttemptsFor(String pubKeyHex) {
    final String hex = pubKeyHex.toLowerCase();
    if (hex.length < kPubKeyPrefixSize * 2) return 0;
    return _telemetryAttempts[
            hex.substring(0, kPubKeyPrefixSize * 2)] ??
        0;
  }

  /// Total telemetry requests sent this session (incremented once
  /// per actual outbound frame, not per call). Useful for the
  /// observability chip in the elevation view.
  int get telemetrySendCount =>
      _telemetryAttempts.values.fold(0, (int a, int b) => a + b);

  /// Reset the per-peer attempt counters so the auto-query loop
  /// gives every peer a fresh set of attempts. Used by the
  /// "tap to restart" affordance on the Fujiさん view — handy after
  /// a peer flips its telemetry mode on, or just to retry.
  void resetTelemetryAttempts() {
    _telemetryAttempts.clear();
    notifyListeners();
  }

  final Set<String> _telemetryInflight = <String>{};
  final Map<String, int> _telemetryAttempts = <String, int>{};

  void _trackTelemetry(MeshcoreInbound f) {
    if (f is! TelemetryResponseFrame) return;
    final StringBuffer hex = StringBuffer();
    for (final int b in f.pubKeyPrefix) {
      hex.write(b.toRadixString(16).padLeft(2, '0'));
    }
    String pub6 = hex.toString();
    // A self-telemetry reply may echo the *request's* all-zero pubkey
    // instead of the device's own prefix, landing under a zero key
    // where selfTelemetry / telemetryFor(self) can't find it. Re-key
    // it to our own prefix so every consumer sees self telemetry.
    final String? ownHex = ownPubKeyHex;
    final String? ownPub6 =
        (ownHex != null && ownHex.length >= kPubKeyPrefixSize * 2)
            ? ownHex.substring(0, kPubKeyPrefixSize * 2)
            : null;
    if (pub6 == '0' * (kPubKeyPrefixSize * 2) && ownPub6 != null) {
      pub6 = ownPub6;
    }
    final List<LppEntry> entries = decodeCayenneLpp(f.lppPayload);
    final NodeTelemetry nt = NodeTelemetry.fromFrame(
      pubKeyPrefixHex: pub6,
      receivedAt: DateTime.now(),
      entries: entries,
    );
    // Diagnostic so we can see exactly what a node reports (run
    // `flutter logs`): which LPP types arrived + the decoded env/alt.
    debugPrint('[telem] key=$pub6 '
        'types=${entries.map((LppEntry e) => '0x${e.type.toRadixString(16)}').join(',')} '
        'temp=${nt.temperatureC} hum=${nt.humidityPct} '
        'press=${nt.pressureHpa} alt=${nt.altitudeMeters}');
    _telemetry[pub6] = nt;
    _telemetryInflight.remove(pub6);
    // Reset the per-peer attempt cap on a successful receipt — a
    // peer that just answered is fair game for periodic refresh
    // later, without inheriting the failed-attempts count from
    // before they flipped telemetry on.
    _telemetryAttempts.remove(pub6);
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
    _recordBatterySample(f.battery.batteryMillivolts, now);
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
    final ChatMessage m = ChatMessage(
      channelIdx: _activeChannel,
      text: t,
      outgoing: true,
      delivery: MessageDelivery.sending,
    );
    _addMessage(m);
    _registerOutgoing(m);
    notifyListeners();
    try {
      await send(MeshcoreFrameCodec.sendChannelTextMessage(
        channelIdx: _activeChannel,
        timestamp: ts,
        text: t,
      ));
    } catch (_) {
      _emitTaskError('sendChannel');
      _markOutgoingFailed(m.id);
      notifyListeners();
    }
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
        // R49 — preserve the outbound repeater chain for topology
        // drawing. activePath gives the prefix of valid bytes; the
        // tail of the 64-byte buffer is zero-padding we discard.
        //
        // A flood-routed contact reports out_path_len == 0xFF (the
        // flood sentinel) — there is no fixed path. activePath would
        // clamp that to a bogus 64-byte chain, which then reads as a
        // 64-hop peer and gets filtered out of the tree at every hop
        // setting. Treat it as an UNKNOWN route (null) instead, so
        // it shows as a floater at the "All" setting like any other
        // advert-only peer.
        outPathHashes: c.outPathLen == kPathLenFlood
            ? null
            : List<int>.unmodifiable(c.activePath),
        // Flood-routed = reachable, no fixed path. Keep this flag so
        // the UI can show "Flood" (like the official app) instead of
        // conflating it with advert-only "unknown".
        viaFlood: c.outPathLen == kPathLenFlood,
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
      // Advert pushes don't carry the outbound repeater path; only
      // ContactFrame does. Preserve whatever the contact sync gave
      // us (may be null for advert-only-heard peers, which is the
      // signal the topology resolver uses to draw dashed).
      outPathHashes: prev?.outPathHashes,
      viaFlood: prev?.viaFlood ?? false,
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
    _battHistorySaveTimer?.cancel();
    for (final Timer t in _deliveryTimers.values) {
      t.cancel();
    }
    _deliveryTimers.clear();
    _statesSub?.cancel();
    _inboundSub?.cancel();
    _rawSub?.cancel();
    _persistChat(); // final flush
    unawaited(_flushBatteryHistory()); // final flush
    unawaited(_keepalive.stop());
    unawaited(_incomingCh.close());
    unawaited(_incomingDm.close());
    unawaited(_taskErrors.close());
    unawaited(_transport?.close());
    unawaited(_connection.dispose());
    super.dispose();
  }
}
