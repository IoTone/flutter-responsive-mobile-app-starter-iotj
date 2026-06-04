// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/chat_message.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import '../theme/theme_controller.dart';
import '../util/geo.dart' as geo;
import 'elevation_profile_view.dart';
import 'equal_grid_view.dart';
import 'fabric_survey_view.dart';
import 'globe_view.dart';
import 'mesh_tree_view.dart';
import 'node_detail_sheet.dart';
import 'sns_cells_view.dart';
import 'street_map_view.dart';
import 'weather_view.dart';

/// R27 — three map views in the /grid picker:
/// `radial` (R18, default) + `globe` (R27) + `equalGrid` (R25) +
/// `streetMap` (R25+2). Selected via a [PopupMenuButton] in the
/// AppBar — swipe nav was tried in R25+2 but conflicted with the
/// outer HomeShell PageView (left-swipe-from-radial would leave the
/// grid tab instead of staying inside it). The dropdown is
/// unambiguous and matches Material conventions.
enum _GridViewMode {
  radial,
  globe,
  equalGrid,
  streetMap,
  fabric,
  elevation,
  tree,
  snsCells,
  weather,
}

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
  /// "the same room", through wide-area at 5 km (the practical LoRa
  /// SF7-12 outdoor envelope), then City (~metro) and Region. The
  /// **Region** stop is special: its scale is computed at runtime to
  /// frame the farthest known node (see `_effectiveScaleKm`); the km
  /// here is only a fallback when no located nodes are visible.
  static const List<({String label, double km})> rangeStops =
      <({String label, double km})>[
    (label: 'Room', km: 0.025),
    (label: 'Home', km: 0.10),
    (label: 'Block', km: 0.5),
    (label: 'Neighborhood', km: 1.0),
    (label: 'Area', km: 2.0),
    (label: 'Wide', km: 5.0),
    (label: 'City', km: 25.0),
    (label: 'Region', km: 300.0),
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

  /// R27 — which of the available map views is showing.
  _GridViewMode _viewMode = _GridViewMode.radial;

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
  /// Default stays at **Wide** (5 km) even though City/Region sit
  /// beyond it on the slider.
  int _scaleIndex =
      GridScreen.rangeStops.indexWhere((s) => s.label == 'Wide');

  /// Live phone compass heading in degrees from magnetic north
  /// (0=N, 90=E, 180=S, 270=W). Null when no sensor data has
  /// arrived yet. Drives the radar's heading needle + heading-up mode.
  double? _headingDeg;

  /// Radar orientation. True (default) = north-up: north is always at
  /// the top, with a heading needle showing which way you face. False
  /// = heading-up: the whole radar rotates so your facing direction is
  /// at the top and the cardinal rose rotates to show where north is.
  bool _northUp = true;

  /// Reported accuracy (degrees, lower = better). When > 25 we
  /// surface a small "calibrate phone (figure-8 wave)" hint.
  double? _headingAccuracyDeg;

  StreamSubscription<CompassEvent>? _compassSub;

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
    // Compass subscription — platform-fused heading. Stream may be
    // null on devices without a magnetometer; in that case the
    // overlay is just skipped. We subscribe at screen-mount time
    // (cheap ~5-10 mA while open) and cancel on dispose.
    final Stream<CompassEvent>? src = FlutterCompass.events;
    if (src != null) {
      _compassSub = src.listen((CompassEvent e) {
        if (!mounted) return;
        setState(() {
          _headingDeg = e.heading;
          _headingAccuracyDeg = e.accuracy;
        });
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgSub?.cancel();
    _compassSub?.cancel();
    _tick.dispose();
    super.dispose();
  }

  void _refreshSnapshot() {
    if (!mounted) return;
    setState(() => _snapshot = List<DiscoveredNode>.of(
        context.read<MeshcoreController>().nodes));
  }

  /// Icon for the AppBar picker entry / button. Each mode has a
  /// distinctive Material symbol so the dropdown reads as glanceable
  /// regardless of language.
  static IconData _iconForMode(_GridViewMode m) => switch (m) {
        _GridViewMode.radial => Icons.radar,
        _GridViewMode.globe => Icons.public,
        _GridViewMode.equalGrid => Icons.grid_on,
        _GridViewMode.streetMap => Icons.map_outlined,
        _GridViewMode.fabric => Icons.view_quilt,
        _GridViewMode.elevation => Icons.terrain,
        _GridViewMode.tree => Icons.account_tree,
        _GridViewMode.snsCells => Icons.local_fire_department,
        _GridViewMode.weather => Icons.thermostat,
      };

  /// 4–5 character all-caps label for the picker button + menu. Keep
  /// short so the AppBar isn't dominated. Long names live in the
  /// row's trailing subtitle.
  static String _shortLabel(_GridViewMode m, AppLocalizations l) =>
      switch (m) {
        _GridViewMode.radial => l.gridViewRadialShort,
        _GridViewMode.globe => l.gridViewGlobeShort,
        _GridViewMode.equalGrid => l.gridViewEqualGridShort,
        _GridViewMode.streetMap => l.gridViewStreetMapShort,
        _GridViewMode.fabric => l.gridViewFabricShort,
        _GridViewMode.elevation => l.gridViewElevationShort,
        _GridViewMode.tree => l.gridViewTreeShort,
        _GridViewMode.snsCells => l.gridViewSnsCellsShort,
        _GridViewMode.weather => l.gridViewWeatherShort,
      };

  static String _longLabel(_GridViewMode m, AppLocalizations l) =>
      switch (m) {
        _GridViewMode.radial => l.gridViewRadial,
        _GridViewMode.globe => l.gridViewGlobe,
        _GridViewMode.equalGrid => l.gridViewEqualGrid,
        _GridViewMode.streetMap => l.gridViewStreetMap,
        _GridViewMode.fabric => l.gridViewFabric,
        _GridViewMode.elevation => l.gridViewElevation,
        _GridViewMode.tree => l.gridViewTree,
        _GridViewMode.snsCells => l.gridViewSnsCells,
        _GridViewMode.weather => l.gridViewWeather,
      };


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

  /// Localised label for the current Range slider stop. The
  /// stop list itself stays as English keys (matching the asset /
  /// codepath identity); the user-facing label is translated.
  String _rangeLabel(AppLocalizations l, int idx) {
    return switch (idx) {
      0 => l.gridRangeRoom,
      1 => l.gridRangeHome,
      2 => l.gridRangeBlock,
      3 => l.gridRangeNeighborhood,
      4 => l.gridRangeArea,
      5 => l.gridRangeWide,
      6 => l.gridRangeCity,
      _ => l.gridRangeRegion,
    };
  }

  /// The outer-ring scale in km for the current stop. Most stops use
  /// their fixed km; the **Region** stop (the last) instead frames the
  /// farthest located node so it shows the whole known mesh extent,
  /// falling back to the stop's km when no node has a location.
  double _effectiveScaleKm(
      double? selfLat, double? selfLon, List<DiscoveredNode> visible) {
    final double base = GridScreen.rangeStops[_scaleIndex].km;
    final bool isRegion = _scaleIndex == GridScreen.rangeStops.length - 1;
    if (!isRegion || selfLat == null || selfLon == null) return base;
    double maxKm = 0;
    for (final DiscoveredNode n in visible) {
      if (!n.hasLocation) continue;
      final double km = geo.haversineMeters(
              selfLat, selfLon, n.latitude!, n.longitude!) /
          1000.0;
      if (km > maxKm) maxKm = km;
    }
    if (maxKm <= 0) return base;
    // Pad 10% so the farthest node sits just inside the rim; clamp to
    // a sane window.
    return (maxKm * 1.1).clamp(50.0, 2000.0);
  }

  /// Pretty distance label for a scale stop (e.g. "25 m" / "5 km").
  String _rangeValue(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(0)} km';
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
    double rotationRad = 0,
  }) {
    final Offset center = Offset(area.width / 2, area.height / 2);
    final double maxR = math.min(area.width, area.height) / 2 - 24;
    if (maxR <= 0) return null;
    final double scaleKm = _effectiveScaleKm(selfLat, selfLon, visible);
    DiscoveredNode? best;
    double bestDist = double.infinity;
    for (final DiscoveredNode n in visible) {
      final Offset p = _GridPainter.positionFor(
        node: n,
        center: center,
        maxR: maxR,
        selfLat: selfLat,
        selfLon: selfLon,
        scaleKm: scaleKm,
        rotationRad: rotationRad,
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

    // Filter visible nodes — within the 24 h recency window AND not
    // ourselves (we shouldn't appear in our own fabric; the centre
    // marker is us). `ownPubKeyHex` is null until SelfInfo arrives,
    // in which case nothing is filtered.
    final int nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int windowSec = GridScreen.recencyWindow.inSeconds;
    final String? selfPk = mc.ownPubKeyHex;
    final List<DiscoveredNode> visible = <DiscoveredNode>[
      for (final DiscoveredNode n in source)
        if (nowUnix - n.lastHeardUnix < windowSec &&
            n.pubKeyHex != selfPk)
          n
    ];

    final double scaleKm = _effectiveScaleKm(
        mc.selfInfo?.latitude, mc.selfInfo?.longitude, visible);
    final AppLocalizations l = AppLocalizations.of(context);
    final String scaleLabel = _rangeLabel(l, _scaleIndex);
    final String scaleValue = _rangeValue(scaleKm);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.gridTitle),
        actions: <Widget>[
          // R27 + R25 + R25+4 — view-mode picker. PopupMenuButton
          // shows icon + short label per mode. Swipe nav was tried
          // in R25+2 but conflicted with the outer HomeShell
          // PageView at the boundary (left-swipe-from-radial would
          // leave the grid tab instead of staying inside it). The
          // dropdown is unambiguous and one tap shorter than a
          // cycle for mid-list modes.
          PopupMenuButton<_GridViewMode>(
            tooltip: l.gridViewPicker,
            initialValue: _viewMode,
            onSelected: (_GridViewMode m) =>
                setState(() => _viewMode = m),
            // Icon + dropdown arrow only — the inline 5-char label
            // was pushing the AppBar title ("Hyperlocal grid") into
            // ellipsis. Long label still shows on each row inside
            // the menu, so users still see what they're picking.
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(_iconForMode(_viewMode)),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
            itemBuilder: (BuildContext _) =>
                <PopupMenuEntry<_GridViewMode>>[
              for (final _GridViewMode m in _GridViewMode.values)
                CheckedPopupMenuItem<_GridViewMode>(
                  value: m,
                  checked: _viewMode == m,
                  child: Row(
                    children: <Widget>[
                      Icon(_iconForMode(m),
                          size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text(_shortLabel(m, l),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                      const SizedBox(width: 8),
                      Text(_longLabel(m, l),
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: _live ? l.gridPauseTooltip : l.gridPlayTooltip,
            icon: Icon(_live ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlay,
          ),
          PopupMenuButton<Duration>(
            tooltip: l.gridIntervalTooltip,
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
            tooltip: _legendVisible
                ? l.gridHideLegend
                : l.gridShowLegend,
            icon: Icon(_legendVisible
                ? Icons.info
                : Icons.info_outline),
            onPressed: () =>
                setState(() => _legendVisible = !_legendVisible),
          ),
        ],
      ),
      // R25+4 — dropdown picker drives mode (was PageView in R25+2;
      // swiping conflicted with the outer HomeShell tab swipe). The
      // body just renders the chosen mode's widget.
      body: switch (_viewMode) {
        _GridViewMode.globe => GlobeView(
            filteredNodes: visible,
            frozen: !_live && _userInteracted,
          ),
        _GridViewMode.equalGrid => EqualGridView(
            cellSizeMeters: EqualGridView.cellSizeForRangeKm(
                GridScreen.rangeStops[_scaleIndex].km),
            filteredNodes: visible,
            frozen: !_live && _userInteracted,
          ),
        _GridViewMode.streetMap => StreetMapView(
            filteredNodes: visible,
            frozen: !_live && _userInteracted,
          ),
        _GridViewMode.fabric => Stack(
            children: <Widget>[
              FabricSurveyView(
                filteredNodes: visible,
                frozen: !_live && _userInteracted,
              ),
              if (_legendVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _FabricLegend(cs: cs, l: l),
                ),
            ],
          ),
        _GridViewMode.elevation => Stack(
            children: <Widget>[
              ElevationProfileView(filteredNodes: visible),
              if (_legendVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _FujiLegend(cs: cs, l: l),
                ),
            ],
          ),
        // Tree mode overlays the legend strip on top of the canvas
        // so the info button does something here (the radial branch
        // is the only other place that hosts a legend). Stack lets
        // the legend dismiss without restructuring the layout.
        _GridViewMode.tree => Stack(
            children: <Widget>[
              MeshTreeView(
                filteredNodes: visible,
                frozen: !_live && _userInteracted,
              ),
              if (_legendVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _TreeLegend(cs: cs, l: l),
                ),
            ],
          ),
        _GridViewMode.snsCells => Stack(
            children: <Widget>[
              SnsCellsView(
                filteredNodes: visible,
                frozen: !_live && _userInteracted,
              ),
              if (_legendVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _SnsCellsLegend(cs: cs, l: l),
                ),
            ],
          ),
        _GridViewMode.weather => WeatherView(filteredNodes: visible),
        _GridViewMode.radial => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              ready
                  ? l.gridStatusReady(
                      visible.length,
                      mc.known.length,
                      mc.favorites.length,
                      _live
                          ? l.gridPlayStateLive(_intervalLabel(_interval))
                          : l.gridPlayStatePaused,
                    )
                  : l.gridStatusOffline,
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
                Text(l.gridRange,
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
                    label: scaleLabel,
                    onChanged: (double v) => setState(() {
                      _userInteracted = true;
                      _scaleIndex = v.round();
                    }),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    '$scaleLabel · $scaleValue',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (_legendVisible)
            _GridLegend(cs: cs, scaleKm: scaleKm, l: l),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        l.gridEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (BuildContext _, BoxConstraints c) {
                      final Size area =
                          Size(c.maxWidth, c.maxHeight);
                      // Heading-up rotates the whole plot so the facing
                      // direction is at the top. North-up (default) or
                      // no compass data → no rotation.
                      final double headingRot =
                          (_northUp || _headingDeg == null)
                              ? 0.0
                              : -(_headingDeg! * math.pi / 180);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (TapDownDetails d) {
                          final DiscoveredNode? hit = _hitTest(
                            tap: d.localPosition,
                            area: area,
                            visible: visible,
                            selfLat: mc.selfInfo?.latitude,
                            selfLon: mc.selfInfo?.longitude,
                            rotationRad: headingRot,
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
                              headingDeg: _headingDeg,
                              scaleKm: scaleKm,
                              rotationRad: headingRot,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_headingDeg != null && visible.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(child: _headingHud(cs, l)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l.gridFooter(scaleLabel.toLowerCase(), scaleValue),
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      },
    );
  }

  /// Map a compass heading (degrees, 0 = N) to a one- or two-letter
  /// cardinal direction. 16-wind compass.
  String _cardinal(double headingDeg) {
    final double n = ((headingDeg % 360) + 360) % 360;
    const List<String> winds = <String>[
      'N', 'NNE', 'NE', 'ENE',
      'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW',
      'W', 'WNW', 'NW', 'NNW',
    ];
    final int idx = ((n + 11.25) ~/ 22.5) % 16;
    return winds[idx];
  }

  /// Prominent heading HUD pinned to the top of the radar — a large,
  /// monospace, HUD-style readout of the compass heading with the
  /// north-up / heading-up toggle. Replaces the tiny footer text.
  Widget _headingHud(ColorScheme cs, AppLocalizations l) {
    final int deg = _headingDeg!.round();
    final String card = _cardinal(_headingDeg!);
    final bool poorAccuracy =
        _headingAccuracyDeg != null && _headingAccuracyDeg! > 25;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '◊ ${l.gridHeadingHud}',
                style: TextStyle(
                    color: cs.primary.withValues(alpha: .7),
                    fontSize: 9,
                    letterSpacing: 5,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    deg.toString().padLeft(3, '0'),
                    style: TextStyle(
                        color: cs.primary,
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        letterSpacing: 2),
                  ),
                  Text('°',
                      style: TextStyle(
                          color: cs.primary.withValues(alpha: .7),
                          fontSize: 22,
                          fontFamily: 'monospace')),
                  const SizedBox(width: 10),
                  Text(card,
                      style: TextStyle(
                          color: cs.tertiary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          letterSpacing: 3)),
                ],
              ),
              if (poorAccuracy)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.explore_off, size: 11, color: cs.tertiary),
                      const SizedBox(width: 4),
                      Text(l.gridHeadingCalibrate,
                          style:
                              TextStyle(color: cs.tertiary, fontSize: 9)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 22,
            tooltip:
                _northUp ? l.gridOrientHeadingUp : l.gridOrientNorthUp,
            icon: Icon(
              _northUp ? Icons.explore_outlined : Icons.navigation,
              color: cs.primary,
            ),
            onPressed: () => setState(() => _northUp = !_northUp),
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
  const _GridLegend(
      {required this.cs, required this.scaleKm, required this.l});
  final ColorScheme cs;
  final double scaleKm;
  final AppLocalizations l;

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
    final String scaleValueDisplay = scaleKm < 1
        ? '${(scaleKm * 1000).round()} m'
        : '${scaleKm.toStringAsFixed(0)} km';
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
          Text(l.gridLegend,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 3)),
          const SizedBox(height: 6),
          row(Icons.adjust, l.gridLegendRings(scaleValueDisplay)),
          row(Icons.my_location, l.gridLegendSelf),
          row(Icons.circle, l.gridLegendDot),
          row(Icons.radio_button_checked, l.gridLegendKnown),
          row(Icons.star, l.gridLegendFavourite),
          row(Icons.waves, l.gridLegendRipple),
          row(Icons.touch_app, l.gridLegendTap),
          const SizedBox(height: 6),
          // Heading semantics — what the wedge actually means + how
          // to fix it when it points the wrong way.
          row(Icons.explore, l.gridLegendHeading),
          row(Icons.threesixty, l.gridLegendCalibration),
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
    this.headingDeg,
    this.rotationRad = 0,
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

  /// Live phone compass heading (degrees from magnetic north,
  /// 0=N / 90=E / 180=S / 270=W). When non-null, the painter draws a
  /// heading needle from the centre showing which way the user is
  /// facing, paired with the cardinal rose.
  final double? headingDeg;

  /// Plot rotation in radians. 0 = north-up (north at the top).
  /// `-headingRad` rotates the whole scene so the facing direction is
  /// at the top (heading-up mode). Applied to nodes, the cardinal
  /// rose, and the heading needle so they stay mutually consistent.
  final double rotationRad;

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
    double rotationRad = 0,
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
    // rotationRad rotates the whole plot (heading-up mode); 0 = north-up.
    final double a = angle + rotationRad;
    return center +
        Offset(radius * math.sin(a), -radius * math.cos(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double maxR = math.min(size.width, size.height) / 2 - 24;
    if (maxR <= 0) return;

    // Concentric range rings — slightly thicker stroke than 1 so
    // they survive low-contrast themes; per-ring distance label on
    // the +X axis so the user can read the scale at a glance.
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ringStroke;
    const List<double> ringFracs = <double>[1 / 3, 2 / 3, 1.0];
    for (final double f in ringFracs) {
      canvas.drawCircle(center, maxR * f, ring);
    }
    // Ring labels. Position each label just inside the ring on the
    // right (+X) axis so they don't collide with node markers in
    // typical fleets.
    for (final double f in ringFracs) {
      final double meters = scaleKm * f * 1000;
      final String label = meters < 1000
          ? '${meters.round()} m'
          : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              color: base, fontSize: 10, fontFamily: 'monospace'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(center.dx + maxR * f - tp.width - 4,
            center.dy - tp.height - 2),
      );
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

    // Compass rose — north-up cardinal markers + a tick ring so the
    // radar reads like a real compass. North is always up (the grid
    // frame is north-up); the needle below shows which way you face.
    _drawCompassRose(canvas, center, maxR);

    // Self marker.
    canvas.drawCircle(center, 5, Paint()..color = accent);
    canvas.drawCircle(center, 9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent.withValues(alpha: .6));

    // Heading needle — points in the user's compass heading (the way
    // they're facing). The north-up frame stays the stable reference;
    // needle + rose together read as a real compass.
    final double? hd = headingDeg;
    if (hd != null) {
      _drawHeadingNeedle(canvas, center, maxR, hd);
    }

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
        rotationRad: rotationRad,
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

  /// Screen direction unit vector for a compass bearing (radians,
  /// 0 = N) under the current [rotationRad]. north-up → N points up.
  Offset _bearingDir(double bearingRad) {
    final double a = bearingRad + rotationRad;
    return Offset(math.sin(a), -math.cos(a));
  }

  /// Compass rose: an 8-point tick ring + N/E/S/W letters just outside
  /// the outer range ring. Rotates with [rotationRad] so in heading-up
  /// mode the cardinals show where north actually is.
  void _drawCompassRose(Canvas canvas, Offset center, double maxR) {
    final Paint tick = Paint()
      ..color = base.withValues(alpha: .6)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 8; i++) {
      final Offset dir = _bearingDir(i * math.pi / 4);
      final double inner = maxR - (i.isEven ? 10 : 6);
      canvas.drawLine(center + dir * inner, center + dir * maxR, tick);
    }
    final List<({String s, double bearing, bool n})> marks =
        <({String s, double bearing, bool n})>[
      (s: 'N', bearing: 0, n: true),
      (s: 'E', bearing: math.pi / 2, n: false),
      (s: 'S', bearing: math.pi, n: false),
      (s: 'W', bearing: 3 * math.pi / 2, n: false),
    ];
    final double lr = maxR + 12;
    for (final ({String s, double bearing, bool n}) m in marks) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: m.s,
          style: TextStyle(
            color: m.n ? accent : base,
            fontSize: m.n ? 13 : 11,
            fontFamily: 'monospace',
            fontWeight: m.n ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final Offset c = center + _bearingDir(m.bearing) * lr;
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// Heading needle pointing in the user's facing direction. In
  /// north-up it points toward the heading bearing; in heading-up it
  /// points straight up (the facing direction is the top). A short
  /// muted tail gives it a magnetic-needle feel.
  void _drawHeadingNeedle(
      Canvas canvas, Offset center, double maxR, double headingDeg) {
    final Offset dir = _bearingDir(headingDeg * math.pi / 180);
    final Offset perp = Offset(-dir.dy, dir.dx);
    final double len = (maxR * 0.34).clamp(28.0, 80.0);
    const double halfW = 6.0;
    final Offset tip = center + dir * len;
    final Offset baseC = center + dir * 12;
    final Path needle = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((baseC + perp * halfW).dx, (baseC + perp * halfW).dy)
      ..lineTo((baseC - perp * halfW).dx, (baseC - perp * halfW).dy)
      ..close();
    canvas.drawPath(needle, Paint()..color = accent);
    canvas.drawLine(
      center,
      center - dir * (len * 0.4),
      Paint()
        ..color = base.withValues(alpha: .5)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.nodes != nodes ||
      old.favorites != favorites ||
      old.known != known ||
      old.tick != tick ||
      old.reduceMotion != reduceMotion ||
      old.rippleAt != rippleAt ||
      old.scaleKm != scaleKm ||
      old.headingDeg != headingDeg ||
      old.rotationRad != rotationRad;
}

/// R50 — info-button legend specifically for the Mesh Tree view.
/// Different from the radial legend ([_GridLegend]) because the tree
/// has no rings, no scale, and the node glyphs mean something
/// different (role × halo state instead of recency).
class _TreeLegend extends StatelessWidget {
  const _TreeLegend({required this.cs, required this.l});
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text, {Color? colour}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 14, color: colour ?? cs.primary),
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
          Text(l.meshTreeLegendTitle,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 3)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l.meshTreeLegendDesc,
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    height: 1.35)),
          ),
          row(Icons.my_location, l.meshTreeLegendSelf, colour: cs.primary),
          row(Icons.crop_square, l.meshTreeLegendRepeater,
              colour: cs.tertiary),
          row(Icons.diamond, l.meshTreeLegendRoom, colour: cs.tertiary),
          row(Icons.circle, l.meshTreeLegendChat, colour: cs.primary),
          row(Icons.sensors, l.meshTreeLegendSensor,
              colour: cs.primary.withValues(alpha: .55)),
          row(Icons.more_horiz, l.meshTreeLegendFlood,
              colour: cs.onSurfaceVariant),
          row(Icons.help_outline, l.meshTreeLegendFloat,
              colour: cs.onSurfaceVariant),
          row(Icons.arrow_forward, l.meshTreeLegendArrow),
          row(Icons.touch_app, l.meshTreeLegendInteract),
        ],
      ),
    );
  }
}

/// R50 — info-button legend specifically for the Fabric Survey view.
/// Different from the radial legend ([_GridLegend]) and the tree
/// legend ([_TreeLegend]) — explains the coverage quilt cells,
/// recency tiers, and the peer markers.
class _FabricLegend extends StatelessWidget {
  const _FabricLegend({required this.cs, required this.l});
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text, {Color? colour}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 14, color: colour ?? cs.primary),
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
          Text(l.fabricLegendTitle,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 3)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l.fabricLegendDesc,
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    height: 1.35)),
          ),
          row(Icons.grid_view, l.fabricLegendCell, colour: cs.secondary),
          row(Icons.gradient, l.fabricLegendRecency, colour: cs.secondary),
          row(Icons.place, l.fabricLegendMarker, colour: cs.tertiary),
          row(Icons.my_location, l.fabricLegendSelf, colour: cs.primary),
          row(Icons.delete_sweep, l.fabricLegendReset),
        ],
      ),
    );
  }
}

/// Info-button legend for the Fujiさん elevation view.
class _FujiLegend extends StatelessWidget {
  const _FujiLegend({required this.cs, required this.l});
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text, {Color? colour}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 14, color: colour ?? cs.primary),
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
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.fujiLegendTitle,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 3)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l.fujiLegendDesc,
                style: TextStyle(
                    color: cs.onSurface, fontSize: 12, height: 1.35)),
          ),
          row(Icons.my_location, l.fujiLegendMe, colour: cs.tertiary),
          row(Icons.terrain, l.fujiLegendRefs, colour: cs.primary),
          row(Icons.circle, l.fujiLegendPeers,
              colour: cs.primary.withValues(alpha: .7)),
          row(Icons.help_outline, l.fujiLegendUnknown,
              colour: cs.onSurfaceVariant),
          row(Icons.touch_app, l.fujiLegendAutoQuery),
        ],
      ),
    );
  }
}

/// R51 — info-button legend for the sns-cells social heat map.
class _SnsCellsLegend extends StatelessWidget {
  const _SnsCellsLegend({required this.cs, required this.l});
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text, {Color? colour}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 14, color: colour ?? cs.primary),
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
          Text(l.snsCellsLegendTitle,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 3)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l.snsCellsLegendDesc,
                style: TextStyle(
                    color: cs.onSurface, fontSize: 12, height: 1.35)),
          ),
          row(Icons.local_fire_department, l.snsCellsLegendHot,
              colour: const Color(0xFFFF3030)),
          row(Icons.ac_unit, l.snsCellsLegendCool),
          row(Icons.chat_bubble_outline, l.snsCellsLegendToast,
              colour: cs.tertiary),
          row(Icons.lock_outline, l.snsCellsLegendChannel,
              colour: cs.primary),
          row(Icons.place_outlined, l.snsCellsLegendInferred,
              colour: const Color(0xFF8A6CFF)),
          row(Icons.timelapse, l.snsCellsLegendDecay),
        ],
      ),
    );
  }
}
