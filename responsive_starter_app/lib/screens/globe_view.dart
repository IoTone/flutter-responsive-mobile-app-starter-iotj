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
  const GlobeView({super.key});

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

  /// Pinch-zoom scale. 1.0 = base (sphere fills the canvas as
  /// before); higher = closer view. Clamped at min/max so the
  /// sphere can't shrink invisible or blow past the bezel.
  double _scale = 1.0;
  static const double _scaleMin = 1.0;
  static const double _scaleMax = 6.0;
  double _scaleAtGestureStart = 1.0;

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

  void _ensureCenteredOn(double? lat, double? lon) {
    if (_centeredOnSelf) return;
    if (lat == null || lon == null) return;
    _centreLonDeg = lon;
    _centreLatDeg = lat;
    _centeredOnSelf = true;
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

    final List<DiscoveredNode> withLoc = <DiscoveredNode>[
      for (final DiscoveredNode n in mc.nodes)
        if (n.hasLocation) n
    ];

    return GestureDetector(
      onScaleStart: (_) => _scaleAtGestureStart = _scale,
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
            child: CustomPaint(
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
            ),
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
          // Zoom slider — bottom-right. Mirrors the pinch gesture
          // so users without two-finger touch (or who just prefer
          // a discrete control) can still scale the view.
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              width: 180,
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
                  Text(l.globeZoom,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10,
                          letterSpacing: 1.2)),
                  Expanded(
                    child: Slider(
                      min: _scaleMin,
                      max: _scaleMax,
                      value: _scale,
                      onChanged: (double v) =>
                          setState(() => _scale = v),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${_scale.toStringAsFixed(1)}×',
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
      final Offset? p = _project(
          centre, r, rotLon, rotLat, selfLat!, selfLon!);
      if (p != null) {
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
      final Offset? p = _project(
          centre, r, rotLon, rotLat, n.latitude!, n.longitude!);
      if (p == null) continue;
      final int dtHours = ((now - n.lastHeardUnix) / 3600).round();
      final double t = (1 - dtHours / 6).clamp(0.0, 1.0);
      final Color c = Color.lerp(peerStale, peerRecent, t) ?? peerRecent;
      canvas.drawCircle(p, 4, Paint()..color = c);
      canvas.drawCircle(
          p,
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = ocean);
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
      final Offset? p = _project(centre, r, rotLon, rotLat, lat, lon);
      if (p == null) continue;
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
      final Offset? proj =
          _project(centre, r, rotLon, rotLat, latI, lonI);
      if (proj != null && prev != null) {
        canvas.drawLine(prev, proj, paint);
      }
      prev = proj;
    }
  }

  /// Orthographic projection of (latDeg, lonDeg) on a unit sphere
  /// rotated so that (centreLat, centreLon) sits at the centre of
  /// the projection. Matches the d3 mockup convention:
  ///   1. Shift longitude by `-centreLon` (centre that longitude).
  ///   2. Cartesian: x = cos(lat)*sin(lonShift), y = cos(lat)*cos(lonShift), z = sin(lat).
  ///   3. Rotate around the screen-x axis by `centreLat` so that
  ///      latitude ends up at z=0 in the rotated frame.
  ///   4. Return null when rotated_y < 0 (back face).
  ///   5. Screen: x → centre.dx + x*r; rotated_z → centre.dy - z*r
  ///      (screen-y grows downward, world-z grows upward).
  Offset? _project(Offset centre, double r, double rotLon,
      double rotLat, double latDeg, double lonDeg) {
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
    if (yr < 0) return null;
    return Offset(centre.dx + x * r, centre.dy - zr * r);
  }

  void _drawParallel(Canvas canvas, Offset centre, double r,
      double rotLon, double rotLat, double latDeg, Paint paint) {
    Offset? prev;
    for (int i = 0; i <= 72; i++) {
      final double lon = (i * 5).toDouble();
      final Offset? p =
          _project(centre, r, rotLon, rotLat, latDeg, lon);
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
      final Offset? p =
          _project(centre, r, rotLon, rotLat, lat, lonDeg);
      if (p != null && prev != null) {
        canvas.drawLine(prev, p, paint);
      }
      prev = p;
    }
  }

  /// `ring` is GeoJSON `[lon, lat]` pairs (note the order).
  void _drawPolygon(Canvas canvas, Offset centre, double r,
      double rotLon, double rotLat, List<List<double>> ring,
      Paint fill, {Paint? stroke}) {
    final Path path = Path();
    bool started = false;
    for (final List<double> pt in ring) {
      final Offset? p =
          _project(centre, r, rotLon, rotLat, pt[1], pt[0]);
      if (p == null) {
        if (started) {
          path.close();
          started = false;
        }
        continue;
      }
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (started) path.close();
    canvas.drawPath(path, fill);
    if (stroke != null) canvas.drawPath(path, stroke);
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
