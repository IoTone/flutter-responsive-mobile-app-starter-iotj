import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../meshcore/chat_message.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import '../theme/theme_controller.dart';
import '../util/geo.dart' as geo;
import 'node_detail_sheet.dart';

/// R18 / U9 — the hyperlocal grid: a radial range-ring view of the
/// mesh **fabric** relative to us. Brightness = recency (100 % at
/// register, 0 % at >24 h → removed). Animation semantics: a *known*
/// node (we've had a direct/attributable exchange) **pulses**; a
/// *favourited* contact **blinks rapidly**; plain fabric nodes are
/// static (just brightness). Colour is theme-driven (R14 / R13). On
/// reduce-motion (R13) animations are replaced with a static ring
/// overlay so the same information is carried without flashing.
///
/// Positioning is **hybrid**: GPS bearing+distance when both we and
/// the node advertise a location; else RSSI/SNR → distance ring with
/// a stable per-pubkey hash bearing; else an abstract outer slot.
///
/// Audio/haptic parity (R12) is left for the R12 CueService (U6);
/// the grid currently carries the visual+positional cue only.
class GridScreen extends StatefulWidget {
  const GridScreen({super.key});

  /// Default outer-range scale (km) when the user hasn't moved the
  /// **Range** slider yet. Beyond this distance a GPS-positioned
  /// node clamps to the outer ring.
  static const double defaultRangeKm = 5.0;

  /// Discrete stops for the **Range** slider. Index 0 = literally
  /// "the same room", up to wide-area at 5 km (about the practical
  /// LoRa SF7-12 outdoor envelope). Render with `_scaleIndex` as
  /// the slider value.
  static const List<({String label, double km})> rangeStops =
      <({String label, double km})>[
    (label: 'Room', km: 0.025),
    (label: 'Home', km: 0.10),
    (label: 'Block', km: 0.5),
    (label: 'Neighborhood', km: 1.0),
    (label: 'Area', km: 2.0),
    (label: 'Wide', km: 5.0),
  ];

  /// Selectable cadences for the **Play** refresh timer. Pause is
  /// the default; Play with the smallest interval is effectively
  /// live but bounded against thrash on noisy meshes.
  static const List<Duration> playIntervals = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  /// Cutoff for visibility on the grid (R18: > 24 h → removed).
  static const Duration recencyWindow = Duration(hours: 24);

  @override
  State<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends State<GridScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  StreamSubscription<ChatMessage>? _msgSub;

  /// R18's anonymous-channel ripple: anchors a transient centre-out
  /// wave on every incoming channel message. The painter reads this
  /// each frame and decays it over `_rippleDuration`.
  DateTime? _rippleAt;
  static const Duration _rippleDuration = Duration(milliseconds: 900);

  /// Whether the inline legend overlay is shown (info button in app bar).
  bool _legendVisible = false;

  /// Maximum hit-test radius (logical px) for tap-to-select on the grid.
  static const double _tapRadius = 28.0;

  /// Pause / play state. Default is **paused** — the painter renders
  /// from a snapshot captured at screen-open / pause-tap rather than
  /// from `mc.nodes` live. Tapping play starts a periodic refresh of
  /// the snapshot at `_interval`. **Until the user touches any of
  /// the controls** (`_userInteracted`), the snapshot follows
  /// `mc.nodes` automatically so a freshly-connected user sees
  /// arriving adverts populate the view. As soon as they tap Pause,
  /// Play, or move the scale slider, the snapshot freezes per the
  /// pause semantics.
  bool _live = false;
  bool _userInteracted = false;
  Duration _interval = const Duration(seconds: 15);
  List<DiscoveredNode>? _snapshot;
  Timer? _refreshTimer;

  /// Index into [GridScreen.rangeStops] for the outer-ring scale.
  int _scaleIndex = GridScreen.rangeStops.length - 1; // Wide (5 km)

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // arbitrary; we read .value
    )..repeat();
    final MeshcoreController mc = context.read<MeshcoreController>();
    _snapshot = List<DiscoveredNode>.of(mc.nodes); // initial paused frame
    _msgSub =
        mc.incomingChannelMessages.listen((_) {
      if (mounted) _rippleAt = DateTime.now();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgSub?.cancel();
    _tick.dispose();
    super.dispose();
  }

  void _refreshSnapshot() {
    if (!mounted) return;
    setState(() => _snapshot = List<DiscoveredNode>.of(
        context.read<MeshcoreController>().nodes));
  }

  void _togglePlay() {
    setState(() {
      _userInteracted = true;
      _live = !_live;
    });
    _refreshTimer?.cancel();
    if (_live) {
      _refreshSnapshot(); // immediate snap on Play
      _refreshTimer =
          Timer.periodic(_interval, (_) => _refreshSnapshot());
    } else {
      // Pause taps: re-capture current state so the frozen view
      // matches what the user sees at the moment of pause.
      _refreshSnapshot();
    }
  }

  void _changeInterval(Duration d) {
    setState(() {
      _userInteracted = true;
      _interval = d;
    });
    if (_live) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(d, (_) => _refreshSnapshot());
    }
  }

  String _intervalLabel(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes} min';
    return '${d.inSeconds}s';
  }

  /// Cheap "did the live node list change" check for the
  /// auto-track-until-interaction path. We compare by length first
  /// (the cheap case) then identity per index — both nodes lists
  /// are managed by the controller which doesn't mutate in place.
  bool _listEquals(
      List<DiscoveredNode>? a, List<DiscoveredNode> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// Hit-test the visible node fleet against a tap. Picks the
  /// closest node within `_tapRadius`. Returns null if none match.
  DiscoveredNode? _hitTest({
    required Offset tap,
    required Size area,
    required List<DiscoveredNode> visible,
    required double? selfLat,
    required double? selfLon,
  }) {
    final Offset center = Offset(area.width / 2, area.height / 2);
    final double maxR = math.min(area.width, area.height) / 2 - 24;
    if (maxR <= 0) return null;
    DiscoveredNode? best;
    double bestDist = double.infinity;
    for (final DiscoveredNode n in visible) {
      final Offset p = _GridPainter.positionFor(
        node: n,
        center: center,
        maxR: maxR,
        selfLat: selfLat,
        selfLon: selfLon,
        scaleKm: GridScreen.rangeStops[_scaleIndex].km,
      );
      final double d = (p - tap).distance;
      if (d <= _tapRadius && d < bestDist) {
        best = n;
        bestDist = d;
      }
    }
    return best;
  }

  Future<void> _showDetail(
      BuildContext ctx, MeshcoreController mc, DiscoveredNode n) async {
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext _) => NodeDetailSheet(
        node: n,
        distanceMeters: n.hasLocation
            ? mc.distanceMetersTo(n.latitude!, n.longitude!)
            : null,
        isFavourite: mc.favorites.contains(n.pubKeyHex),
        isKnown: mc.known.contains(n.pubKeyHex),
        onToggleFavourite: () => mc.toggleFavorite(n.pubKeyHex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ThemeController tc = context.watch<ThemeController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool ready = mc.state == MeshcoreConnectionState.ready;

    // Until the user touches any control, the snapshot follows the
    // live `mc.nodes` automatically — that way a freshly-connected
    // user actually sees adverts populate the view. As soon as they
    // tap pause/play/scale (sets `_userInteracted = true`), the
    // snapshot freezes per the pause semantics.
    if (!_userInteracted && !_listEquals(_snapshot, mc.nodes)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_userInteracted) {
          setState(() => _snapshot =
              List<DiscoveredNode>.of(mc.nodes));
        }
      });
    }
    final List<DiscoveredNode> source = _snapshot ?? mc.nodes;

    // Filter visible nodes (within the 24h recency window).
    final int nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int windowSec = GridScreen.recencyWindow.inSeconds;
    final List<DiscoveredNode> visible = <DiscoveredNode>[
      for (final DiscoveredNode n in source)
        if (nowUnix - n.lastHeardUnix < windowSec) n
    ];

    final double scaleKm = GridScreen.rangeStops[_scaleIndex].km;
    final ({String label, double km}) scaleStop =
        GridScreen.rangeStops[_scaleIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hyperlocal grid'),
        actions: <Widget>[
          IconButton(
            tooltip:
                _live ? 'Pause updates' : 'Play (refresh every interval)',
            icon: Icon(_live ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlay,
          ),
          PopupMenuButton<Duration>(
            tooltip: 'Refresh interval (when playing)',
            initialValue: _interval,
            onSelected: _changeInterval,
            itemBuilder: (BuildContext _) => <PopupMenuEntry<Duration>>[
              for (final Duration d in GridScreen.playIntervals)
                CheckedPopupMenuItem<Duration>(
                  value: d,
                  checked: _interval == d,
                  child: Text(_intervalLabel(d)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(_intervalLabel(_interval),
                      style: TextStyle(
                          color: _live
                              ? cs.onPrimary
                              : cs.onSurfaceVariant)),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: _legendVisible ? 'Hide legend' : 'Show legend',
            icon: Icon(_legendVisible
                ? Icons.info
                : Icons.info_outline),
            onPressed: () =>
                setState(() => _legendVisible = !_legendVisible),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              ready
                  ? '${visible.length} in fabric · ${mc.known.length} '
                      'known · ${mc.favorites.length} contact'
                      '${mc.favorites.length == 1 ? '' : 's'}'
                      ' · ${_live ? 'live (${_intervalLabel(_interval)})' : 'paused'}'
                  : 'Not connected — Settings → Diagnostics & connect',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
          // Range scale slider — six discrete stops from Room (25 m)
          // out to Wide (5 km, default). Affects how the GPS-distance
          // branch projects onto the outer ring (RSSI-only nodes still
          // use their fractional rings as before, but the legend label
          // tracks the selected scale so the user knows what the rings
          // mean at a glance).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: <Widget>[
                Text('Range',
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        letterSpacing: 1)),
                Expanded(
                  child: Slider(
                    value: _scaleIndex.toDouble(),
                    min: 0,
                    max: (GridScreen.rangeStops.length - 1).toDouble(),
                    divisions: GridScreen.rangeStops.length - 1,
                    label: scaleStop.label,
                    onChanged: (double v) => setState(() {
                      _userInteracted = true;
                      _scaleIndex = v.round();
                    }),
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    '${scaleStop.label} · '
                    '${scaleStop.km < 1
                            ? '${(scaleStop.km * 1000).round()} m'
                            : '${scaleStop.km.toStringAsFixed(scaleStop.km < 10 ? 0 : 0)} km'}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (_legendVisible) _GridLegend(cs: cs, scaleKm: scaleKm),
          const Divider(height: 1),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'No fabric in range yet.\n\nNodes appear here as '
                        'their adverts are heard. Star a node in '
                        'Nodes to mark it as a contact (rapid blink). '
                        'Nodes we DM with become known (pulse).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (BuildContext _, BoxConstraints c) {
                      final Size area =
                          Size(c.maxWidth, c.maxHeight);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (TapDownDetails d) {
                          final DiscoveredNode? hit = _hitTest(
                            tap: d.localPosition,
                            area: area,
                            visible: visible,
                            selfLat: mc.selfInfo?.latitude,
                            selfLon: mc.selfInfo?.longitude,
                          );
                          if (hit != null) {
                            _showDetail(context, mc, hit);
                          }
                        },
                        child: AnimatedBuilder(
                          animation: _tick,
                          builder: (BuildContext _, Widget? __) =>
                              CustomPaint(
                            size: area,
                            painter: _GridPainter(
                              nodes: visible,
                              favorites: mc.favorites,
                              known: mc.known,
                              selfLat: mc.selfInfo?.latitude,
                              selfLon: mc.selfInfo?.longitude,
                              nowUnix: nowUnix,
                              windowSec: windowSec,
                              tick: _tick.value,
                              reduceMotion: tc.reduceMotion,
                              accent: cs.primary,
                              subtle: cs.onSurface.withValues(alpha: .12),
                              ringStroke:
                                  cs.outline.withValues(alpha: .35),
                              base: cs.onSurfaceVariant,
                              rippleAt: _rippleAt,
                              rippleDuration: _rippleDuration,
                              scaleKm: scaleKm,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Text(
              'Outer ring ≈ ${scaleStop.label.toLowerCase()} '
              '(${scaleStop.km < 1 ? '${(scaleStop.km * 1000).round()} m' : '${scaleStop.km.toStringAsFixed(0)} km'}) · '
              'tap a node for details · info icon for the legend',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggleable legend overlay strip. Explains what the rings, the
/// node glyphs, the animations, and the ripple mean — every cue is
/// in here so a new user can decode the grid at a glance.
class _GridLegend extends StatelessWidget {
  const _GridLegend({required this.cs, required this.scaleKm});
  final ColorScheme cs;
  final double scaleKm;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 14, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 12,
                        height: 1.35)),
              ),
            ],
          ),
        );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('LEGEND',
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 3)),
          const SizedBox(height: 6),
          row(Icons.adjust,
              'Three concentric rings = distance bands. With GPS '
              'on both ends, the outer ring is the **Range** scale '
              'above (~${scaleKm < 1 ? '${(scaleKm * 1000).round()} m' : '${scaleKm.toStringAsFixed(0)} km'} '
              'right now). Without GPS, rings are RSSI bands '
              '(near / mid / far).'),
          row(Icons.my_location,
              'Centre marker = you. Cross-hair = N-S / E-W guide.'),
          row(Icons.circle,
              'Dot = a fabric node we\'ve heard. Brightness = recency '
              '(full = just now, fades to 0 over 24 h then disappears).'),
          row(Icons.radio_button_checked,
              'Pulse (slow growing halo) = a known node — we have had '
              'a direct attributable exchange (DM) with them.'),
          row(Icons.star,
              'Rapid blink in alt-colour = a favourited contact.'),
          row(Icons.waves,
              'Centre-out ripple = an anonymous channel message (the '
              'protocol doesn\'t attribute channel msgs to a sender).'),
          row(Icons.touch_app,
              'Tap a node to see details + Message / Favourite.'),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.nodes,
    required this.favorites,
    required this.known,
    required this.selfLat,
    required this.selfLon,
    required this.nowUnix,
    required this.windowSec,
    required this.tick,
    required this.reduceMotion,
    required this.accent,
    required this.subtle,
    required this.ringStroke,
    required this.base,
    required this.rippleAt,
    required this.rippleDuration,
    required this.scaleKm,
  });

  final List<DiscoveredNode> nodes;
  final Set<String> favorites;
  final Set<String> known;
  final double? selfLat;
  final double? selfLon;
  final int nowUnix;
  final int windowSec;
  final double tick; // 0..1, repeating
  final bool reduceMotion;
  final Color accent;
  final Color subtle;
  final Color ringStroke;
  final Color base;
  final DateTime? rippleAt;
  final Duration rippleDuration;
  final double scaleKm;

  static bool _selfHasGpsStatic(double? lat, double? lon) =>
      lat != null && lon != null && !(lat == 0 && lon == 0);

  /// Stable arbitrary angle from pubkey (so a node doesn't jump).
  static double _hashAngle(String pubKeyHex) {
    final String head =
        pubKeyHex.length >= 4 ? pubKeyHex.substring(0, 4) : pubKeyHex;
    final int v = int.tryParse(head, radix: 16) ?? 0;
    return (v / 0xFFFF) * 2 * math.pi;
  }

  /// RSSI → ring index 0 (near) / 1 (mid) / 2 (far).
  static int _ringFromRssi(int? rssi) {
    if (rssi == null) return 2;
    if (rssi >= -60) return 0;
    if (rssi >= -90) return 1;
    return 2;
  }

  /// Pure position math — same logic the painter uses, exposed so
  /// `GridScreen` can hit-test taps against the rendered fleet
  /// without re-deriving it (no animation phase is involved, so this
  /// is stable per node per snapshot). [scaleKm] is the outer-ring
  /// scale (km) selected via the Range slider.
  static Offset positionFor({
    required DiscoveredNode node,
    required Offset center,
    required double maxR,
    required double? selfLat,
    required double? selfLon,
    required double scaleKm,
  }) {
    final bool selfGps = _selfHasGpsStatic(selfLat, selfLon);
    final double angle;
    final double radius;
    if (selfGps && node.hasLocation) {
      final double dKm = geo.haversineMeters(
              selfLat!, selfLon!, node.latitude!, node.longitude!) /
          1000.0;
      radius = (dKm / scaleKm).clamp(0.05, 1.0) * maxR;
      angle = geo.bearingRadians(
          selfLat, selfLon, node.latitude!, node.longitude!);
    } else if (node.rssi != null) {
      final int ringIdx = _ringFromRssi(node.rssi);
      radius = maxR * <double>[1 / 3, 2 / 3, 1.0][ringIdx];
      angle = _hashAngle(node.pubKeyHex);
    } else {
      radius = maxR;
      angle = _hashAngle(node.pubKeyHex);
    }
    return center +
        Offset(radius * math.sin(angle), -radius * math.cos(angle));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double maxR = math.min(size.width, size.height) / 2 - 24;
    if (maxR <= 0) return;

    // Concentric range rings.
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ringStroke;
    for (final double f in <double>[1 / 3, 2 / 3, 1.0]) {
      canvas.drawCircle(center, maxR * f, ring);
    }
    // Cross-hair guides (faint).
    final Paint cross = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = subtle;
    canvas.drawLine(Offset(center.dx - maxR, center.dy),
        Offset(center.dx + maxR, center.dy), cross);
    canvas.drawLine(Offset(center.dx, center.dy - maxR),
        Offset(center.dx, center.dy + maxR), cross);

    // Self marker.
    canvas.drawCircle(center, 5, Paint()..color = accent);
    canvas.drawCircle(center, 9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent.withValues(alpha: .6));

    // R18 anonymous-channel ripple: an incoming channel message is
    // not attributable to a node, so draw a transient centre-out
    // wave instead of a node marker. Honours reduce-motion: skipped.
    if (!reduceMotion && rippleAt != null) {
      final int ageMs =
          DateTime.now().difference(rippleAt!).inMilliseconds;
      final double t = ageMs / rippleDuration.inMilliseconds;
      if (t >= 0 && t < 1) {
        canvas.drawCircle(
          center,
          maxR * t,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = accent.withValues(alpha: (1 - t) * 0.7),
        );
      }
    }

    for (final DiscoveredNode n in nodes) {
      // Recency → brightness (linear 24h decay).
      final double age = (nowUnix - n.lastHeardUnix) / windowSec;
      final double bright = (1.0 - age).clamp(0.0, 1.0);
      if (bright <= 0) continue;

      final Offset p = positionFor(
        node: n,
        center: center,
        maxR: maxR,
        selfLat: selfLat,
        selfLon: selfLon,
        scaleKm: scaleKm,
      );

      final bool isFav = favorites.contains(n.pubKeyHex);
      final bool isKnown = known.contains(n.pubKeyHex);

      // Animation phases.
      double scale = 1.0;
      double opacityMul = 1.0;
      if (!reduceMotion) {
        if (isFav) {
          // Rapid blink ~5 Hz: on for half the cycle.
          final double phase = (tick * 5 * 2) % 1;
          opacityMul = phase < 0.5 ? 1.0 : 0.35;
        } else if (isKnown) {
          // Pulse ~0.7 Hz: gentle sine.
          final double s =
              0.5 + 0.5 * math.sin(tick * 2 * math.pi * 2.8);
          scale = 0.9 + 0.4 * s;
        }
      }

      final double r0 = (isFav || isKnown ? 6.0 : 4.0) * scale;
      final Color c = accent.withValues(alpha: bright * opacityMul);
      canvas.drawCircle(p, r0, Paint()..color = c);

      // Reduce-motion accessibility ring: known = thin ring; fav =
      // thicker ring (info preserved without animation).
      if (reduceMotion && (isKnown || isFav)) {
        canvas.drawCircle(
          p,
          r0 + (isFav ? 5 : 3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isFav ? 2 : 1.2
            ..color = accent.withValues(alpha: bright * .8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.nodes != nodes ||
      old.favorites != favorites ||
      old.known != known ||
      old.tick != tick ||
      old.reduceMotion != reduceMotion ||
      old.rippleAt != rippleAt ||
      old.scaleKm != scaleKm;
}
