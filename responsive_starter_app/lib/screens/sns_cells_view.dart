// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/coverage_store.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';
import '../meshcore/message_heat.dart';
import '../meshcore/own_location.dart';
import '../sns/inferred_place_store.dart';
import '../sns/sns_frame.dart';

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
  final TransformationController _transform = TransformationController();
  int _lastPingSeq = 0;
  String? _flashPubKey; // node to highlight (most recent located DM)
  int _flashUntilMs = 0;

  /// Base scale stop. Default metro (tight local view); cycle out to
  /// region / whole-mesh to see distant nodes (Seattle, Vancouver BC).
  SnsFrame _frame = SnsFrame.metro;

  void _cycleFrame() {
    setState(() => _frame = _frame.next);
    _resetView(); // re-centre on the new base scale
  }

  String _frameLabel(AppLocalizations l, SnsFrame f) => switch (f) {
        SnsFrame.metro => l.snsFrameMetro,
        SnsFrame.region => l.snsFrameRegion,
        SnsFrame.mesh => l.snsFrameMesh,
      };

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  void _resetView() => _transform.value = Matrix4.identity();

  void _onTick(Duration _) {
    // Repaint ~every frame so heat visibly cools and toasts fade.
    // Cheap — the painter only walks active cells (sparse).
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _ingestPing(MeshcoreController mc) {
    final HeatPing? p = mc.lastHeatPing;
    if (p == null || p.seq == _lastPingSeq) return;
    _lastPingSeq = p.seq;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final bool located = p.latitude != null && p.longitude != null;
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
    // Auto-scroll to the sender: a located ping snaps the view back
    // to the fit-to-content frame, which always includes the sender
    // (the painter fits self + every active cell + node). Done in a
    // post-frame callback so we don't mutate the transform mid-build.
    if (located && !_transform.value.isIdentity()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetView();
      });
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
    final Map<String, int> heatCounts = mc.messageHeatCounts();
    // R54 — inferred "place echoes" from channel banter.
    final List<InferredMarker> inferred = mc.inferredPlaces();
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
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 0.4,
            maxScale: 6.0,
            boundaryMargin: const EdgeInsets.all(800),
            child: CustomPaint(
              painter: _SnsCellsPainter(
                selfLat: selfLat,
                selfLon: selfLon,
                maxHalfMeters: _frame.maxHalfMeters,
                heat: heat,
                heatCounts: heatCounts,
                nodes: nodes,
                inferred: inferred,
                toasts: _toasts,
                flashPubKey: _flashPubKey,
                nowMs: now,
                toastLifeMs: _toastLifeMs,
                accent: cs.primary,
                hot: const Color(0xFFFF3030),
                cool: Colors.white,
                node: cs.onSurfaceVariant,
                flash: cs.tertiary,
                infer: const Color(0xFF8A6CFF),
                self: cs.primary,
                label: cs.onSurface,
                toastBg: cs.surface,
                toastBorder: cs.outline,
                bg: cs.surface,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        // Scale stop — cycle metro → region → mesh so distant nodes
        // (Seattle, Vancouver BC) can be framed instead of edge-pinned.
        Positioned(
          left: 12,
          top: 12,
          child: ActionChip(
            avatar: const Icon(Icons.zoom_out_map, size: 16),
            label: Text(_frameLabel(l, _frame)),
            visualDensity: VisualDensity.compact,
            onPressed: _cycleFrame,
          ),
        ),
        // Recenter — fades in when zoomed/panned away from the base
        // fit-to-content view.
        Positioned(
          right: 12,
          top: 12,
          child: AnimatedBuilder(
            animation: _transform,
            builder: (BuildContext _, Widget? __) {
              final bool atIdentity = _transform.value.isIdentity();
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: atIdentity ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: atIdentity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(
                        Icons.center_focus_strong, size: 16),
                    label: Text(l.meshTreeRecenter),
                    onPressed: _resetView,
                  ),
                ),
              );
            },
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
              '${l.snsCellsStatus(heat.length, hotCells)}'
              '${inferred.isNotEmpty ? '  ◇${inferred.length}' : ''}',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 10,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        // Clear-heat control — wipes the accumulated heat + toasts.
        // Useful when moving to a new area or to reset the pulse.
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (inferred.isNotEmpty) ...<Widget>[
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.place_outlined, size: 16),
                  label: Text(l.snsPlacesButton(inferred.length)),
                  onPressed: () => _showPlacesList(
                      context, mc, selfLat, selfLon),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.tonalIcon(
                icon: const Icon(Icons.clear_all, size: 16),
                label: Text(l.snsCellsClear),
                onPressed: () {
                  mc.clearMessageHeat();
                  setState(() {
                    _toasts.clear();
                    _flashPubKey = null;
                    _lastPingSeq = mc.lastHeatPing?.seq ?? 0;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// R54 — a textual list of the inferred places (so distant ones that
  /// pin off-screen are still readable): name · distance · confidence ·
  /// last-hour count · the source banter, each dismissible.
  void _showPlacesList(BuildContext context, MeshcoreController mc,
      double selfLat, double selfLon) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final AppLocalizations l = AppLocalizations.of(ctx);
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return Consumer<MeshcoreController>(
          builder: (BuildContext ctx, MeshcoreController mc, Widget? _) {
            final List<InferredMarker> places = mc.inferredPlaces();
            if (places.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(28),
                child: Text(l.snsPlacesEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant)),
              );
            }
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(l.snsPlacesTitle,
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            letterSpacing: 2)),
                  ),
                  for (final InferredMarker m in places)
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.place_outlined,
                          color: const Color(0xFF8A6CFF),
                          size: 20),
                      title: Text(m.place.displayName),
                      subtitle: Text(
                        '${_SnsCellsPainter._distKm(selfLat, selfLon, m.place.latitude, m.place.longitude).round()} km'
                        '  ·  ${(m.confidence * 100).round()}%'
                        '  ·  ×${m.recentCount}'
                        '\n${m.place.sourceSpan}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 11),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: l.snsPlacesDismiss,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => mc.dismissInferredPlace(m.key),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SnsCellsPainter extends CustomPainter {
  _SnsCellsPainter({
    required this.selfLat,
    required this.selfLon,
    required this.maxHalfMeters,
    required this.heat,
    required this.heatCounts,
    required this.nodes,
    required this.inferred,
    required this.toasts,
    required this.flashPubKey,
    required this.nowMs,
    required this.toastLifeMs,
    required this.accent,
    required this.hot,
    required this.cool,
    required this.node,
    required this.flash,
    required this.infer,
    required this.self,
    required this.label,
    required this.toastBg,
    required this.toastBorder,
    required this.bg,
  });

  final double selfLat;
  final double selfLon;

  /// Cap on the view's half-extent (metres) — the active [SnsFrame].
  final double maxHalfMeters;
  final Map<String, double> heat;
  final Map<String, int> heatCounts;
  final List<DiscoveredNode> nodes;
  final List<InferredMarker> inferred;
  final List<_Toast> toasts;
  final String? flashPubKey;
  final int nowMs;
  final int toastLifeMs;
  final Color accent;
  final Color hot;
  final Color cool;
  final Color node;
  final Color flash;
  final Color infer;
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
    for (final InferredMarker m in inferred) {
      considerLatLon(m.place.latitude, m.place.longitude);
    }
    final double half = snsHalfExtentMeters(maxOffset, maxHalfMeters);
    final double pxPerMeter =
        (math.min(size.width, size.height) * 0.46) / half;

    Offset project(double lat, double lon) {
      final double dN = (lat - selfLat) * _mPerDegLat;
      final double dE = (lon - selfLon) * mPerDegLon;
      return Offset(
          centre.dx + dE * pxPerMeter, centre.dy - dN * pxPerMeter);
    }

    final double cellPx =
        CoverageStore.cellDeg * _mPerDegLat * pxPerMeter;

    // The CRT sweep line position — shared by the grid (for the
    // local magnification/glow as the beam passes) and the glitch
    // overlay (which draws the band itself).
    final double sweepY = ((nowMs % 3200) / 3200.0) * size.height;

    // --- Reference grid (always on, CRT phosphor glow) ---
    // Aligned to the geographic cell lattice so heat squares sit
    // inside grid cells. When cells are too small to read, step by
    // a multiple so lines stay ~16 px+ apart instead of vanishing.
    //
    // Uses the accent colour (not onSurfaceVariant) so it's visible
    // on monochromatic/terminal themes where surface-variant is
    // nearly the background. Each line is drawn as a soft blurred
    // glow + a crisp bright core = phosphor look. Near the sweep
    // line, horizontal lines bow apart (a passing "lens"
    // magnification) and everything brightens.
    final int step = math.max(1, (16 / cellPx).ceil());
    final double gridPx = cellPx * step;

    // Pixel-space origin of the displayed grid lattice: the SW corner
    // of the geographic cell that contains self, projected to pixels.
    // Lines (and heat squares) live on `{origin + k * gridPx}`. Shared
    // by the grid drawing AND the heat fill so heat snaps to — and
    // fills — the same squares the lines outline, instead of floating
    // as fixed-size blobs near the grid corners.
    final double selfCellLon =
        (selfLon / CoverageStore.cellDeg).floor() * CoverageStore.cellDeg;
    final double gridOriginX =
        centre.dx + (selfCellLon - selfLon) * mPerDegLon * pxPerMeter;
    final double selfCellLat =
        (selfLat / CoverageStore.cellDeg).floor() * CoverageStore.cellDeg;
    final double gridOriginY =
        centre.dy - (selfCellLat - selfLat) * _mPerDegLat * pxPerMeter;
    final bool latticeOk = gridPx.isFinite && gridPx >= 2;

    if (latticeOk) {
      const double bandHalf = 34.0; // sweep influence radius (px)
      final Paint glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6);
      final Paint core = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      // Vertical lines (no displacement — beam is horizontal — but
      // brighten the segment that crosses the sweep band).
      double x0 = gridOriginX;
      x0 -= (x0 / gridPx).ceil() * gridPx;
      for (double x = x0; x < size.width; x += gridPx) {
        glow.color = accent.withValues(alpha: 0.10);
        core.color = accent.withValues(alpha: 0.32);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), glow);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), core);
        // Energised segment where the beam crosses.
        canvas.drawLine(
            Offset(x, sweepY - bandHalf),
            Offset(x, sweepY + bandHalf),
            Paint()
              ..strokeWidth = 1.4
              ..color = accent.withValues(alpha: 0.55)
              ..maskFilter =
                  const MaskFilter.blur(BlurStyle.normal, 1.5));
      }

      // Horizontal lines — displaced away from the sweep centre
      // within the band (magnification), brighter the closer they
      // are to the beam.
      double y0 = gridOriginY;
      y0 -= (y0 / gridPx).ceil() * gridPx;
      for (double y = y0; y < size.height; y += gridPx) {
        final double d = y - sweepY;
        double yy = y;
        double bright = 0.0;
        if (d.abs() < bandHalf) {
          final double t = 1.0 - d.abs() / bandHalf; // 0..1 at centre
          // Push the line away from the beam centre — lattice spreads
          // = magnified — by up to ~10 px right at the beam.
          yy = y + d.sign * t * 10.0;
          bright = t;
        }
        glow.color = accent.withValues(alpha: 0.10 + 0.30 * bright);
        core.color = accent.withValues(alpha: 0.32 + 0.45 * bright);
        canvas.drawLine(Offset(0, yy), Offset(size.width, yy), glow);
        canvas.drawLine(Offset(0, yy), Offset(size.width, yy), core);
      }
    }

    // --- Heat cells ---
    // Glitch clock: a coarse time quantum (~7 fps) drives the
    // RGB-split phase so hot cells shimmer like a degrading CRT feed
    // without thrashing every frame.
    final double splitPhase =
        math.sin(nowMs / 220.0); // -1..1, ~0.7 Hz

    // Snap heat into the displayed grid lattice and fill whole grid
    // squares. When zoomed out (e.g. senders spread across WA + BC),
    // many fine geographic cells fall inside one visible grid square;
    // we keep the hottest so the square reads as a solid filled cell
    // aligned to the grid lines, rather than a small blob hovering
    // near a grid corner.
    final Map<(int, int), double> gridHeat = <(int, int), double>{};
    final Map<(int, int), int> gridCount = <(int, int), int>{};
    final List<({Offset centre, double hotness, int count})> looseHeat =
        <({Offset centre, double hotness, int count})>[];
    heat.forEach((String key, double hotness) {
      final ({int latBucket, int lonBucket})? b =
          CoverageStore.parseKey(key);
      if (b == null) return;
      final ({double lat, double lon}) c =
          CoverageStore.cellCentre(b.latBucket, b.lonBucket);
      final Offset cc = project(c.lat, c.lon);
      final int count = heatCounts[key] ?? 0;
      if (latticeOk) {
        final int col = ((cc.dx - gridOriginX) / gridPx).floor();
        final int row = ((cc.dy - gridOriginY) / gridPx).floor();
        final (int, int) k = (col, row);
        final double prev = gridHeat[k] ?? 0.0;
        if (hotness > prev) gridHeat[k] = hotness;
        gridCount[k] = (gridCount[k] ?? 0) + count; // sum over merged cells
      } else {
        looseHeat.add((centre: cc, hotness: hotness, count: count));
      }
    });

    void drawHeatRect(Rect r, double hotness) {
      // white (cool) → red (hot). Floor the alpha at 0.40 so even a
      // single fresh message reads as a solid patch rather than a
      // ghost; ramp to near-opaque when hot.
      final Color fill = Color.lerp(cool, hot, hotness)!
          .withValues(alpha: (0.40 + 0.50 * hotness).clamp(0.0, 0.92));
      canvas.drawRect(r, Paint()..color = fill);

      // RGB-split / chromatic aberration on hot cells — draw a red
      // ghost and a cyan ghost offset opposite ways, amount tied to
      // hotness + the split phase. Reads as a glitchy "signal hot"
      // cue and intensifies as the cell heats up.
      if (hotness > 0.6) {
        final double s = splitPhase * (1.0 + hotness * 2.5);
        final Paint redGhost = Paint()
          ..color =
              const Color(0xFFFF0040).withValues(alpha: 0.30 * hotness)
          ..blendMode = BlendMode.screen;
        final Paint cyanGhost = Paint()
          ..color =
              const Color(0xFF00FFE0).withValues(alpha: 0.22 * hotness)
          ..blendMode = BlendMode.screen;
        canvas.drawRect(r.shift(Offset(s, 0)), redGhost);
        canvas.drawRect(r.shift(Offset(-s, 0)), cyanGhost);
      }
    }

    gridHeat.forEach(((int, int) k, double hotness) {
      final Rect r = Rect.fromLTWH(
        gridOriginX + k.$1 * gridPx,
        gridOriginY + k.$2 * gridPx,
        gridPx,
        gridPx,
      );
      drawHeatRect(r, hotness);
      // Last-hour message count, centred, when the square is big enough
      // to fit a legible digit.
      final int count = gridCount[k] ?? 0;
      if (count > 0 && gridPx >= 16) {
        _drawCount(canvas, r.center, '$count', hotness > 0.55);
      }
    });
    // Degenerate lattice fallback — fixed-size centred squares.
    for (final ({Offset centre, double hotness, int count}) h in looseHeat) {
      drawHeatRect(
        Rect.fromCenter(center: h.centre, width: 12, height: 12),
        h.hotness,
      );
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

    // --- Inferred "place echoes" (R54) ---
    // Distinct ghost markers: a dashed ring + hollow diamond, clearly
    // not a node dot. Confidence drives opacity. Each carries its
    // last-hour mention count. Markers beyond the frame (e.g. a city
    // 200 km away) are pinned to the edge with a direction arrow + the
    // distance, so they aren't lost off-screen.
    final Rect frame = Offset.zero & size;
    final Rect inner = frame.deflate(18);
    for (final InferredMarker m in inferred) {
      final Offset p = project(m.place.latitude, m.place.longitude);
      final double op = (0.40 + 0.55 * m.confidence).clamp(0.0, 1.0);
      if (inner.contains(p)) {
        _drawDashedCircle(canvas, p, 9, infer.withValues(alpha: op * 0.85));
        canvas.drawPath(_diamond(p, 5),
            Paint()..color = infer.withValues(alpha: op * 0.45));
        canvas.drawPath(
            _diamond(p, 5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = infer.withValues(alpha: op));
        _drawInferLabel(
            canvas,
            p.translate(0, -13),
            '${m.place.displayName}  ×${m.recentCount}',
            op);
      } else {
        // Edge-pinned: clamp to the border along the ray from self.
        final Offset edge = _edgePoint(centre, p, inner);
        final double ang = math.atan2(p.dy - centre.dy, p.dx - centre.dx);
        canvas.save();
        canvas.translate(edge.dx, edge.dy);
        canvas.rotate(ang);
        // Small arrow-head pointing outward.
        canvas.drawPath(
            Path()
              ..moveTo(6, 0)
              ..lineTo(-4, -4)
              ..lineTo(-4, 4)
              ..close(),
            Paint()..color = infer.withValues(alpha: op));
        canvas.restore();
        final double km = _distKm(
            selfLat, selfLon, m.place.latitude, m.place.longitude);
        _drawInferLabel(
            canvas,
            edge.translate(0, edge.dy < size.height / 2 ? 12 : -10),
            '${m.place.displayName}  ${km.round()}km ×${m.recentCount}',
            op);
      }
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

    // --- Glitch overlay: CRT scanlines + sweep + occasional tear ---
    _drawGlitch(canvas, size);

    // --- Toasts (drawn on top of scanlines so text stays crisp) ---
    // Located messages (DMs from a positioned sender) toast *over
    // the sender*, rising as they age. Unlocated / anonymous channel
    // messages can't be placed — instead of piling on our crosshair
    // (which read as "from me"), they stack as banners down from the
    // top so the chatter is visible without lying about its origin.
    int bannerSlot = 0;
    for (final _Toast t in toasts) {
      final double age = (nowMs - t.createdMs) / toastLifeMs;
      if (age >= 1.0) continue;
      final double opacity = age < 0.15
          ? age / 0.15 // fade in
          : (1.0 - (age - 0.15) / 0.85).clamp(0.0, 1.0); // hold + out
      final bool located = t.lat != null && t.lon != null;
      if (located) {
        final Offset anchor = project(t.lat!, t.lon!);
        final Offset pos = anchor.translate(0, -18 - age * 24);
        _drawToast(canvas, pos, t.text, opacity, t.isChannel);
      } else {
        // Top-banner stack — newest highest. Slide in from the right
        // edge slightly as it appears.
        final double y = 16 + bannerSlot * 26.0;
        final Offset pos = Offset(size.width / 2, y);
        _drawToast(canvas, pos, t.text, opacity, t.isChannel);
        bannerSlot++;
      }
    }
  }

  /// CRT-style glitch layer: static scanlines, a sweeping bright
  /// line, and an occasional horizontal "tear" band that offsets a
  /// slice of the frame. Kept subtle — the heat data is the point,
  /// the glitch is flavour.
  void _drawGlitch(Canvas canvas, Size size) {
    // Static scanlines — dark horizontal lines every 3px.
    final Paint scan = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 3.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
    }

    // Sweeping scan line — one brighter band travelling top→bottom
    // on a ~3.2 s loop.
    final double sweepT = (nowMs % 3200) / 3200.0;
    final double sweepY = sweepT * size.height;
    final Paint sweep = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, sweepY - 14),
        Offset(0, sweepY + 14),
        <Color>[
          accent.withValues(alpha: 0.0),
          accent.withValues(alpha: 0.16),
          accent.withValues(alpha: 0.0),
        ],
        <double>[0.0, 0.5, 1.0],
      );
    canvas.drawRect(
        Rect.fromLTWH(0, sweepY - 14, size.width, 28), sweep);

    // Occasional tear — every few seconds, a thin horizontal slice
    // gets a bright offset bar (RGB-split coloured). Driven by a
    // coarse time hash so it fires irregularly, not on a metronome.
    final int tearWindow = nowMs ~/ 700;
    final int tearHash = Object.hash(tearWindow, 0x5eed);
    if (tearHash % 5 == 0) {
      final double ty =
          (tearHash >> 3 & 0xFF) / 255.0 * size.height;
      final double th = 2.0 + (tearHash >> 11 & 0x3);
      canvas.drawRect(
          Rect.fromLTWH(0, ty, size.width, th),
          Paint()
            ..color = const Color(0xFFFF0040).withValues(alpha: 0.18)
            ..blendMode = BlendMode.screen);
      canvas.drawRect(
          Rect.fromLTWH(0, ty + th, size.width, th),
          Paint()
            ..color = const Color(0xFF00FFE0).withValues(alpha: 0.14)
            ..blendMode = BlendMode.screen);
    }
  }

  static Path _diamond(Offset p, double r) => Path()
    ..moveTo(p.dx, p.dy - r)
    ..lineTo(p.dx + r, p.dy)
    ..lineTo(p.dx, p.dy + r)
    ..lineTo(p.dx - r, p.dy)
    ..close();

  /// Point on rect [r]'s border along the ray from [c] toward [target].
  static Offset _edgePoint(Offset c, Offset target, Rect r) {
    final double dx = target.dx - c.dx;
    final double dy = target.dy - c.dy;
    double t = double.infinity;
    if (dx > 0) t = math.min(t, (r.right - c.dx) / dx);
    if (dx < 0) t = math.min(t, (r.left - c.dx) / dx);
    if (dy > 0) t = math.min(t, (r.bottom - c.dy) / dy);
    if (dy < 0) t = math.min(t, (r.top - c.dy) / dy);
    if (!t.isFinite || t < 0) t = 0;
    return Offset(c.dx + dx * t, c.dy + dy * t);
  }

  static double _distKm(double lat1, double lon1, double lat2, double lon2) {
    const double rad = math.pi / 180.0;
    final double dLat = (lat2 - lat1) * rad;
    final double dLon = (lon2 - lon1) * rad;
    final double a = math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.cos(lat1 * rad) *
            math.cos(lat2 * rad) *
            math.pow(math.sin(dLon / 2), 2).toDouble();
    return 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Centred message count for a heat square.
  void _drawCount(Canvas canvas, Offset c, String text, bool onHot) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: (onHot ? Colors.white : Colors.black).withValues(alpha: .85),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          shadows: <Shadow>[
            Shadow(
                color: (onHot ? Colors.black : Colors.white)
                    .withValues(alpha: .5),
                blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  /// A dashed ring — the "inferred / not a real node" signal.
  void _drawDashedCircle(Canvas canvas, Offset c, double r, Color color) {
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;
    const int dashes = 10;
    final double seg = (2 * math.pi) / (dashes * 2);
    for (int i = 0; i < dashes; i++) {
      final double start = i * 2 * seg;
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r), start, seg, false, p);
    }
  }

  /// Small place-name label above an inferred marker (no box — it's a
  /// soft annotation, not a chat toast).
  void _drawInferLabel(
      Canvas canvas, Offset anchor, String text, double opacity) {
    final String trimmed =
        text.length > 22 ? '${text.substring(0, 22)}…' : text;
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: trimmed,
        style: TextStyle(
          color: infer.withValues(alpha: opacity),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          shadows: const <Shadow>[
            Shadow(color: Color(0xCC000000), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    tp.paint(canvas, Offset(anchor.dx - tp.width / 2, anchor.dy - tp.height));
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
