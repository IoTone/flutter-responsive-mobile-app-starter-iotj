// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/coverage_store.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';
import 'node_detail_sheet.dart';

/// F8 — Fabric survey view. Paints **mesh coverage** as a quilt of
/// shaded cells over an OSM basemap. Distinct from the equal-grid
/// (where peers are *now*) and from the street-map (peers + trail
/// at one moment): this is **multi-session aggregation** — every
/// cell where we've ever observed mesh activity is shaded, brighter
/// for recent, faded for older. Holes are the gaps where the mesh
/// hasn't reached yet.
///
/// Data lives in the controller's [MeshcoreController.coverageCells]
/// map (persisted via [CoverageStore]). The user can clear it via
/// the overflow menu when they want a clean survey from a fresh
/// location.
class FabricSurveyView extends StatefulWidget {
  const FabricSurveyView({
    super.key,
    this.filteredNodes,
    this.frozen = false,
  });

  final List<DiscoveredNode>? filteredNodes;
  final bool frozen;

  @override
  State<FabricSurveyView> createState() => _FabricSurveyViewState();
}

class _FabricSurveyViewState extends State<FabricSurveyView> {
  static const double _zoomMin = 8.0;
  static const double _zoomMax = 16.0;
  static const double _zoomStep = 1.0;
  late final MapController _map = MapController();
  double _zoom = 12.0; // metro-area default; quilt reads best here
  bool _centered = false;
  bool _showTiles = true;

  Future<void> _confirmReset(MeshcoreController mc) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l.fabricResetTitle),
        content: Text(l.fabricResetBody),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.fabricResetApply)),
        ],
      ),
    );
    if (ok == true) await mc.resetCoverage();
  }

  Future<void> _showDetail(MeshcoreController mc, DiscoveredNode n) {
    return showModalBottomSheet<void>(
      context: context,
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
    if (!_centered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _map.move(LatLng(selfLat, selfLon), _zoom);
        } catch (_) {/* not laid out */}
        _centered = true;
      });
    }

    // Build the coverage polygon set. One CircleMarker per cell —
    // sized so adjacent cells touch (radius = half the cell
    // diagonal × cos(lat) for square-ish look at this latitude).
    final int nowSec =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final List<Polygon> cells = <Polygon>[];
    mc.coverageCells.forEach((String key, int unixSec) {
      final ({int latBucket, int lonBucket})? b =
          CoverageStore.parseKey(key);
      if (b == null) return;
      final double latOrigin = b.latBucket * CoverageStore.cellDeg;
      final double lonOrigin = b.lonBucket * CoverageStore.cellDeg;
      // Recency ramp: <1 h ago = full alpha 65%; >7 d ago = 12%.
      final int ageSec = nowSec - unixSec;
      double recency;
      if (ageSec < 3600) {
        recency = 1.0;
      } else if (ageSec < 86400) {
        recency = 0.75;
      } else if (ageSec < 604800) {
        recency = 0.45;
      } else {
        recency = 0.2;
      }
      cells.add(Polygon(
        points: <LatLng>[
          LatLng(latOrigin, lonOrigin),
          LatLng(latOrigin + CoverageStore.cellDeg, lonOrigin),
          LatLng(latOrigin + CoverageStore.cellDeg,
              lonOrigin + CoverageStore.cellDeg),
          LatLng(latOrigin, lonOrigin + CoverageStore.cellDeg),
        ],
        color: cs.primary.withValues(alpha: 0.18 + 0.42 * recency),
        borderColor: cs.primary.withValues(alpha: 0.30 * recency),
        borderStrokeWidth: 0.5,
      ));
    });

    final List<DiscoveredNode> source =
        widget.filteredNodes ?? mc.nodes;
    final List<DiscoveredNode> withLoc = <DiscoveredNode>[
      for (final DiscoveredNode n in source)
        if (n.hasLocation) n
    ];

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
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.iotone.meshmore_sns_app',
                ),
              // Theme-tinted overlay so cells stay readable on busy
              // street tiles.
              if (cells.isNotEmpty)
                PolygonLayer(polygons: cells),
              // Tiny pins for peers in the current set so the user
              // can correlate covered cells with the nodes that
              // contributed.
              MarkerLayer(
                markers: <Marker>[
                  for (final DiscoveredNode n in withLoc)
                    Marker(
                      point: LatLng(n.latitude!, n.longitude!),
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => _showDetail(mc, n),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.tertiary,
                            border: Border.all(
                                color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  Marker(
                    point: LatLng(selfLat, selfLon),
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary,
                        border: Border.all(
                            color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Top-left stat strip — coverage cell count + age cue.
        Positioned(
          left: 12,
          top: 12,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: cs.primary.withValues(alpha: .5)),
              ),
              child: Text(
                l.fabricCoverageCount(cells.length),
                style: TextStyle(
                    color: cs.primary,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        if (widget.frozen)
          Positioned(
            left: 12,
            bottom: 12,
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
        // Top-right toolbar: zoom + reset.
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
                  onPressed: _zoom < _zoomMax
                      ? () {
                          setState(() => _zoom += _zoomStep);
                          _map.move(_map.camera.center, _zoom);
                        }
                      : null,
                ),
                IconButton(
                  tooltip: l.equalGridZoomOut,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.remove),
                  onPressed: _zoom > _zoomMin
                      ? () {
                          setState(() => _zoom -= _zoomStep);
                          _map.move(_map.camera.center, _zoom);
                        }
                      : null,
                ),
                IconButton(
                  tooltip: l.streetMapRecenter,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.my_location),
                  onPressed: () =>
                      _map.move(LatLng(selfLat, selfLon), _zoom),
                ),
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
                IconButton(
                  tooltip: l.fabricResetTooltip,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: cells.isEmpty
                      ? null
                      : () => _confirmReset(mc),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
