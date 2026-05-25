// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/city_lookup.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';
import 'node_detail_sheet.dart';

/// R25 Stage 1 — **equal-grid view**. Third view in the hyperlocal
/// grid mode toggle (after radial + globe). The viewport is a
/// rectangular canvas of equal-sized cells, centred on our own
/// location; each peer with a known lat/lon is placed inside the
/// cell its geographic offset falls into, with its position **inside**
/// the cell preserved relative to the cell's geographic footprint.
///
/// Distinct from the globe view: cells are equal in screen space
/// (not Mercator-projected), so cell-to-cell comparison of peer
/// density is honest. Distinct from the radial grid: position is
/// absolute lat/lon, not signal-derived rings.
///
/// Stage 1 ships the structural skeleton only — cells are labelled
/// by **grid coordinates** (A-1, B-2 …). Stage 2 layers GeoNames
/// reverse-geocoded city/POI labels on top. Stage 3 adds an OSM
/// raster tile background under the overlay. Each stage is
/// independently deployable.
class EqualGridView extends StatefulWidget {
  const EqualGridView({
    super.key,
    required this.cellSizeMeters,
    this.filteredNodes,
    this.frozen = false,
  });

  /// Length of one cell's edge in metres. Auto-scaled from the
  /// radial-grid range slider — see [cellSizeForRangeKm].
  final double cellSizeMeters;

  /// Pre-filtered node list piped through from the radial grid (so
  /// the equal-grid honours the same recency window + pause-snapshot
  /// state). Null falls back to `mc.nodes`.
  final List<DiscoveredNode>? filteredNodes;

  /// True iff the radial grid is paused — surfaces a small PAUSED
  /// indicator (matches the globe view's behaviour).
  final bool frozen;

  /// Default mapping from the radial grid's range stop (km) to cell
  /// edge length in metres. Approximately rangeKm × 1000 ÷ 5, so the
  /// visible viewport carries ~5 cells across at any range stop.
  /// Rounded to friendly values per stop.
  static double cellSizeForRangeKm(double rangeKm) {
    if (rangeKm <= 0.030) return 5.0; // Room
    if (rangeKm <= 0.150) return 20.0; // Home
    if (rangeKm <= 0.700) return 100.0; // Block
    if (rangeKm <= 1.500) return 200.0; // Neighborhood
    if (rangeKm <= 3.000) return 500.0; // Area
    return 1000.0; // Wide
  }

  @override
  State<EqualGridView> createState() => _EqualGridViewState();
}

class _EqualGridViewState extends State<EqualGridView> {
  /// Cached size of the last paint pass so the tap hit-test can run
  /// in the same coordinate space the painter used.
  Size? _lastPaintSize;

  @override
  void initState() {
    super.initState();
    // R25 Stage 2 — kick the city DB warm-up if main.dart hasn't
    // already (e.g. on hot-reload). Repaint once it lands so the
    // city labels fill in without waiting for an unrelated
    // controller notification.
    if (CityLookup.cachedOrNull == null) {
      CityLookup.load().then((_) {
        if (mounted) setState(() {});
      }).catchError((Object _) {/* degrade to grid coords */});
    }
  }

  Future<void> _showDetail(
      BuildContext ctx, MeshcoreController mc, DiscoveredNode n) {
    return showModalBottomSheet<void>(
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
        proximity: mc.proximityFor(n),
        recentDms: mc.dmHistoryFor(n.pubKeyHex),
        tags: mc.tagsFor(n.pubKeyHex),
        tagSuggestions: mc.allTags,
        onAddTag: (String t) => mc.addTagTo(n.pubKeyHex, t),
        onRemoveTag: (String t) => mc.removeTagFrom(n.pubKeyHex, t),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    final List<DiscoveredNode> source =
        widget.filteredNodes ?? mc.nodes;
    final List<DiscoveredNode> withLoc = <DiscoveredNode>[
      for (final DiscoveredNode n in source)
        if (n.hasLocation) n
    ];

    // Self anchor: prefer the controller's resolved own-location.
    // No anchor → render an "awaiting GPS" placeholder; without it
    // there's no meaningful origin for the grid.
    final double? selfLat = mc.ownLocation?.latitude;
    final double? selfLon = mc.ownLocation?.longitude;
    if (selfLat == null || selfLon == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.equalGridAwaitingFix,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return GestureDetector(
      onTapUp: (TapUpDetails d) {
        final Size size =
            _lastPaintSize ?? context.size ?? Size.zero;
        if (size.isEmpty) return;
        final DiscoveredNode? hit = _hitTest(
          tap: d.localPosition,
          size: size,
          selfLat: selfLat,
          selfLon: selfLon,
          peers: withLoc,
        );
        if (hit != null) _showDetail(context, mc, hit);
      },
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: LayoutBuilder(builder:
                (BuildContext _, BoxConstraints c) {
              final Size sz = Size(c.maxWidth, c.maxHeight);
              if (_lastPaintSize != sz) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _lastPaintSize = sz;
                });
              }
              return CustomPaint(
                painter: _EqualGridPainter(
                  selfLat: selfLat,
                  selfLon: selfLon,
                  peers: withLoc,
                  knownPubKeys: mc.known,
                  favPubKeys: mc.favorites,
                  cellSizeMeters: widget.cellSizeMeters,
                  cellLine: cs.outline.withValues(alpha: .35),
                  cellLabel: cs.onSurfaceVariant.withValues(alpha: .6),
                  selfPin: cs.primary,
                  peerCompanion: cs.tertiary,
                  peerRepeater: cs.primary,
                  badgeFill: cs.tertiaryContainer,
                  badgeText: cs.onTertiaryContainer,
                ),
              );
            }),
          ),
          // Cell-size readout: tiny chip bottom-right so users can
          // tell "5 m cells" from "1 km cells" without inferring from
          // the range slider.
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: cs.outline.withValues(alpha: .4)),
              ),
              child: Text(
                l.equalGridCellSize(_formatMeters(widget.cellSizeMeters)),
                style: TextStyle(
                    color: cs.onSurface,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 1),
              ),
            ),
          ),
          if (widget.frozen)
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      cs.tertiaryContainer.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.pause,
                        size: 12, color: cs.onTertiaryContainer),
                    const SizedBox(width: 4),
                    Text(l.globePaused,
                        style: TextStyle(
                            color: cs.onTertiaryContainer,
                            fontSize: 10,
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Tap hit-test in the painter's coordinate space. Computes each
  /// peer's screen position via the same projection the painter
  /// uses, picks the nearest within a 24-px radius.
  DiscoveredNode? _hitTest({
    required Offset tap,
    required Size size,
    required double selfLat,
    required double selfLon,
    required List<DiscoveredNode> peers,
  }) {
    final Offset centre = size.center(Offset.zero);
    final double cellPx =
        _EqualGridPainter.cellPixels(size, widget.cellSizeMeters);
    DiscoveredNode? best;
    double bestSq = 24 * 24;
    for (final DiscoveredNode n in peers) {
      final Offset p = _EqualGridPainter.projectPeer(
        centre: centre,
        cellPx: cellPx,
        cellMeters: widget.cellSizeMeters,
        selfLat: selfLat,
        selfLon: selfLon,
        peerLat: n.latitude!,
        peerLon: n.longitude!,
      );
      final double dx = p.dx - tap.dx;
      final double dy = p.dy - tap.dy;
      final double sq = dx * dx + dy * dy;
      if (sq < bestSq) {
        bestSq = sq;
        best = n;
      }
    }
    return best;
  }

  static String _formatMeters(double m) {
    if (m < 1000) return '${m.round()} m';
    final double km = m / 1000.0;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }
}

/// Painter for the equal-grid view. Owns the lat/lon → cell → screen
/// projection so the tap hit-test can reuse the same math.
class _EqualGridPainter extends CustomPainter {
  _EqualGridPainter({
    required this.selfLat,
    required this.selfLon,
    required this.peers,
    required this.knownPubKeys,
    required this.favPubKeys,
    required this.cellSizeMeters,
    required this.cellLine,
    required this.cellLabel,
    required this.selfPin,
    required this.peerCompanion,
    required this.peerRepeater,
    required this.badgeFill,
    required this.badgeText,
  });

  final double selfLat;
  final double selfLon;
  final List<DiscoveredNode> peers;
  final Set<String> knownPubKeys;
  final Set<String> favPubKeys;
  final double cellSizeMeters;
  final Color cellLine;
  final Color cellLabel;
  final Color selfPin;
  final Color peerCompanion;
  final Color peerRepeater;
  final Color badgeFill;
  final Color badgeText;

  /// Earth radius in metres. Used for the equirectangular-ish
  /// projection — accurate enough for the scales we render (≤ tens
  /// of km) without the cost of a full geodesic projection.
  static const double _earthM = 6371000.0;

  /// Cell edge length in pixels. We aim for ~5 cells across the
  /// canvas's shorter side, so cellPx = min(w, h) / 5. With this
  /// scaling, [cellSizeMeters] just controls *what* a single cell
  /// represents — the painter always draws cells at a comfortable
  /// on-screen size regardless of range.
  static double cellPixels(Size size, double _) =>
      math.min(size.width, size.height) / 5.0;

  /// Convert a peer lat/lon to a screen offset using an equirect-
  /// angular projection anchored at (selfLat, selfLon). 1° lat ≈
  /// 111 km; 1° lon ≈ 111 km × cos(lat). Returns the position in
  /// the same pixel space the painter renders into.
  static Offset projectPeer({
    required Offset centre,
    required double cellPx,
    required double cellMeters,
    required double selfLat,
    required double selfLon,
    required double peerLat,
    required double peerLon,
  }) {
    final double dLatRad = (peerLat - selfLat) * math.pi / 180.0;
    final double dLonRad = (peerLon - selfLon) * math.pi / 180.0;
    final double dyM = dLatRad * _earthM; // +north
    final double dxM = dLonRad * _earthM * math.cos(selfLat * math.pi / 180.0);
    final double pxPerMeter = cellPx / cellMeters;
    // Screen +y is down; geographic +y (north) is up → invert dyM.
    return Offset(
      centre.dx + dxM * pxPerMeter,
      centre.dy - dyM * pxPerMeter,
    );
  }

  /// Cell coord like "B-3". Origin (0, 0) is the cell containing the
  /// self pin. Letters increase east; numbers increase south so the
  /// labelling reads naturally on screen.
  static String _coord(int cx, int cy) {
    // Letters: 0 → 'A', 1 → 'B', … negative → 'A-1' style fallback.
    String letter;
    if (cx >= 0 && cx < 26) {
      letter = String.fromCharCode('A'.codeUnitAt(0) + cx);
    } else if (cx < 0 && cx > -27) {
      letter = String.fromCharCode('A'.codeUnitAt(0) + (-cx - 1));
      letter = '-$letter';
    } else {
      letter = cx.toString();
    }
    return '$letter${cy + 1}'; // 1-based row reads more naturally
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double cellPx = cellPixels(size, cellSizeMeters);
    final Paint cellStroke = Paint()
      ..color = cellLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    // Draw all grid lines visible in the viewport. The self cell
    // is the one containing (centre); cells span outwards from
    // there. We enumerate cell indices large enough to cover the
    // canvas in both directions.
    final int colsHalf =
        (size.width / cellPx / 2.0).ceil() + 1;
    final int rowsHalf =
        (size.height / cellPx / 2.0).ceil() + 1;
    // Pre-resolve metres-per-degree at our latitude so per-cell
    // centre-coord math doesn't repeat the cos() in the hot loop.
    const double mPerDegLat = 6371000.0 * math.pi / 180.0;
    final double mPerDegLon =
        mPerDegLat * math.cos(selfLat * math.pi / 180.0);
    for (int cx = -colsHalf; cx <= colsHalf; cx++) {
      for (int cy = -rowsHalf; cy <= rowsHalf; cy++) {
        final Rect cellRect = Rect.fromLTWH(
          centre.dx + cx * cellPx - cellPx / 2,
          centre.dy + cy * cellPx - cellPx / 2,
          cellPx,
          cellPx,
        );
        canvas.drawRect(cellRect, cellStroke);
        // R25 Stage 2 — try the offline city DB first. If the
        // lookup hasn't loaded yet (first frame after launch) OR
        // there's no nearby city, fall back to the grid coord so
        // the label is never empty.
        final double cellCentreLat =
            selfLat + (cy.toDouble() * -1.0) * cellSizeMeters / mPerDegLat;
        final double cellCentreLon =
            selfLon + cx.toDouble() * cellSizeMeters / mPerDegLon;
        final String? city = labelForCell(
            centreLat: cellCentreLat,
            centreLon: cellCentreLon,
            cellSizeMeters: cellSizeMeters);
        final String label = city ?? _coord(cx, cy);
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
                color: cellLabel,
                fontSize: city != null ? 10 : 9,
                fontWeight: city != null
                    ? FontWeight.w500
                    : FontWeight.normal,
                letterSpacing: city != null ? 0.5 : 1,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ]),
          ),
          textDirection: TextDirection.ltr,
          ellipsis: '…',
          maxLines: 1,
        )..layout(maxWidth: cellPx - 8);
        tp.paint(canvas,
            cellRect.topLeft + const Offset(4, 3));
      }
    }

    // Group peers by cell so we can collapse dense cells to a
    // "• × N" badge. Peer screen position is preserved for un-
    // collapsed cells; collapsed cells render at the cell centre.
    final Map<({int cx, int cy}), List<({DiscoveredNode n, Offset p})>>
        byCell = <({int cx, int cy}),
            List<({DiscoveredNode n, Offset p})>>{};
    for (final DiscoveredNode n in peers) {
      final Offset p = projectPeer(
        centre: centre,
        cellPx: cellPx,
        cellMeters: cellSizeMeters,
        selfLat: selfLat,
        selfLon: selfLon,
        peerLat: n.latitude!,
        peerLon: n.longitude!,
      );
      final int cx = ((p.dx - centre.dx) / cellPx).round();
      final int cy = ((p.dy - centre.dy) / cellPx).round();
      byCell
          .putIfAbsent((cx: cx, cy: cy),
              () => <({DiscoveredNode n, Offset p})>[])
          .add((n: n, p: p));
    }

    for (final MapEntry<({int cx, int cy}),
        List<({DiscoveredNode n, Offset p})>> entry in byCell.entries) {
      final List<({DiscoveredNode n, Offset p})> list = entry.value;
      if (list.length > 8) {
        // Density collapse — single badge at the cell centre.
        final Offset cellCentre = Offset(
          centre.dx + entry.key.cx * cellPx,
          centre.dy + entry.key.cy * cellPx,
        );
        _drawBadge(canvas, cellCentre, list.length);
      } else {
        for (final ({DiscoveredNode n, Offset p}) e in list) {
          _drawPeerGlyph(canvas, e.p, e.n);
        }
      }
    }

    // Self pin last so it sits on top of everything.
    _drawSelf(canvas, centre);
  }

  void _drawBadge(Canvas canvas, Offset at, int count) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '• × $count',
        style: TextStyle(
            color: badgeText,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double pad = 6;
    final Rect r = Rect.fromCenter(
      center: at,
      width: tp.width + pad * 2,
      height: tp.height + pad,
    );
    final RRect rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
    canvas.drawRRect(rr, Paint()..color = badgeFill);
    tp.paint(canvas, r.topLeft + Offset(pad, pad / 2));
  }

  void _drawPeerGlyph(Canvas canvas, Offset at, DiscoveredNode n) {
    // Companion/chat nodes (type 1) = dot. Repeaters (type 2) =
    // triangle. Others render as a small ring so a future
    // sensor/room type doesn't disappear silently.
    final bool isRepeater = n.type == 2;
    final Color base = isRepeater ? peerRepeater : peerCompanion;
    final Paint fill = Paint()..color = base;
    if (isRepeater) {
      const double s = 7.0;
      final Path p = Path()
        ..moveTo(at.dx, at.dy - s)
        ..lineTo(at.dx - s, at.dy + s)
        ..lineTo(at.dx + s, at.dy + s)
        ..close();
      canvas.drawPath(p, fill);
    } else if (n.type == 3 || n.type == 4) {
      // Room / Sensor — small open ring.
      canvas.drawCircle(at, 5.0,
          Paint()
            ..color = base
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    } else {
      canvas.drawCircle(at, 5.0, fill);
    }
    // Favourite or known badge: tiny dot above the glyph.
    if (favPubKeys.contains(n.pubKeyHex)) {
      canvas.drawCircle(
          at + const Offset(0, -10), 2.0,
          Paint()..color = peerRepeater);
    } else if (knownPubKeys.contains(n.pubKeyHex)) {
      canvas.drawCircle(
          at + const Offset(0, -10), 2.0,
          Paint()
            ..color = peerCompanion
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
    }
  }

  void _drawSelf(Canvas canvas, Offset at) {
    // Outer halo + inner dot. Subtle ring underneath the glyph cues
    // "you are here" without dominating the view.
    canvas.drawCircle(at, 11.0,
        Paint()..color = selfPin.withValues(alpha: .25));
    canvas.drawCircle(at, 5.0, Paint()..color = selfPin);
  }

  @override
  bool shouldRepaint(covariant _EqualGridPainter old) {
    return selfLat != old.selfLat ||
        selfLon != old.selfLon ||
        cellSizeMeters != old.cellSizeMeters ||
        peers != old.peers ||
        knownPubKeys != old.knownPubKeys ||
        favPubKeys != old.favPubKeys;
  }
}
