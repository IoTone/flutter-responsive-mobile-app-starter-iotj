// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:meshcore/meshcore.dart' show SelfInfo;
import 'package:latlong2/latlong.dart' hide Path; // collides with ui.Path
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/city_lookup.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';
import '../util/lora_range.dart';
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

  /// Stage 3 — OSM tile zoom level picked to roughly match the cell
  /// resolution. OSM resolution at zoom z (equator) is
  /// 156 543 / 2^z m/px; we want a tile pixel scale comparable to
  /// the painter's metre/pixel ratio so the basemap reads as the
  /// same kind of zoom as the overlay. Rough table:
  ///   5 m cells   → z 18   (~0.6 m/px)
  ///  20 m cells   → z 17   (~1.2 m/px)
  /// 100 m cells   → z 16   (~2.4 m/px)
  /// 200 m cells   → z 15   (~4.8 m/px)
  /// 500 m cells   → z 14   (~10  m/px)
  /// 1 km cells    → z 13   (~20  m/px)
  static double _tileZoomForCellMeters(double cellM) {
    if (cellM <= 8) return 18.0;
    if (cellM <= 30) return 17.0;
    if (cellM <= 150) return 16.0;
    if (cellM <= 300) return 15.0;
    if (cellM <= 700) return 14.0;
    return 13.0;
  }

  @override
  State<EqualGridView> createState() => _EqualGridViewState();
}

class _EqualGridViewState extends State<EqualGridView> {
  /// Cached size of the last paint pass so the tap hit-test can run
  /// in the same coordinate space the painter used.
  Size? _lastPaintSize;

  /// R25+1 — user zoom override on top of the auto-scale cell size
  /// piped in from the parent. Positive steps shrink cells (zoom in),
  /// negative steps grow cells (zoom out). Each step changes cell
  /// size by a factor of 2. Range is clamped so the user can't
  /// drive into impossible territory (sub-1m or hundreds-of-km).
  int _zoomSteps = 0;
  static const int _zoomStepMin = -4; // up to 16× wider
  static const int _zoomStepMax = 3; // up to 8× tighter
  double get _effectiveCellSizeMeters =>
      widget.cellSizeMeters * math.pow(2.0, -_zoomSteps);

  /// R25+3.1 — show / hide the NERV-style stats panel. The user
  /// asked for a way to declutter back to the clean R25+1 look on
  /// demand; cell highlight stays either way. In-memory only —
  /// reopening the view resets to "show". Persisting would be
  /// overkill for a one-tap toggle.
  bool _showStats = true;

  /// R25+1 — magnetic-compass heading (degrees from N, clockwise).
  /// Null until the first event arrives. Drives the heading arrow
  /// on the self pin; matches the radial-grid view's semantics.
  double? _headingDeg;
  StreamSubscription<CompassEvent>? _compassSub;

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
    // R25+1 — subscribe to compass heading. Same sensor source as
    // the radial grid; on platforms without a magnetometer
    // flutter_compass returns null and we just don't draw the arrow.
    _compassSub = FlutterCompass.events?.listen((CompassEvent e) {
      if (!mounted) return;
      final double? h = e.heading;
      if (h == null) return;
      // Throttle setState to whole-degree changes — the painter
      // doesn't care about sub-degree precision and we'd otherwise
      // repaint every sensor sample.
      if (_headingDeg != null && (h - _headingDeg!).abs() < 1.0) {
        return;
      }
      setState(() => _headingDeg = h);
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  void _zoomIn() {
    if (_zoomSteps >= _zoomStepMax) return;
    setState(() => _zoomSteps++);
  }

  void _zoomOut() {
    if (_zoomSteps <= _zoomStepMin) return;
    setState(() => _zoomSteps--);
  }

  void _zoomReset() {
    if (_zoomSteps == 0) return;
    setState(() => _zoomSteps = 0);
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

    final double cellMeters = _effectiveCellSizeMeters;
    // R25+1 — estimate signal radius from our own radio params so
    // each peer (and we ourselves) can render an "approximate reach"
    // circle on the painter. We don't get peer TX/SF/BW over the
    // wire — the mesh requires all nodes share SF/BW/CR so this is
    // a reasonable proxy for them too. Falls back to a sensible
    // default if SelfInfo hasn't loaded yet.
    final SelfInfo? si = mc.selfInfo;
    final double estimatedRangeM = si == null
        ? 1500.0
        : estimatedLoraRangeMeters(
            spreadingFactor: si.spreadingFactor,
            bandwidthKhz: si.bandwidthKhz,
            txPowerDbm: si.txPowerDbm,
          );

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
          // R25 Stage 3 + R25+1 themed — OSM raster tile background.
          // Wrapped in a ColorFiltered with BlendMode.color so the
          // basemap hue picks up the active theme accent (Seele /
          // Nerv / Hyperlocal / …). Locked to the self-anchor; no
          // user pan/zoom on the underlying map (zoom is via the
          // dedicated +/- buttons over the cell scale).
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                cs.primary.withValues(alpha: .35),
                BlendMode.color,
              ),
              child: FlutterMap(
                // ValueKey forces a fresh FlutterMap (and thus a fresh
                // `initialCenter` / `initialZoom`) when the user
                // changes the effective cell size or our own location
                // updates. Cheaper than wiring a MapController +
                // .move() since the map is locked anyway.
                key: ValueKey<String>(
                    '${selfLat.toStringAsFixed(4)}_'
                    '${selfLon.toStringAsFixed(4)}_'
                    '$cellMeters'),
                options: MapOptions(
                  initialCenter: LatLng(selfLat, selfLon),
                  initialZoom:
                      EqualGridView._tileZoomForCellMeters(cellMeters),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                  backgroundColor: cs.surfaceContainerHighest,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    // OSM tile policy requires a non-default
                    // User-Agent that identifies the app.
                    userAgentPackageName:
                        'com.iotone.meshmore_sns_app',
                  ),
                ],
              ),
            ),
          ),
          // Theme darken/lighten overlay — sits on top of the tinted
          // tiles to settle them into the theme's surface tone, so
          // the cell glyphs above always have a comfortable contrast.
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: cs.surface.withValues(alpha: .25),
              ),
            ),
          ),
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
                  cellSizeMeters: cellMeters,
                  cellLine: cs.outline.withValues(alpha: .35),
                  cellLabel:
                      cs.onSurfaceVariant.withValues(alpha: .85),
                  selfPin: cs.primary,
                  peerCompanion: cs.tertiary,
                  peerRepeater: cs.primary,
                  badgeFill: cs.tertiaryContainer,
                  badgeText: cs.onTertiaryContainer,
                  trail: mc.ownTrail,
                  trailColor: cs.secondary,
                  headingDeg: _headingDeg,
                  estimatedRangeMeters: estimatedRangeM,
                  rangeRing: cs.tertiary.withValues(alpha: .25),
                ),
              );
            }),
          ),
          // R25+3 — NERV-style stats panel pinned to the top of the
          // view. Floats above the basemap + cell overlay; never
          // intercepts pointer events so taps still hit peers.
          // R25+3.1 — collapsible via the toolbar toggle below.
          if (_showStats)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: IgnorePointer(
              child: _NervStatsPanel(
                cellLat: selfLat,
                cellLon: selfLon,
                cellSizeMeters: cellMeters,
                peerCount: withLoc.length,
                nearestPeerMeters: _nearestPeerMeters(
                    withLoc, selfLat, selfLon),
                nearestPeerName: _nearestPeerName(
                    withLoc, selfLat, selfLon),
                estimatedRangeMeters: estimatedRangeM,
                headingDeg: _headingDeg,
                altitudeMeters: mc.ownLocation?.altitudeMeters,
                accent: cs.primary,
                bg: cs.surface.withValues(alpha: .80),
                border: cs.primary.withValues(alpha: .60),
              ),
            ),
          ),
          // R25+1 — Zoom controls + cell-size readout. The +/- pair
          // shrinks/grows the cell size by 2× per tap on top of the
          // radial-range-derived base; long-press the readout to
          // reset to base zoom.
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: cs.surface.withValues(alpha: .85),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                    color: cs.outline.withValues(alpha: .4)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: l.equalGridZoomOut,
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.remove),
                      onPressed: _zoomSteps > _zoomStepMin
                          ? _zoomOut
                          : null,
                    ),
                    GestureDetector(
                      onLongPress: _zoomReset,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4),
                        child: Text(
                          l.equalGridCellSize(
                              _formatMeters(cellMeters)),
                          style: TextStyle(
                              color: cs.onSurface,
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 1),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.equalGridZoomIn,
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.add),
                      onPressed: _zoomSteps < _zoomStepMax
                          ? _zoomIn
                          : null,
                    ),
                    // R25+3.1 — show/hide the NERV stats panel.
                    // Decluttering the view back to the original
                    // R25+1 "circles + futuristic" look is one tap;
                    // bringing the panel back is the same tap again.
                    Container(
                      width: 1,
                      height: 18,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 2),
                      color: cs.outline.withValues(alpha: .4),
                    ),
                    IconButton(
                      tooltip: _showStats
                          ? l.equalGridHideStats
                          : l.equalGridShowStats,
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                      icon: Icon(_showStats
                          ? Icons.dashboard
                          : Icons.dashboard_outlined),
                      onPressed: () =>
                          setState(() => _showStats = !_showStats),
                    ),
                  ],
                ),
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
    final double cellM = _effectiveCellSizeMeters;
    final double cellPx =
        _EqualGridPainter.cellPixels(size, cellM);
    DiscoveredNode? best;
    double bestSq = 24 * 24;
    for (final DiscoveredNode n in peers) {
      final Offset p = _EqualGridPainter.projectPeer(
        centre: centre,
        cellPx: cellPx,
        cellMeters: cellM,
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

  /// R25+3 — distance to the geographically-closest peer with a known
  /// lat/lon, in metres. Returns null when no peers have location.
  static double? _nearestPeerMeters(
      List<DiscoveredNode> peers, double selfLat, double selfLon) {
    const double earthM = 6371000.0;
    double? best;
    for (final DiscoveredNode n in peers) {
      final double dLat =
          (n.latitude! - selfLat) * math.pi / 180.0;
      final double dLon =
          (n.longitude! - selfLon) * math.pi / 180.0;
      final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(selfLat * math.pi / 180.0) *
              math.cos(n.latitude! * math.pi / 180.0) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      final double d = 2 * earthM * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      if (best == null || d < best) best = d;
    }
    return best;
  }

  static String? _nearestPeerName(
      List<DiscoveredNode> peers, double selfLat, double selfLon) {
    const double earthM = 6371000.0;
    DiscoveredNode? best;
    double bestD = double.infinity;
    for (final DiscoveredNode n in peers) {
      final double dLat =
          (n.latitude! - selfLat) * math.pi / 180.0;
      final double dLon =
          (n.longitude! - selfLon) * math.pi / 180.0;
      final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(selfLat * math.pi / 180.0) *
              math.cos(n.latitude! * math.pi / 180.0) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      final double d = 2 * earthM * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      if (d < bestD) {
        bestD = d;
        best = n;
      }
    }
    if (best == null) return null;
    return best.name.isEmpty ? best.shortId : best.name;
  }
}

/// R25+3 — Evangelion / NERV style targeting panel pinned to the top
/// of the equal-grid view. Monospace, narrow fixed-width segments
/// separated by `//`. Reads the current cell's city / coord label
/// from the offline GeoNames lookup (Stage 2 dependency); falls
/// back to grid coords when no city is nearby.
class _NervStatsPanel extends StatelessWidget {
  const _NervStatsPanel({
    required this.cellLat,
    required this.cellLon,
    required this.cellSizeMeters,
    required this.peerCount,
    required this.nearestPeerMeters,
    required this.nearestPeerName,
    required this.estimatedRangeMeters,
    required this.headingDeg,
    required this.altitudeMeters,
    required this.accent,
    required this.bg,
    required this.border,
  });

  final double cellLat;
  final double cellLon;
  final double cellSizeMeters;
  final int peerCount;
  final double? nearestPeerMeters;
  final String? nearestPeerName;
  final double estimatedRangeMeters;
  final double? headingDeg;
  final double? altitudeMeters;
  final Color accent;
  final Color bg;
  final Color border;

  String _fmtMeters(double m) {
    if (m < 1000) return '${m.round()} m';
    final double km = m / 1000.0;
    return km < 10
        ? '${km.toStringAsFixed(1)} km'
        : '${km.round()} km';
  }

  String _cardinal(double deg) {
    const List<String> dirs = <String>[
      'N',
      'NE',
      'E',
      'SE',
      'S',
      'SW',
      'W',
      'NW'
    ];
    return dirs[((deg + 22.5) ~/ 45) % 8];
  }

  @override
  Widget build(BuildContext context) {
    // City label via the offline DB; defaults to "—" when unloaded /
    // unmapped. Cells smaller than ~the cell size are off-the-grid
    // points so we use the same lookup-radius heuristic as the
    // painter — half-diagonal of the current cell.
    final String? cityLabel = labelForCell(
      centreLat: cellLat,
      centreLon: cellLon,
      cellSizeMeters: cellSizeMeters,
    );
    final String gridLabel = cityLabel ?? '—';

    String entry(String key, String val) =>
        '$key // ${val.toUpperCase()}';

    final List<String> bits = <String>[
      entry('LOC', gridLabel),
      entry('PEERS', '$peerCount'),
      if (nearestPeerMeters != null)
        entry(
            'NEAR',
            '${_fmtMeters(nearestPeerMeters!)} '
                '· ${(nearestPeerName ?? '').substring(0, math.min(8, (nearestPeerName ?? '').length))}'),
      entry('REACH', _fmtMeters(estimatedRangeMeters)),
      if (headingDeg != null)
        entry('HDG',
            '${headingDeg!.toStringAsFixed(0)}° ${_cardinal(headingDeg!)}'),
      if (altitudeMeters != null)
        entry('ALT', '${altitudeMeters!.round()} m'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border, width: 1.0),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header strip — fake NERV ID and tag bracket.
          Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                color: accent,
              ),
              const SizedBox(width: 4),
              Text('[ MESHMORE :: HYPERLOCAL :: TARGETING ]',
                  style: TextStyle(
                      color: accent,
                      fontFamily: 'monospace',
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          // Stats wrap — flows onto multiple lines on narrow screens.
          Wrap(
            spacing: 14,
            runSpacing: 2,
            children: <Widget>[
              for (final String b in bits)
                Text(b,
                    style: TextStyle(
                        color: accent,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.15,
                        letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
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
    required this.trail,
    required this.trailColor,
    required this.headingDeg,
    required this.estimatedRangeMeters,
    required this.rangeRing,
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

  /// R25+1 — list of recent own-location samples (oldest first).
  /// Empty list = no trail drawn. Each point's recency tunes the
  /// stroke alpha so the oldest fades and the newest is solid.
  final List<({double latitude, double longitude, int unixSec})>
      trail;
  final Color trailColor;

  /// R25+1 — current magnetic-compass heading in degrees from N
  /// (clockwise). Null when the sensor isn't available; the arrow
  /// just isn't drawn in that case.
  final double? headingDeg;

  /// R25+1 — estimated LoRa reach for our radio tuple. Drawn as a
  /// faint ring around our own pin AND around each peer (mesh
  /// nodes share SF/BW/CR so the same radius is a reasonable proxy
  /// for them too — see lora_range.dart).
  final double estimatedRangeMeters;
  final Color rangeRing;

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
    final Paint currentCellFill = Paint()
      ..color = selfPin.withValues(alpha: .12);
    final Paint currentCellBorder = Paint()
      ..color = selfPin.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int cx = -colsHalf; cx <= colsHalf; cx++) {
      for (int cy = -rowsHalf; cy <= rowsHalf; cy++) {
        final Rect cellRect = Rect.fromLTWH(
          centre.dx + cx * cellPx - cellPx / 2,
          centre.dy + cy * cellPx - cellPx / 2,
          cellPx,
          cellPx,
        );
        // R25+3 — highlight the cell containing self (cx==cy==0).
        // Faint primary-tinted fill + thicker primary border so the
        // user can always find "where am I" at a glance even with
        // the bullseye glyph aside.
        if (cx == 0 && cy == 0) {
          canvas.drawRect(cellRect, currentCellFill);
          canvas.drawRect(cellRect, currentCellBorder);
        } else {
          canvas.drawRect(cellRect, cellStroke);
        }
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

    // R25+1 — estimated signal-range rings. Drawn BEFORE peer glyphs
    // so the glyphs sit on top. We use a single radius value for
    // every node (including self) since the protocol requires all
    // mesh members share SF/BW/CR; TX power may differ but we have
    // no per-peer signal to reflect that yet.
    final double pxPerMeter = cellPx / cellSizeMeters;
    final double rangePx = estimatedRangeMeters * pxPerMeter;
    if (rangePx > 4) {
      final Paint ring = Paint()
        ..color = rangeRing
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      // Self range ring first (under the trail / glyphs).
      canvas.drawCircle(centre, rangePx, ring);
      // Each peer's reach. Skip densely-collapsed cells (the badge
      // already represents many nodes — drawing N overlapping rings
      // is noise).
      for (final MapEntry<({int cx, int cy}),
          List<({DiscoveredNode n, Offset p})>> entry
          in byCell.entries) {
        if (entry.value.length > 8) continue;
        for (final ({DiscoveredNode n, Offset p}) e in entry.value) {
          canvas.drawCircle(e.p, rangePx, ring);
        }
      }
    }

    // R25+1 — own-movement trail. Newest sample is solid; older
    // samples fade. Drawn after rings, before glyphs so peer pins
    // sit on top.
    if (trail.length >= 2) {
      for (int i = 1; i < trail.length; i++) {
        final ({double latitude, double longitude, int unixSec}) a =
            trail[i - 1];
        final ({double latitude, double longitude, int unixSec}) b =
            trail[i];
        final Offset pa = projectPeer(
          centre: centre,
          cellPx: cellPx,
          cellMeters: cellSizeMeters,
          selfLat: selfLat,
          selfLon: selfLon,
          peerLat: a.latitude,
          peerLon: a.longitude,
        );
        final Offset pb = projectPeer(
          centre: centre,
          cellPx: cellPx,
          cellMeters: cellSizeMeters,
          selfLat: selfLat,
          selfLon: selfLon,
          peerLat: b.latitude,
          peerLon: b.longitude,
        );
        // Linear age ramp: oldest segment ~25 % alpha, newest 95 %.
        final double t = (i + 1) / trail.length;
        final Paint p = Paint()
          ..color = trailColor.withValues(alpha: 0.25 + 0.7 * t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(pa, pb, p);
      }
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
    // R25+1 — distinctive self glyph. Three-ring bullseye + bright
    // centre dot + crosshair stroke so we never confuse our own pin
    // with a peer's filled-circle glyph. Optional heading wedge
    // points the direction the phone is facing (from the magnetic
    // compass).
    final Paint haloOuter = Paint()
      ..color = selfPin.withValues(alpha: .18);
    final Paint haloMid = Paint()
      ..color = selfPin.withValues(alpha: .35);
    canvas.drawCircle(at, 18.0, haloOuter);
    canvas.drawCircle(at, 11.0, haloMid);

    // Crosshair strokes through the bullseye — N/S/E/W ticks make
    // the self pin readable even when zoomed way out (where the
    // glyph dot itself collapses to a few pixels).
    final Paint cross = Paint()
      ..color = selfPin.withValues(alpha: .85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(at + const Offset(-14, 0), at + const Offset(-6, 0), cross);
    canvas.drawLine(at + const Offset(6, 0), at + const Offset(14, 0), cross);
    canvas.drawLine(at + const Offset(0, -14), at + const Offset(0, -6), cross);
    canvas.drawLine(at + const Offset(0, 6), at + const Offset(0, 14), cross);

    // Inner solid dot, slightly bigger than a peer dot.
    canvas.drawCircle(at, 6.0, Paint()..color = selfPin);
    canvas.drawCircle(at, 2.5,
        Paint()..color = selfPin.withValues(alpha: 1.0));

    // Heading arrow: small triangular wedge above the bullseye,
    // rotated to the compass heading. Magnetic-north relative — the
    // wedge points the way the phone's top edge is pointing. Hidden
    // when the sensor isn't available.
    if (headingDeg != null) {
      final double hRad = headingDeg! * math.pi / 180.0;
      // Forward unit vector at the heading (screen +y is down, so
      // an "up" on screen is -y).
      final double fx = math.sin(hRad);
      final double fy = -math.cos(hRad);
      // Perpendicular (right-hand) for the wedge's base width.
      final double rx = math.cos(hRad);
      final double ry = math.sin(hRad);
      const double tipDist = 24.0;
      const double baseDist = 14.0;
      const double halfWidth = 6.0;
      final Offset tip = at + Offset(fx * tipDist, fy * tipDist);
      final Offset baseL = at +
          Offset(
              fx * baseDist + rx * halfWidth,
              fy * baseDist + ry * halfWidth);
      final Offset baseR = at +
          Offset(
              fx * baseDist - rx * halfWidth,
              fy * baseDist - ry * halfWidth);
      final Path p = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(baseL.dx, baseL.dy)
        ..lineTo(baseR.dx, baseR.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = selfPin);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualGridPainter old) {
    return selfLat != old.selfLat ||
        selfLon != old.selfLon ||
        cellSizeMeters != old.cellSizeMeters ||
        peers != old.peers ||
        knownPubKeys != old.knownPubKeys ||
        favPubKeys != old.favPubKeys ||
        trail != old.trail ||
        headingDeg != old.headingDeg ||
        estimatedRangeMeters != old.estimatedRangeMeters;
  }
}
