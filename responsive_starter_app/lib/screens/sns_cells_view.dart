// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/coverage_store.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';
import '../meshcore/message_heat.dart';
import '../meshcore/own_location.dart';

/// R51 — sns-cells: a social-activity heat map. Built on the same
/// geographic-cell idea as the hyperlocal grid, but instead of
/// plotting *presence* it plots *chatter*: each observed message
/// turns up the heat in its cell (bright red = busy), and cells
/// cool over a one-hour horizon back to faint white.
///
/// When a message arrives it flashes as a toast near its source
/// node and fades. The whole thing is a "social pulse" line — who's
/// talking, where, right now.
class SnsCellsView extends StatefulWidget {
  const SnsCellsView({
    super.key,
    this.filteredNodes,
    this.frozen = false,
  });

  final List<DiscoveredNode>? filteredNodes;
  final bool frozen;

  @override
  State<SnsCellsView> createState() => _SnsCellsViewState();
}

class _Toast {
  _Toast({
    required this.text,
    required this.lat,
    required this.lon,
    required this.createdMs,
    required this.isChannel,
    required this.pubKeyHex,
  });
  final String text;
  final double? lat;
  final double? lon;
  final int createdMs;
  final bool isChannel;
  final String? pubKeyHex;
}

class _SnsCellsViewState extends State<SnsCellsView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  static const int _toastLifeMs = 3500;

  final List<_Toast> _toasts = <_Toast>[];
  int _lastPingSeq = 0;
  String? _flashPubKey; // node to highlight (most recent located DM)
  int _flashUntilMs = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration _) {
    // Repaint ~every frame so heat visibly cools and toasts fade.
    // Cheap — the painter only walks active cells (sparse).
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _ingestPing(MeshcoreController mc) {
    final HeatPing? p = mc.lastHeatPing;
    if (p == null || p.seq == _lastPingSeq) return;
    _lastPingSeq = p.seq;
    final int now = DateTime.now().millisecondsSinceEpoch;
    _toasts.add(_Toast(
      text: p.text,
      lat: p.latitude,
      lon: p.longitude,
      createdMs: now,
      isChannel: p.isChannel,
      pubKeyHex: p.pubKeyHex,
    ));
    if (p.pubKeyHex != null) {
      _flashPubKey = p.pubKeyHex;
      _flashUntilMs = now + _toastLifeMs;
    }
    // Bound the toast list — keep the newest handful.
    while (_toasts.length > 6) {
      _toasts.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);

    if (!widget.frozen) _ingestPing(mc);

    final OwnLocation? own = mc.ownLocation;
    final double? selfLat = own?.latitude;
    final double? selfLon = own?.longitude;

    if (selfLat == null || selfLon == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.snsCellsAwaitingFix,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final Map<String, double> heat = mc.messageHeatScores();
    final List<DiscoveredNode> source =
        widget.filteredNodes ?? mc.nodes;
    final List<DiscoveredNode> nodes = <DiscoveredNode>[
      for (final DiscoveredNode n in source)
        if (n.hasLocation) n,
    ];

    final int now = DateTime.now().millisecondsSinceEpoch;
    _toasts.removeWhere((_Toast t) => now - t.createdMs > _toastLifeMs);
    if (_flashUntilMs < now) _flashPubKey = null;

    final int hotCells =
        heat.values.where((double v) => v >= 0.8).length;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _SnsCellsPainter(
              selfLat: selfLat,
              selfLon: selfLon,
              heat: heat,
              nodes: nodes,
              toasts: _toasts,
              flashPubKey: _flashPubKey,
              nowMs: now,
              toastLifeMs: _toastLifeMs,
              accent: cs.primary,
              hot: const Color(0xFFFF3030),
              cool: Colors.white,
              node: cs.onSurfaceVariant,
              flash: cs.tertiary,
              self: cs.primary,
              label: cs.onSurface,
              toastBg: cs.surface,
              toastBorder: cs.outline,
              bg: cs.surface,
            ),
          ),
        ),
        // Status chip — active cells + hot count.
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: cs.outline.withValues(alpha: .55)),
            ),
            child: Text(
              l.snsCellsStatus(heat.length, hotCells),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 10,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SnsCellsPainter extends CustomPainter {
  _SnsCellsPainter({
    required this.selfLat,
    required this.selfLon,
    required this.heat,
    required this.nodes,
    required this.toasts,
    required this.flashPubKey,
    required this.nowMs,
    required this.toastLifeMs,
    required this.accent,
    required this.hot,
    required this.cool,
    required this.node,
    required this.flash,
    required this.self,
    required this.label,
    required this.toastBg,
    required this.toastBorder,
    required this.bg,
  });

  final double selfLat;
  final double selfLon;
  final Map<String, double> heat;
  final List<DiscoveredNode> nodes;
  final List<_Toast> toasts;
  final String? flashPubKey;
  final int nowMs;
  final int toastLifeMs;
  final Color accent;
  final Color hot;
  final Color cool;
  final Color node;
  final Color flash;
  final Color self;
  final Color label;
  final Color toastBg;
  final Color toastBorder;
  final Color bg;

  static const double _mPerDegLat = 111320.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final Offset centre = size.center(Offset.zero);
    final double mPerDegLon =
        _mPerDegLat * math.cos(selfLat * math.pi / 180).abs();

    // Fit-to-content range: cover the farthest active cell / node,
    // clamped to a sane window so a single distant peer doesn't zoom
    // us out to nothing.
    double maxOffset = 600; // metres, minimum half-extent
    void considerLatLon(double lat, double lon) {
      final double dN = (lat - selfLat) * _mPerDegLat;
      final double dE = (lon - selfLon) * mPerDegLon;
      final double d = math.max(dN.abs(), dE.abs());
      if (d > maxOffset) maxOffset = d;
    }

    heat.forEach((String key, double _) {
      final ({int latBucket, int lonBucket})? b =
          CoverageStore.parseKey(key);
      if (b == null) return;
      final ({double lat, double lon}) c =
          CoverageStore.cellCentre(b.latBucket, b.lonBucket);
      considerLatLon(c.lat, c.lon);
    });
    for (final DiscoveredNode n in nodes) {
      considerLatLon(n.latitude!, n.longitude!);
    }
    final double half = (maxOffset * 1.15).clamp(600.0, 20000.0);
    final double pxPerMeter =
        (math.min(size.width, size.height) * 0.46) / half;

    Offset project(double lat, double lon) {
      final double dN = (lat - selfLat) * _mPerDegLat;
      final double dE = (lon - selfLon) * mPerDegLon;
      return Offset(
          centre.dx + dE * pxPerMeter, centre.dy - dN * pxPerMeter);
    }

    // --- Heat cells ---
    final double cellPx =
        CoverageStore.cellDeg * _mPerDegLat * pxPerMeter;
    heat.forEach((String key, double hotness) {
      final ({int latBucket, int lonBucket})? b =
          CoverageStore.parseKey(key);
      if (b == null) return;
      final ({double lat, double lon}) c =
          CoverageStore.cellCentre(b.latBucket, b.lonBucket);
      final Offset cc = project(c.lat, c.lon);
      final Rect r = Rect.fromCenter(
          center: cc,
          width: math.max(cellPx, 6),
          height: math.max(cellPx, 6));
      // white (cool) → red (hot). Alpha also rises with heat so a
      // near-cool cell stays faint and the map breathes.
      final Color fill = Color.lerp(cool, hot, hotness)!
          .withValues(alpha: (0.20 + 0.62 * hotness).clamp(0.0, 0.85));
      canvas.drawRect(r, Paint()..color = fill);
    });

    // --- Grid lines (faint) for spatial reference ---
    final Paint grid = Paint()
      ..color = node.withValues(alpha: 0.12)
      ..strokeWidth = 0.5;
    if (cellPx >= 12) {
      // Only draw the lattice when cells are big enough to read.
      final double startX = centre.dx % cellPx;
      for (double x = startX; x < size.width; x += cellPx) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
      final double startY = centre.dy % cellPx;
      for (double y = startY; y < size.height; y += cellPx) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }

    // --- Nodes ---
    for (final DiscoveredNode n in nodes) {
      final Offset p = project(n.latitude!, n.longitude!);
      final bool flashing = n.pubKeyHex == flashPubKey;
      if (flashing) {
        // Expanding ring pulse around the active node.
        canvas.drawCircle(
            p,
            10,
            Paint()
              ..color = flash.withValues(alpha: 0.35)
              ..style = PaintingStyle.fill);
        canvas.drawCircle(
            p,
            13,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = flash);
      }
      canvas.drawCircle(p, 3.5,
          Paint()..color = flashing ? flash : node);
    }

    // --- Self pin (crosshair) ---
    final Paint selfPaint = Paint()
      ..color = self
      ..strokeWidth = 1.6;
    canvas.drawLine(centre.translate(-9, 0), centre.translate(9, 0),
        selfPaint);
    canvas.drawLine(centre.translate(0, -9), centre.translate(0, 9),
        selfPaint);
    canvas.drawCircle(centre, 4, Paint()..color = self);

    // --- Toasts ---
    for (final _Toast t in toasts) {
      final double age = (nowMs - t.createdMs) / toastLifeMs;
      if (age >= 1.0) continue;
      final double opacity = age < 0.15
          ? age / 0.15 // fade in
          : (1.0 - (age - 0.15) / 0.85).clamp(0.0, 1.0); // hold + out
      final Offset anchor = (t.lat != null && t.lon != null)
          ? project(t.lat!, t.lon!)
          : centre;
      // Rise slightly as it ages.
      final Offset pos = anchor.translate(0, -18 - age * 24);
      _drawToast(canvas, pos, t.text, opacity, t.isChannel);
    }
  }

  void _drawToast(Canvas canvas, Offset anchor, String text,
      double opacity, bool isChannel) {
    final String trimmed =
        text.length > 40 ? '${text.substring(0, 40)}…' : text;
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: trimmed,
        style: TextStyle(
          color: label.withValues(alpha: opacity),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 200);
    final Rect box = Rect.fromCenter(
      center: anchor,
      width: tp.width + 16,
      height: tp.height + 10,
    );
    final RRect rr = RRect.fromRectAndRadius(box, const Radius.circular(6));
    canvas.drawRRect(
        rr, Paint()..color = toastBg.withValues(alpha: opacity * 0.92));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = (isChannel ? accent : flash)
              .withValues(alpha: opacity * 0.8));
    tp.paint(canvas, Offset(box.left + 8, box.top + 5));
  }

  @override
  bool shouldRepaint(covariant _SnsCellsPainter old) => true;
}
