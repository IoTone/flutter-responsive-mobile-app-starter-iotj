// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:meshcore/meshcore.dart' show SelfInfo;
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';
import '../util/lora_range.dart';
import 'node_detail_sheet.dart';

/// R25+2 — fourth view in the hyperlocal-grid sub-mode swipe stack.
///
/// Unlike the equal-grid view (cells in screen space), this view is
/// a **standard interactive street map**: full-colour OSM tiles,
/// native pan + pinch zoom on the map itself, and peer / self / trail
/// rendered via flutter_map's own layer primitives (Marker, Polyline,
/// CircleMarker) rather than a CustomPaint overlay.
///
/// Reuses the same data (filtered nodes + frozen state piped from the
/// radial grid) and the same R25+1 polish — distinctive self pin,
/// heading arrow, ownTrail polyline, estimated LoRa range rings.
/// What's different vs the equal-grid is *what* the user sees
/// underneath: an actual street map you can pan and zoom through,
/// not a tinted basemap clipped to a 5×5 cell viewport.
class StreetMapView extends StatefulWidget {
  const StreetMapView({
    super.key,
    this.filteredNodes,
    this.frozen = false,
  });

  final List<DiscoveredNode>? filteredNodes;
  final bool frozen;

  @override
  State<StreetMapView> createState() => _StreetMapViewState();
}

class _StreetMapViewState extends State<StreetMapView> {
  /// Discrete zoom levels. Pinch on the map also works; these
  /// buttons are an explicit affordance for users on devices
  /// without multi-touch or who prefer one-handed operation.
  static const double _zoomMin = 6.0;
  static const double _zoomMax = 18.5;
  static const double _zoomStep = 1.0;
  late final MapController _map = MapController();
  double _zoom = 14.0; // metro default; pinned to self on first build
  bool _centered = false;

  double? _headingDeg;
  StreamSubscription<CompassEvent>? _compassSub;

  /// R25+3 — tile source toggle. `standard` is the colorful OSM
  /// raster everyone recognises; `topo` is OpenTopoMap with contour
  /// lines, shaded relief and trail/POI overlays — useful when the
  /// street layer adds noise (off-grid use, hiking).
  _TileSource _tileSource = _TileSource.standard;

  /// R25+5 — show / hide the basemap tiles entirely. Default on;
  /// flipping off renders peers, trail, and range circles on a
  /// plain themed background, which can read better against accent
  /// colours on dark themes where street colours clash.
  bool _showTiles = true;

  @override
  void initState() {
    super.initState();
    _compassSub = FlutterCompass.events?.listen((CompassEvent e) {
      final double? h = e.heading;
      if (h == null || !mounted) return;
      if (_headingDeg != null && (h - _headingDeg!).abs() < 1.0) return;
      setState(() => _headingDeg = h);
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  void _zoomIn() {
    final double next = (_zoom + _zoomStep).clamp(_zoomMin, _zoomMax);
    if (next == _zoom) return;
    setState(() => _zoom = next);
    _map.move(_map.camera.center, _zoom);
  }

  void _zoomOut() {
    final double next = (_zoom - _zoomStep).clamp(_zoomMin, _zoomMax);
    if (next == _zoom) return;
    setState(() => _zoom = next);
    _map.move(_map.camera.center, _zoom);
  }

  void _recenterOnSelf(double lat, double lon) {
    _map.move(LatLng(lat, lon), _zoom);
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
    // First build after the controller has a location: centre on self.
    if (!_centered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _map.move(LatLng(selfLat, selfLon), _zoom);
        } catch (_) {/* map not laid out yet */}
        _centered = true;
      });
    }

    final List<DiscoveredNode> source =
        widget.filteredNodes ?? mc.nodes;
    final List<DiscoveredNode> withLoc = <DiscoveredNode>[
      for (final DiscoveredNode n in source)
        if (n.hasLocation) n
    ];

    final SelfInfo? si = mc.selfInfo;
    final double rangeM = si == null
        ? 1500.0
        : estimatedLoraRangeMeters(
            spreadingFactor: si.spreadingFactor,
            bandwidthKhz: si.bandwidthKhz,
            txPowerDbm: si.txPowerDbm,
          );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: LatLng(selfLat, selfLon),
              initialZoom: _zoom,
              minZoom: _zoomMin,
              maxZoom: _zoomMax,
              interactionOptions: const InteractionOptions(
                // Pan + pinch + scroll-wheel zoom; no rotation
                // (heading still works via the self-marker arrow).
                flags: InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.scrollWheelZoom |
                    InteractiveFlag.doubleTapZoom,
              ),
              backgroundColor: cs.surfaceContainerHighest,
            ),
            children: <Widget>[
              if (_showTiles)
                TileLayer(
                  // R25+3 — swappable basemap. Topo subdomain set
                  // (a/b/c) is required by OpenTopoMap's policy to
                  // spread load; standard OSM doesn't use one.
                  urlTemplate: _tileSource.urlTemplate,
                  subdomains: _tileSource.subdomains,
                  maxNativeZoom: _tileSource.maxNativeZoom,
                  userAgentPackageName:
                      'com.iotone.meshmore_sns_app',
                ),
              // R25+1 — range circle for self + each peer. Drawn
              // before markers so the marker icons sit on top.
              CircleLayer(
                circles: <CircleMarker>[
                  CircleMarker(
                    point: LatLng(selfLat, selfLon),
                    radius: rangeM,
                    useRadiusInMeter: true,
                    color: cs.tertiary.withValues(alpha: .12),
                    borderColor: cs.tertiary.withValues(alpha: .55),
                    borderStrokeWidth: 1.0,
                  ),
                  for (final DiscoveredNode n in withLoc)
                    CircleMarker(
                      point: LatLng(n.latitude!, n.longitude!),
                      radius: rangeM,
                      useRadiusInMeter: true,
                      color: cs.tertiary.withValues(alpha: .06),
                      borderColor: cs.tertiary.withValues(alpha: .35),
                      borderStrokeWidth: 1.0,
                    ),
                ],
              ),
              // R25+1 — own-movement trail, oldest faded → newest
              // solid. Drawn as a single Polyline; per-segment alpha
              // would need multiple polylines so we go with a
              // single mid-alpha line for now.
              if (mc.ownTrail.length >= 2)
                PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: <LatLng>[
                        for (final ({
                          double latitude,
                          double longitude,
                          int unixSec
                        }) p in mc.ownTrail)
                          LatLng(p.latitude, p.longitude),
                      ],
                      strokeWidth: 3.0,
                      color: cs.secondary.withValues(alpha: .65),
                    ),
                  ],
                ),
              // Peer markers.
              MarkerLayer(
                markers: <Marker>[
                  for (final DiscoveredNode n in withLoc)
                    Marker(
                      point: LatLng(n.latitude!, n.longitude!),
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => _showDetail(context, mc, n),
                        child: _PeerGlyph(
                          node: n,
                          companion: cs.tertiary,
                          repeater: cs.primary,
                          known: mc.known.contains(n.pubKeyHex),
                          favourite: mc.favorites.contains(n.pubKeyHex),
                        ),
                      ),
                    ),
                  // Self marker last so it sits on top.
                  Marker(
                    point: LatLng(selfLat, selfLon),
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    child: _SelfGlyph(
                      colour: cs.primary,
                      headingDeg: _headingDeg,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.frozen)
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        // Zoom +/- + re-centre. Stacked vertically, top-right.
        Positioned(
          right: 12,
          top: 12,
          child: Material(
            color: cs.surface.withValues(alpha: .9),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                  color: cs.outline.withValues(alpha: .4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: l.equalGridZoomIn,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.add),
                  onPressed: _zoom < _zoomMax ? _zoomIn : null,
                ),
                IconButton(
                  tooltip: l.equalGridZoomOut,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.remove),
                  onPressed: _zoom > _zoomMin ? _zoomOut : null,
                ),
                IconButton(
                  tooltip: l.streetMapRecenter,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.my_location),
                  onPressed: () =>
                      _recenterOnSelf(selfLat, selfLon),
                ),
                // R25+3 — basemap toggle: street ↔ topo.
                IconButton(
                  tooltip: _tileSource == _TileSource.standard
                      ? l.streetMapTopoLayer
                      : l.streetMapStandardLayer,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                  icon: Icon(_tileSource == _TileSource.standard
                      ? Icons.terrain
                      : Icons.map),
                  onPressed: () => setState(() {
                    _tileSource =
                        _tileSource == _TileSource.standard
                            ? _TileSource.topo
                            : _TileSource.standard;
                  }),
                ),
                // R25+5 — hide the basemap entirely. Useful when
                // street colours clash with the theme accent or
                // when the user just wants to focus on the pin
                // pattern without distraction.
                IconButton(
                  tooltip: _showTiles
                      ? l.mapHideTiles
                      : l.mapShowTiles,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                  icon: Icon(_showTiles
                      ? Icons.layers
                      : Icons.layers_clear),
                  onPressed: () =>
                      setState(() => _showTiles = !_showTiles),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// R25+3 — basemap tile-set picker. Layered behind the markers /
/// trail / range circles. Standard is recognisable street view;
/// topo is contour + shaded relief from OpenTopoMap (CC-BY-SA;
/// attribution belongs in the About screen).
enum _TileSource {
  standard(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: <String>[],
    maxNativeZoom: 19,
  ),
  topo(
    urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    subdomains: <String>['a', 'b', 'c'],
    maxNativeZoom: 17,
  );

  const _TileSource({
    required this.urlTemplate,
    required this.subdomains,
    required this.maxNativeZoom,
  });

  final String urlTemplate;
  final List<String> subdomains;
  final int maxNativeZoom;
}

class _PeerGlyph extends StatelessWidget {
  const _PeerGlyph({
    required this.node,
    required this.companion,
    required this.repeater,
    required this.known,
    required this.favourite,
  });
  final DiscoveredNode node;
  final Color companion;
  final Color repeater;
  final bool known;
  final bool favourite;

  @override
  Widget build(BuildContext context) {
    final bool isRepeater = node.type == 2;
    final Color base = isRepeater ? repeater : companion;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        if (isRepeater)
          // Triangle.
          CustomPaint(
            size: const Size(16, 16),
            painter: _TrianglePainter(color: base),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: base,
              border: Border.all(color: Colors.white, width: 1.0),
            ),
          ),
        if (favourite)
          Positioned(
            top: 0,
            right: 0,
            child: Icon(Icons.star, size: 10, color: repeater),
          )
        else if (known)
          Positioned(
            top: 0,
            right: 0,
            child: Icon(Icons.circle, size: 8, color: companion),
          ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = color;
    final Paint stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final Path p = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p, fill);
    canvas.drawPath(p, stroke);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) =>
      color != old.color;
}

class _SelfGlyph extends StatelessWidget {
  const _SelfGlyph({required this.colour, required this.headingDeg});
  final Color colour;
  final double? headingDeg;

  @override
  Widget build(BuildContext context) {
    final double rot =
        headingDeg == null ? 0.0 : headingDeg! * 3.141592653589793 / 180.0;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // Three-ring bullseye.
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colour.withValues(alpha: .18),
          ),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colour.withValues(alpha: .35),
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colour,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
        if (headingDeg != null)
          Transform.rotate(
            angle: rot,
            child: CustomPaint(
              size: const Size(40, 40),
              painter: _HeadingWedgePainter(color: colour),
            ),
          ),
      ],
    );
  }
}

class _HeadingWedgePainter extends CustomPainter {
  _HeadingWedgePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = color;
    final double cx = size.width / 2;
    final Path p = Path()
      ..moveTo(cx, 2) // tip toward "up" at 0° heading
      ..lineTo(cx - 5, 12)
      ..lineTo(cx + 5, 12)
      ..close();
    canvas.drawPath(p, fill);
  }

  @override
  bool shouldRepaint(covariant _HeadingWedgePainter old) =>
      color != old.color;
}
