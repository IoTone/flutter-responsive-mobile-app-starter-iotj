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

  /// Nominal outer-range scale (km). The spec says derive from radio
  /// params (SF/BW/freq); using a conservative nominal until that's
  /// wired — beyond this distance a node clamps to the outer ring.
  static const double nominalRangeKm = 5.0;

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

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // arbitrary; we read .value
    )..repeat();
    _msgSub = context
        .read<MeshcoreController>()
        .incomingChannelMessages
        .listen((_) {
      if (mounted) _rippleAt = DateTime.now();
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ThemeController tc = context.watch<ThemeController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool ready = mc.state == MeshcoreConnectionState.ready;

    // Filter visible nodes (within the 24h recency window).
    final int nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int windowSec = GridScreen.recencyWindow.inSeconds;
    final List<DiscoveredNode> visible = <DiscoveredNode>[
      for (final DiscoveredNode n in mc.nodes)
        if (nowUnix - n.lastHeardUnix < windowSec) n
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Hyperlocal grid')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              ready
                  ? '${visible.length} in fabric · ${mc.known.length} '
                      'known · ${mc.favorites.length} contact'
                      '${mc.favorites.length == 1 ? '' : 's'}'
                  : 'Not connected — Settings → Diagnostics & connect',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
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
                    builder: (BuildContext _, BoxConstraints c) =>
                        AnimatedBuilder(
                      animation: _tick,
                      builder: (BuildContext _, Widget? __) =>
                          CustomPaint(
                        size: Size(c.maxWidth, c.maxHeight),
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
                          ringStroke: cs.outline.withValues(alpha: .35),
                          base: cs.onSurfaceVariant,
                          rippleAt: _rippleAt,
                          rippleDuration: _rippleDuration,
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Text(
              'Outer ring ≈ ${GridScreen.nominalRangeKm.toStringAsFixed(0)} km · '
              'pulse = known · rapid blink = contact',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
            ),
          ),
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

  bool _selfHasGps() =>
      selfLat != null && selfLon != null &&
      !(selfLat == 0 && selfLon == 0);

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

    final bool selfGps = _selfHasGps();

    for (final DiscoveredNode n in nodes) {
      // Recency → brightness (linear 24h decay).
      final double age = (nowUnix - n.lastHeardUnix) / windowSec;
      final double bright = (1.0 - age).clamp(0.0, 1.0);
      if (bright <= 0) continue;

      // Position.
      final double angle;
      final double radius;
      if (selfGps && n.hasLocation) {
        final double dKm = geo.haversineMeters(
                selfLat!, selfLon!, n.latitude!, n.longitude!) /
            1000.0;
        radius = (dKm / GridScreen.nominalRangeKm).clamp(0.05, 1.0) * maxR;
        angle = geo.bearingRadians(
            selfLat!, selfLon!, n.latitude!, n.longitude!);
      } else if (n.rssi != null) {
        final int ringIdx = _ringFromRssi(n.rssi);
        radius = maxR * <double>[1 / 3, 2 / 3, 1.0][ringIdx];
        angle = _hashAngle(n.pubKeyHex);
      } else {
        radius = maxR; // abstract outer slot
        angle = _hashAngle(n.pubKeyHex);
      }
      final Offset p = center +
          Offset(radius * math.sin(angle), -radius * math.cos(angle));

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
      old.rippleAt != rippleAt;
}
