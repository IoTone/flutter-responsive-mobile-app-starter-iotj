// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';
import 'node_detail_sheet.dart';

/// R27 — macro globe view. Renders the mesh fabric on a 3D earth
/// using **real Natural Earth 110m land polygons** (asset
/// `assets/data/world-110m.geojson`, public domain). Pure Flutter:
/// no WebView, no platform channels.
///
/// Three toggleable overlays:
///   - **arcs** (default ON): great-circle dashed paths from self
///     to each peer with a known location.
///   - **region**: peers within ~10° geohash buckets collapse into
///     a labelled bubble (summary stats over an area).
///   - **labels**: peer names rendered next to each pin.
///
/// Drag to rotate the globe; pitch is clamped at the poles so the
/// user can't flip past. Auto-centres on the user's lat/lon at
/// first opportunity.
class GlobeView extends StatefulWidget {
  const GlobeView({
    super.key,
    this.filteredNodes,
    this.frozen = false,
  });

  /// R40 — when non-null, the globe renders this list verbatim
  /// instead of pulling `mc.nodes` itself. This is how the radial
  /// grid pipes its **pause / play / recency-window** state through
  /// without duplicating filter logic.
  final List<DiscoveredNode>? filteredNodes;

  /// R40 — when true, the globe shows a small "PAUSED" indicator
  /// (the grid is on a frozen snapshot, so the globe is too).
  final bool frozen;

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView> {
  /// Longitude currently at the centre of the projection (degrees).
  /// Initialised to the user's lon on first opportunity.
  double _centreLonDeg = 0;

  /// Latitude currently at the centre of the projection (degrees).
  /// Clamped to ±89° so the user can't flip past the pole.
  double _centreLatDeg = 0;
  bool _centeredOnSelf = false;

  /// R40 — zoom expressed as **camera altitude**. The slider speaks
  /// miles/feet (the user metaphor); the painter speaks `_scale`
  /// (radius multiplier). Conversion below assumes a 60° FOV and a
  /// 3959 mi earth radius — at scale s the visible half-radius on
  /// the ground is ~4399/s mi, which back-solves to altitude ≈
  /// 7625/s mi (since visibleR ≈ alt × tan(30°)).
  ///
  /// Range:
  ///   - **Min altitude = 100 ft** (most zoomed-in; ~70 m visible)
  ///   - **Default = 1 mi** (hyperlocal entry point — see immediate
  ///     neighbourhood and any peers in your block)
  ///   - **Max altitude = ~7625 mi** (whole hemisphere — like
  ///     today's 1.0× default)
  ///
  /// Past about ~50× scale (~150 mi altitude) the Natural Earth
  /// 110m polygons become visibly coarse — at hyperlocal zoom they
  /// disappear off-screen and the canvas is dominated by ocean
  /// colour with your pin + nearby peers, which is the desired
  /// "you are here" feel.
  static const double _altDefaultMi = 1.0;
  static const double _altMinMi = 100.0 / 5280.0; // 100 ft
  static const double _altMaxMi = 7625.0; // ≈ hemisphere
  static double _scaleFromAltMi(double altMi) => 7625.0 / altMi;
  static double _altMiFromScale(double s) => 7625.0 / s;

  /// Map a `_scale` value to a 0..1 slider position, **inverted**
  /// so the slider's left edge is "zoomed out" (high altitude) and
  /// the right edge is "zoomed in" (low altitude). Log-spaced over
  /// `_scaleMin..._scaleMax` because the range spans ~5 decades.
  static double _scaleToSliderPos(double scale) {
    final double logS = math.log(scale.clamp(_scaleMin, _scaleMax));
    final double logMin = math.log(_scaleMin);
    final double logMax = math.log(_scaleMax);
    return (logS - logMin) / (logMax - logMin);
  }

  static double _sliderPosToScale(double pos) {
    final double logMin = math.log(_scaleMin);
    final double logMax = math.log(_scaleMax);
    return math.exp(logMin + (logMax - logMin) * pos.clamp(0.0, 1.0));
  }

  /// Pretty altitude readout. Below 1 mile → ft; otherwise mi.
  /// Mixed unit so a hyperlocal zoom doesn't read "0.02 mi".
  static String _formatAltitude(double altMi) {
    if (altMi < 1.0) {
      final int ft = (altMi * 5280.0).round();
      return '$ft ft';
    }
    if (altMi < 10.0) return '${altMi.toStringAsFixed(1)} mi';
    return '${altMi.round()} mi';
  }

  static final double _scaleMin = _scaleFromAltMi(_altMaxMi); // 1.0
  static final double _scaleMax = _scaleFromAltMi(_altMinMi); // ~402_640
  static final double _scaleDefault =
      _scaleFromAltMi(_altDefaultMi); // 7625

  double _scale = _scaleDefault;
  double _scaleAtGestureStart = _scaleDefault;

  bool _showArcs = true;
  bool _showRegions = false;
  bool _showLabels = false;

  /// Lazily-loaded land polygons (list of rings; each ring is a
  /// list of `[lon, lat]` pairs). Built from the bundled GeoJSON
  /// asset on first frame. Null until loaded.
  List<List<List<double>>>? _land;

  @override
  void initState() {
    super.initState();
    _loadLand();
  }

  Future<void> _loadLand() async {
    try {
      final String raw =
          await rootBundle.loadString('assets/data/world-110m.geojson');
      final Map<String, dynamic> doc =
          jsonDecode(raw) as Map<String, dynamic>;
      // The asset is a FeatureCollection with a single MultiPolygon
      // feature. Flatten to a list of rings — for our visual
      // purposes we don't need to keep polygons grouped.
      final List<List<List<double>>> rings = <List<List<double>>>[];
      final List<dynamic> features = (doc['features'] as List<dynamic>);
      for (final dynamic f in features) {
        final Map<String, dynamic> geom =
            (f as Map<String, dynamic>)['geometry']
                as Map<String, dynamic>;
        final String type = geom['type'] as String;
        if (type == 'Polygon') {
          for (final dynamic ring in geom['coordinates'] as List<dynamic>) {
            rings.add(<List<double>>[
              for (final dynamic pt in ring as List<dynamic>)
                <double>[
                  (pt[0] as num).toDouble(),
                  (pt[1] as num).toDouble(),
                ],
            ]);
          }
        } else if (type == 'MultiPolygon') {
          for (final dynamic poly in geom['coordinates'] as List<dynamic>) {
            for (final dynamic ring in poly as List<dynamic>) {
              rings.add(<List<double>>[
                for (final dynamic pt in ring as List<dynamic>)
                  <double>[
                    (pt[0] as num).toDouble(),
                    (pt[1] as num).toDouble(),
                  ],
              ]);
            }
          }
        }
      }
      if (!mounted) return;
      setState(() => _land = rings);
    } catch (_) {
      // Asset missing / parse failed → fall through with no land.
      if (mounted) setState(() => _land = <List<List<double>>>[]);
    }
  }

  /// Last paint size — written by the painter on every paint pass.
  /// Used by the tap hit-test to convert the tap-local position
  /// into projected sphere coordinates without a second
  /// LayoutBuilder.
  Size? _lastPaintSize;

  void _ensureCenteredOn(double? lat, double? lon) {
    if (_centeredOnSelf) return;
    if (lat == null || lon == null) return;
    _centreLonDeg = lon;
    _centreLatDeg = lat;
    _centeredOnSelf = true;
  }

  /// Duplicate of the painter's projection, public to the state
  /// class so the tap hit-test can reuse it without going through
  /// the painter's private method.
  ({Offset offset, double rotY}) _projectPoint(Offset centre,
      double r, double rotLon, double rotLat, double latDeg,
      double lonDeg) {
    final double lonShift = (lonDeg * math.pi / 180) - rotLon;
    final double lat = latDeg * math.pi / 180;
    final double cl = math.cos(lat);
    final double x = cl * math.sin(lonShift);
    final double y = cl * math.cos(lonShift);
    final double z = math.sin(lat);
    final double c = math.cos(rotLat);
    final double s = math.sin(rotLat);
    final double yr = y * c + z * s;
    final double zr = -y * s + z * c;
    return (
      offset: Offset(centre.dx + x * r, centre.dy - zr * r),
      rotY: yr,
    );
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
        recentDms: mc.dmHistoryFor(n.pubKeyHex),
        proximity: mc.proximityFor(n),
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);

    final double? selfLat = mc.phoneLocationFix?.latitude ??
        ((mc.selfInfo?.latitude ?? 0) == 0
            ? null
            : mc.selfInfo!.latitude);
    final double? selfLon = mc.phoneLocationFix?.longitude ??
        ((mc.selfInfo?.longitude ?? 0) == 0
            ? null
            : mc.selfInfo!.longitude);
    _ensureCenteredOn(selfLat, selfLon);

    // R40 — when the grid hands us a pre-filtered list (its own
    // pause-snapshot + recency window already applied), use it.
    // Otherwise fall back to the controller's live nodes so the
    // globe is still useful when constructed standalone.
    final List<DiscoveredNode> source =
        widget.filteredNodes ?? mc.nodes;
    final List<DiscoveredNode> withLoc = <DiscoveredNode>[
      for (final DiscoveredNode n in source)
        if (n.hasLocation) n
    ];

    return GestureDetector(
      onScaleStart: (_) => _scaleAtGestureStart = _scale,
      onTapUp: (TapUpDetails d) {
        // Hit-test the tap against every visible peer pin. We
        // need the surface size for the projection; LayoutBuilder
        // gave us a Size we cached in `_lastPaintSize` during
        // paint. Fall back to context.size if we haven't painted
        // yet (e.g. first frame race).
        final Size size = _lastPaintSize ?? context.size ?? Size.zero;
        if (size.isEmpty) return;
        final Offset centre = size.center(Offset.zero);
        final double r =
            math.min(size.width, size.height) * 0.45 * _scale;
        final double rotLon = _centreLonDeg * math.pi / 180;
        final double rotLat = _centreLatDeg * math.pi / 180;
        DiscoveredNode? best;
        double bestSq = 24 * 24; // 24-px tap radius²
        for (final DiscoveredNode n in withLoc) {
          final ({Offset offset, double rotY}) pp = _projectPoint(
              centre, r, rotLon, rotLat, n.latitude!, n.longitude!);
          if (pp.rotY < 0) continue;
          final double dx = pp.offset.dx - d.localPosition.dx;
          final double dy = pp.offset.dy - d.localPosition.dy;
          final double sq = dx * dx + dy * dy;
          if (sq < bestSq) {
            bestSq = sq;
            best = n;
          }
        }
        if (best != null) _showDetail(context, mc, best);
      },
      onScaleUpdate: (ScaleUpdateDetails d) {
        // Trackball drag + pinch zoom in one handler. With a single
        // pointer, `scale` is always 1.0 and `focalPointDelta` is
        // the pan delta; with two pointers we get both. Scale-aware
        // drag: when zoomed in (higher _scale), the same pixel
        // distance maps to a smaller angular rotation so the globe
        // doesn't fly past under the finger.
        setState(() {
          _scale = (_scaleAtGestureStart * d.scale)
              .clamp(_scaleMin, _scaleMax);
          final double k = 0.5 / _scale;
          _centreLonDeg =
              ((_centreLonDeg - d.focalPointDelta.dx * k) + 540) %
                      360 -
                  180;
          _centreLatDeg = (_centreLatDeg + d.focalPointDelta.dy * k)
              .clamp(-89.0, 89.0);
        });
      },
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: LayoutBuilder(builder:
                (BuildContext _, BoxConstraints constraints) {
              // Cache the size so the tap hit-test in
              // GestureDetector has the same coords the painter
              // used. Done post-frame so we don't setState during
              // a build.
              final Size sz =
                  Size(constraints.maxWidth, constraints.maxHeight);
              if (_lastPaintSize != sz) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _lastPaintSize = sz;
                });
              }
              return CustomPaint(
              painter: _GlobePainter(
                centreLonDeg: _centreLonDeg,
                centreLatDeg: _centreLatDeg,
                scale: _scale,
                ocean: cs.surfaceContainerHighest,
                land: cs.surfaceContainer,
                landStroke: cs.outline.withValues(alpha: .55),
                grid: cs.outline.withValues(alpha: .35),
                selfPin: cs.primary,
                peerRecent: cs.tertiary,
                peerStale: cs.onSurfaceVariant,
                arc: cs.primary.withValues(alpha: .55),
                regionFill: cs.tertiary.withValues(alpha: .20),
                regionStroke: cs.tertiary,
                regionLabel: cs.onSurface,
                labelText: cs.onSurfaceVariant,
                frame: cs.outline,
                rings: _land ?? const <List<List<double>>>[],
                selfLat: selfLat,
                selfLon: selfLon,
                peers: withLoc,
                showArcs: _showArcs,
                showRegions: _showRegions,
                showLabels: _showLabels,
              ),
            );
            }),
          ),
          // Overlay toggle strip — top-right, three small chips.
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: cs.outline.withValues(alpha: .5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _OverlayChip(
                    icon: Icons.timeline,
                    label: l.globeOverlayArcs,
                    on: _showArcs,
                    onTap: () =>
                        setState(() => _showArcs = !_showArcs),
                  ),
                  const SizedBox(width: 4),
                  _OverlayChip(
                    icon: Icons.scatter_plot,
                    label: l.globeOverlayRegion,
                    on: _showRegions,
                    onTap: () => setState(
                        () => _showRegions = !_showRegions),
                  ),
                  const SizedBox(width: 4),
                  _OverlayChip(
                    icon: Icons.label_outline,
                    label: l.globeOverlayLabels,
                    on: _showLabels,
                    onTap: () => setState(
                        () => _showLabels = !_showLabels),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: cs.outline.withValues(alpha: .4)),
              ),
              child: Text(
                l.globeFooter(withLoc.length),
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                    letterSpacing: 1),
              ),
            ),
          ),
          // R40 — altitude slider. Log-mapped so the range from
          // hemisphere (~7600 mi) down to 100 ft fits a single
          // 0..1 slider track without the entire useful range
          // collapsing into the last 1% (it would on a linear
          // slider given the 400 000× zoom factor).
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: cs.outline.withValues(alpha: .4)),
              ),
              child: Row(
                children: <Widget>[
                  Text(l.globeAltitude,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10,
                          letterSpacing: 1.2)),
                  Expanded(
                    child: Slider(
                      min: 0.0,
                      max: 1.0,
                      // Slider is reversed in meaning: 0.0 = max
                      // altitude (zoomed out), 1.0 = min altitude
                      // (zoomed in). Reads more naturally on screen.
                      value: _scaleToSliderPos(_scale),
                      onChanged: (double v) => setState(
                          () => _scale = _sliderPosToScale(v)),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      _formatAltitude(_altMiFromScale(_scale)),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontFamily: 'monospace',
                          fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // R40 — PAUSED indicator when the grid handed us a frozen
          // snapshot; otherwise hidden.
          if (widget.frozen)
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer.withValues(alpha: .85),
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
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: on
                  ? cs.primary
                  : cs.outline.withValues(alpha: .35),
              width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12,
                color: on ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: on ? cs.primary : cs.onSurfaceVariant,
                    fontSize: 10,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.centreLonDeg,
    required this.centreLatDeg,
    required this.scale,
    required this.ocean,
    required this.land,
    required this.landStroke,
    required this.grid,
    required this.selfPin,
    required this.peerRecent,
    required this.peerStale,
    required this.arc,
    required this.regionFill,
    required this.regionStroke,
    required this.regionLabel,
    required this.labelText,
    required this.frame,
    required this.rings,
    required this.selfLat,
    required this.selfLon,
    required this.peers,
    required this.showArcs,
    required this.showRegions,
    required this.showLabels,
  });

  /// Longitude (°E) currently centred in the projection.
  final double centreLonDeg;

  /// Latitude (°N) currently centred in the projection.
  final double centreLatDeg;

  /// Zoom factor — multiplies the projection radius. 1.0 = base.
  final double scale;
  final Color ocean;
  final Color land;
  final Color landStroke;
  final Color grid;
  final Color selfPin;
  final Color peerRecent;
  final Color peerStale;
  final Color arc;
  final Color regionFill;
  final Color regionStroke;
  final Color regionLabel;
  final Color labelText;
  final Color frame;
  final List<List<List<double>>> rings;
  final double? selfLat;
  final double? selfLon;
  final List<DiscoveredNode> peers;
  final bool showArcs;
  final bool showRegions;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double r =
        math.min(size.width, size.height) * 0.45 * scale;
    // Convert centre to radians once; pass to every project call.
    final double rotLon = centreLonDeg * math.pi / 180;
    final double rotLat = centreLatDeg * math.pi / 180;

    // Ocean disk.
    canvas.drawCircle(centre, r, Paint()..color = ocean);

    // Frame.
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = frame,
    );

    // Graticule.
    final Paint gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = grid;
    for (int latDeg = -60; latDeg <= 60; latDeg += 30) {
      _drawParallel(canvas, centre, r, rotLon, rotLat,
          latDeg.toDouble(), gridPaint);
    }
    for (int lonDeg = 0; lonDeg < 360; lonDeg += 30) {
      _drawMeridian(canvas, centre, r, rotLon, rotLat,
          lonDeg.toDouble(), gridPaint);
    }

    // Land — fill + thin stroke.
    final Paint landFill = Paint()..color = land;
    final Paint landStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = landStroke;
    for (final List<List<double>> ring in rings) {
      // GeoJSON pairs are [lon, lat].
      _drawPolygon(canvas, centre, r, rotLon, rotLat, ring, landFill,
          stroke: landStrokePaint);
    }

    // Arcs from self → each peer (great-circle).
    if (showArcs && selfLat != null && selfLon != null) {
      final Paint arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = arc;
      for (final DiscoveredNode n in peers) {
        _drawGreatCircle(
            canvas,
            centre,
            r,
            rotLon,
            rotLat,
            selfLat!,
            selfLon!,
            n.latitude!,
            n.longitude!,
            arcPaint);
      }
    }

    // Region clusters OR per-node pins.
    if (showRegions) {
      _drawRegionClusters(canvas, centre, r, rotLon, rotLat);
    } else {
      _drawPeerPins(canvas, centre, r, rotLon, rotLat);
    }

    // Self pin (crosshair + dot). Drawn after peers so it's on
    // top in the overlap case.
    if (selfLat != null && selfLon != null) {
      final ({Offset offset, double rotY}) pp = _project(
          centre, r, rotLon, rotLat, selfLat!, selfLon!);
      if (pp.rotY >= 0) {
        final Offset p = pp.offset;
        final Paint x = Paint()
          ..color = selfPin
          ..strokeWidth = 1.6;
        canvas.drawLine(p.translate(-10, 0), p.translate(10, 0), x);
        canvas.drawLine(p.translate(0, -10), p.translate(0, 10), x);
        canvas.drawCircle(p, 5, Paint()..color = selfPin);
      }
    }
  }

  void _drawPeerPins(Canvas canvas, Offset centre, double r,
      double rotLon, double rotLat) {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final DiscoveredNode n in peers) {
      final ({Offset offset, double rotY}) pp = _project(
          centre, r, rotLon, rotLat, n.latitude!, n.longitude!);
      if (pp.rotY < 0) continue;
      final Offset p = pp.offset;
      final int dtHours = ((now - n.lastHeardUnix) / 3600).round();
      final double t = (1 - dtHours / 6).clamp(0.0, 1.0);
      final Color c = Color.lerp(peerStale, peerRecent, t) ?? peerRecent;
      _drawPeerShape(canvas, p, n.type, c, ocean);
      if (showLabels && n.name.isNotEmpty) {
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: n.name,
            style: TextStyle(
                color: labelText,
                fontSize: 10,
                fontFamily: 'monospace'),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p.translate(8, -tp.height / 2));
      }
    }
  }

  void _drawRegionClusters(Canvas canvas, Offset centre, double r,
      double rotLon, double rotLat) {
    final Map<String, _RegionAcc> buckets = <String, _RegionAcc>{};
    for (final DiscoveredNode n in peers) {
      final int lb = (n.latitude! / 10).floor() * 10;
      final int wb = (n.longitude! / 10).floor() * 10;
      final String key = '$lb,$wb';
      final _RegionAcc acc = buckets.putIfAbsent(
          key, () => _RegionAcc(0, 0, 0));
      acc.count++;
      acc.latSum += n.latitude!;
      acc.lonSum += n.longitude!;
    }
    for (final _RegionAcc acc in buckets.values) {
      final double lat = acc.latSum / acc.count;
      final double lon = acc.lonSum / acc.count;
      final ({Offset offset, double rotY}) pp =
          _project(centre, r, rotLon, rotLat, lat, lon);
      if (pp.rotY < 0) continue;
      final Offset p = pp.offset;
      final double radius = 8 + acc.count * 2.0;
      canvas.drawCircle(p, radius, Paint()..color = regionFill);
      canvas.drawCircle(
          p,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = regionStroke);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${acc.count}',
          style: TextStyle(
              color: regionLabel,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// Great-circle line between two lat/lon points, segmented and
  /// projected; segments are skipped where either end falls on the
  /// far side of the sphere. Matches the d3 mockup convention used
  /// by the rest of the painter — see `_project` for the math.
  void _drawGreatCircle(Canvas canvas, Offset centre, double r,
      double rotLon, double rotLat, double lat1, double lon1,
      double lat2, double lon2, Paint paint) {
    const int N = 48;
    Offset? prev;
    for (int i = 0; i <= N; i++) {
      final double t = i / N;
      // Slerp on the unit sphere is equivalent to interpolating
      // lat/lon directly along the great-circle when the two points
      // aren't near-antipodal — for our usage (peers within a few
      // thousand km) a simple lerp in (sinLat, lon) and re-projecting
      // is visually indistinguishable and a lot cheaper.
      final double sinL = math.sin(lat1 * math.pi / 180) * (1 - t) +
          math.sin(lat2 * math.pi / 180) * t;
      final double lonI = lon1 * (1 - t) + lon2 * t;
      final double latI =
          math.asin(sinL.clamp(-1.0, 1.0)) * 180 / math.pi;
      final ({Offset offset, double rotY}) pp =
          _project(centre, r, rotLon, rotLat, latI, lonI);
      final Offset? proj = pp.rotY < 0 ? null : pp.offset;
      if (proj != null && prev != null) {
        canvas.drawLine(prev, proj, paint);
      }
      prev = proj;
    }
  }

  /// Orthographic projection of (latDeg, lonDeg) on a unit sphere
  /// rotated so that (centreLat, centreLon) sits at the centre of
  /// the projection. See class docstring for full convention.
  ///
  /// Returns both the screen Offset AND the rotated-y component
  /// (i.e. depth toward the camera). Callers can:
  ///   - Treat `rotY < 0` as "back-face, skip drawing this point";
  ///   - Use both points' `rotY` values to interpolate the
  ///     **horizon-crossing** point on the great-circle when a
  ///     polygon edge transitions from visible to invisible.
  ({Offset offset, double rotY}) _project(Offset centre, double r,
      double rotLon, double rotLat, double latDeg, double lonDeg) {
    final double lonShift =
        (lonDeg * math.pi / 180) - rotLon;
    final double lat = latDeg * math.pi / 180;
    final double cl = math.cos(lat);
    final double x = cl * math.sin(lonShift);
    final double y = cl * math.cos(lonShift);
    final double z = math.sin(lat);
    final double c = math.cos(rotLat);
    final double s = math.sin(rotLat);
    final double yr = y * c + z * s;
    final double zr = -y * s + z * c;
    return (
      offset: Offset(centre.dx + x * r, centre.dy - zr * r),
      rotY: yr,
    );
  }

  void _drawParallel(Canvas canvas, Offset centre, double r,
      double rotLon, double rotLat, double latDeg, Paint paint) {
    Offset? prev;
    for (int i = 0; i <= 72; i++) {
      final double lon = (i * 5).toDouble();
      final ({Offset offset, double rotY}) pp =
          _project(centre, r, rotLon, rotLat, latDeg, lon);
      final Offset? p = pp.rotY < 0 ? null : pp.offset;
      if (p != null && prev != null) {
        canvas.drawLine(prev, p, paint);
      }
      prev = p;
    }
  }

  void _drawMeridian(Canvas canvas, Offset centre, double r,
      double rotLon, double rotLat, double lonDeg, Paint paint) {
    Offset? prev;
    for (int i = 0; i <= 36; i++) {
      final double lat = (i * 5).toDouble() - 90;
      final ({Offset offset, double rotY}) pp =
          _project(centre, r, rotLon, rotLat, lat, lonDeg);
      final Offset? p = pp.rotY < 0 ? null : pp.offset;
      if (p != null && prev != null) {
        canvas.drawLine(prev, p, paint);
      }
      prev = p;
    }
  }

  /// `ring` is GeoJSON `[lon, lat]` pairs (note the order).
  /// Project a polygon ring onto the visible hemisphere. When an
  /// edge **crosses the horizon** (one endpoint visible, the other
  /// back-facing), we linearly interpolate the screen offset at
  /// the crossing point so the path follows the limb of the sphere
  /// cleanly instead of closing with a straight chord — which is
  /// what produced the triangle artifacts reported in the field.
  ///
  /// The interpolation is in screen space (LERP of the two
  /// projected offsets weighted by `rotY`), not on the great-circle,
  /// because we render each edge as a straight segment between
  /// consecutive ring vertices anyway. The result hugs the sphere
  /// edge closely enough at typical zoom levels that the chunky-
  /// chord artifact disappears.
  void _drawPolygon(Canvas canvas, Offset centre, double r,
      double rotLon, double rotLat, List<List<double>> ring,
      Paint fill, {Paint? stroke}) {
    if (ring.isEmpty) return;
    final Path path = Path();
    // Project every vertex once up-front so we can look at adjacent
    // pairs for horizon crossings without re-projecting.
    final List<({Offset offset, double rotY})> proj =
        <({Offset offset, double rotY})>[
      for (final List<double> pt in ring)
        _project(centre, r, rotLon, rotLat, pt[1], pt[0]),
    ];
    bool started = false;
    for (int i = 0; i < proj.length; i++) {
      final ({Offset offset, double rotY}) cur = proj[i];
      final bool curVisible = cur.rotY >= 0;
      if (curVisible) {
        if (!started) {
          // Was on the back face on previous step; check the
          // previous vertex (treating wrap-around) for a crossing
          // into us, so the path enters along the limb.
          final ({Offset offset, double rotY}) prev =
              proj[(i - 1 + proj.length) % proj.length];
          if (prev.rotY < 0) {
            final Offset entry = _lerpHorizon(prev, cur);
            path.moveTo(entry.dx, entry.dy);
            path.lineTo(cur.offset.dx, cur.offset.dy);
          } else {
            path.moveTo(cur.offset.dx, cur.offset.dy);
          }
          started = true;
        } else {
          path.lineTo(cur.offset.dx, cur.offset.dy);
        }
      } else if (started) {
        // Transition visible → invisible. Draw to the horizon
        // crossing of the **incoming** edge, then close so the
        // chord runs along the limb.
        final ({Offset offset, double rotY}) prev = proj[i - 1];
        if (prev.rotY >= 0) {
          final Offset exit = _lerpHorizon(prev, cur);
          path.lineTo(exit.dx, exit.dy);
        }
        path.close();
        started = false;
      }
    }
    if (started) path.close();
    canvas.drawPath(path, fill);
    if (stroke != null) canvas.drawPath(path, stroke);
  }

  /// Linear interpolation between two projected points along the
  /// `rotY = 0` crossing. Both endpoints have known `rotY` (one
  /// positive, one negative) so the crossing parameter is
  /// `t = rotY_a / (rotY_a - rotY_b)`.
  Offset _lerpHorizon(({Offset offset, double rotY}) a,
      ({Offset offset, double rotY}) b) {
    final double denom = a.rotY - b.rotY;
    if (denom.abs() < 1e-9) return a.offset;
    final double t = a.rotY / denom;
    return Offset(
      a.offset.dx + (b.offset.dx - a.offset.dx) * t,
      a.offset.dy + (b.offset.dy - a.offset.dy) * t,
    );
  }

  /// Per-node-type shape glyph. type 1 = chat/companion (circle),
  /// type 2 = repeater/router (triangle), type 3 = room (square),
  /// type 4 = sensor (diamond), other = circle.
  void _drawPeerShape(Canvas canvas, Offset p, int type,
      Color fill, Color outline) {
    final Paint fillPaint = Paint()..color = fill;
    final Paint outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outline;
    const double s = 5;
    switch (type) {
      case 2: // Router — triangle pointing up.
        final Path tri = Path()
          ..moveTo(p.dx, p.dy - s)
          ..lineTo(p.dx + s, p.dy + s * 0.85)
          ..lineTo(p.dx - s, p.dy + s * 0.85)
          ..close();
        canvas.drawPath(tri, fillPaint);
        canvas.drawPath(tri, outlinePaint);
      case 3: // Room — square.
        final Rect sq = Rect.fromCenter(
            center: p, width: s * 1.8, height: s * 1.8);
        canvas.drawRect(sq, fillPaint);
        canvas.drawRect(sq, outlinePaint);
      case 4: // Sensor — diamond.
        final Path dia = Path()
          ..moveTo(p.dx, p.dy - s)
          ..lineTo(p.dx + s, p.dy)
          ..lineTo(p.dx, p.dy + s)
          ..lineTo(p.dx - s, p.dy)
          ..close();
        canvas.drawPath(dia, fillPaint);
        canvas.drawPath(dia, outlinePaint);
      default: // 1 (Chat / companion) or unknown — circle.
        canvas.drawCircle(p, 4, fillPaint);
        canvas.drawCircle(p, 4, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) =>
      old.centreLonDeg != centreLonDeg ||
      old.centreLatDeg != centreLatDeg ||
      old.scale != scale ||
      old.selfLat != selfLat ||
      old.selfLon != selfLon ||
      old.peers.length != peers.length ||
      old.rings.length != rings.length ||
      old.showArcs != showArcs ||
      old.showRegions != showRegions ||
      old.showLabels != showLabels;
}

class _RegionAcc {
  _RegionAcc(this.count, this.latSum, this.lonSum);
  int count;
  double latSum;
  double lonSum;
}
