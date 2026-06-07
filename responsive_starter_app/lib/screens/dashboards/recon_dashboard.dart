// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/app_localizations.dart';
import '../../meshcore/discovered_node.dart';
import '../../meshcore/meshcore_controller.dart';
import '../../meshcore/own_location.dart';
import '../../theme/mm_skin.dart';
import '../../theme/theme_controller.dart';
import '../../ui/mm_audio_toggle.dart';
import '../../ui/mm_scaffold.dart';
import '../../util/geo.dart';
import '../device_manager_sheet.dart';
import '../node_detail_sheet.dart';
import 'dashboard_model.dart';

/// Concept F — **Tactical Recon** dashboard: night-ops codec. OLED-black,
/// single amber phosphor, map/bearing-first. A small sweep compass + a
/// terse waypoint readout: each contact as `▲ NAME  range  heading°`
/// (real bearing/range when GPS is known, otherwise a stable bearing +
/// proximity). All-mono, dark-adapted, low-overdraw. Tap a row → the node
/// sheet. Same DashboardModel/controller as every skin.
class ReconDashboard extends StatefulWidget {
  const ReconDashboard({super.key});

  @override
  State<ReconDashboard> createState() => _ReconDashboardState();
}

class _ReconDashboardState extends State<ReconDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  Future<void> _open(MeshcoreController mc, DiscoveredNode n) async {
    await showModalBottomSheet<void>(
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
    final AppLocalizations l = AppLocalizations.of(context);
    final MmSkin skin = context.skin;
    final bool reduceMotion = context
        .select<ThemeController, bool>((ThemeController t) => t.reduceMotion);
    final DashboardModel m = DashboardModel.gather(mc, l);

    if (reduceMotion) {
      if (_sweep.isAnimating) _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }

    final Color amber = skin.color.fg;
    final Color dim = skin.color.fgMuted;
    final TextStyle mono = TextStyle(
        fontFamily: skin.type.monoFamily, color: amber, fontSize: 13);

    final List<_Waypoint> waypoints = _waypoints(mc);
    double? bestSnr;
    for (final DiscoveredNode n in mc.nodes) {
      final double? s = n.snrDb;
      if (s != null) bestSnr = (bestSnr == null) ? s : math.max(bestSnr, s);
    }

    return MmScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text('MESHMORE · RECON',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: skin.type.headingFamily,
                          color: amber,
                          fontSize: 15,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700)),
                ),
                Text(m.statusLabel,
                    style: TextStyle(
                        color: m.alert ? skin.color.alert : dim,
                        fontFamily: skin.type.monoFamily,
                        fontSize: 11,
                        letterSpacing: 1)),
                const MmAudioToggle(),
                IconButton(
                  tooltip: 'BLE',
                  icon: Icon(Icons.bluetooth,
                      size: 20,
                      color: m.alert ? skin.color.alert : amber),
                  onPressed: () => DeviceManagerSheet.show(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: skin.color.line),
          // Compass + terse readout.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 92,
                  height: 92,
                  child: AnimatedBuilder(
                    animation: _sweep,
                    builder: (BuildContext _, Widget? __) => CustomPaint(
                      painter: _CompassPainter(
                        sweep: reduceMotion ? null : _sweep.value,
                        amber: amber,
                        dim: dim,
                        waypoints: waypoints,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _kv('PEERS', '${m.peersInRange}/${m.knownCount}', mono, dim),
                      _kv('CH', m.channelLabel, mono, dim),
                      if (m.contactsLabel != null)
                        _kv('CON', m.contactsLabel!, mono, dim),
                      if (m.batteryLine != null)
                        _kv('BATT', m.batteryLine!, mono, dim),
                      _kv('SNR',
                          bestSnr == null ? '—' : '${bestSnr.toStringAsFixed(0)}dB',
                          mono, dim),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: skin.color.surface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Text('CONTACTS // RNG · BRG',
                style: TextStyle(
                    color: dim,
                    fontFamily: skin.type.monoFamily,
                    fontSize: 11,
                    letterSpacing: 1.5)),
          ),
          // Waypoint readout.
          Expanded(
            child: waypoints.isEmpty
                ? Center(
                    child: Text(l.dashReconNoContacts,
                        style: TextStyle(color: dim, fontFamily: skin.type.monoFamily)))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: waypoints.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: skin.color.line),
                    itemBuilder: (BuildContext _, int i) {
                      final _Waypoint w = waypoints[i];
                      return InkWell(
                        onTap: () => _open(mc, w.node),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            children: <Widget>[
                              Text(w.inRange ? '▲' : '△',
                                  style: TextStyle(
                                      color: w.inRange ? amber : dim,
                                      fontSize: 13)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    w.node.name.isEmpty
                                        ? w.node.shortId
                                        : w.node.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: mono),
                              ),
                              const SizedBox(width: 8),
                              Text(w.range,
                                  style: TextStyle(
                                      color: dim,
                                      fontFamily: skin.type.monoFamily,
                                      fontSize: 12)),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 42,
                                child: Text('${w.bearingDeg}°',
                                    textAlign: TextAlign.right,
                                    style: mono),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, TextStyle mono, Color dim) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            SizedBox(
                width: 52,
                child: Text(k,
                    style: TextStyle(
                        color: dim,
                        fontFamily: mono.fontFamily,
                        fontSize: 12,
                        letterSpacing: 1))),
            Text(v, style: mono),
          ],
        ),
      );

  List<_Waypoint> _waypoints(MeshcoreController mc) {
    final String? selfPk = mc.ownPubKeyHex;
    final OwnLocation? own = mc.ownLocation;
    final List<_Waypoint> out = <_Waypoint>[];
    for (final DiscoveredNode n in mc.nodes) {
      if (selfPk != null && n.pubKeyHex == selfPk) continue;
      double? distM;
      int bearingDeg;
      if (n.hasLocation) {
        distM = mc.distanceMetersTo(n.latitude!, n.longitude!);
        if (own != null) {
          final double rad = bearingRadians(
              own.latitude, own.longitude, n.latitude!, n.longitude!);
          bearingDeg = ((rad * 180 / math.pi) % 360).round() % 360;
        } else {
          bearingDeg = _hashDeg(n.pubKeyHex);
        }
      } else {
        bearingDeg = _hashDeg(n.pubKeyHex);
      }
      final String range = _fmtRange(distM);
      final NodeProximity p = mc.proximityFor(n);
      out.add(_Waypoint(
        node: n,
        range: range,
        bearingDeg: bearingDeg.toString().padLeft(3, '0'),
        bearingRad: bearingDeg * math.pi / 180,
        inRange: p == NodeProximity.near || p == NodeProximity.recent,
        distM: distM,
      ));
    }
    out.sort((_Waypoint a, _Waypoint b) {
      if (a.inRange != b.inRange) return a.inRange ? -1 : 1;
      final double da = a.distM ?? double.infinity;
      final double db = b.distM ?? double.infinity;
      return da.compareTo(db);
    });
    return out;
  }

  String _fmtRange(double? m) {
    final String? f = formatDistance(m);
    if (f == null) return '···';
    return f.replaceFirst('≈ ', '').replaceAll(' ', '');
  }

  int _hashDeg(String key) {
    int h = 0x811c9dc5;
    for (final int c in key.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h % 360;
  }
}

class _Waypoint {
  _Waypoint({
    required this.node,
    required this.range,
    required this.bearingDeg,
    required this.bearingRad,
    required this.inRange,
    required this.distM,
  });
  final DiscoveredNode node;
  final String range;
  final String bearingDeg;
  final double bearingRad;
  final bool inRange;
  final double? distM;
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.sweep,
    required this.amber,
    required this.dim,
    required this.waypoints,
  });

  final double? sweep;
  final Color amber;
  final Color dim;
  final List<_Waypoint> waypoints;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 2;
    // Ring.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = dim.withValues(alpha: 0.7));
    // Cardinal ticks.
    final Paint tick = Paint()
      ..strokeWidth = 1
      ..color = dim.withValues(alpha: 0.7);
    for (int d = 0; d < 360; d += 90) {
      final double a = (d - 90) * math.pi / 180;
      canvas.drawLine(
          Offset(c.dx + math.cos(a) * (r - 4), c.dy + math.sin(a) * (r - 4)),
          Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r),
          tick);
    }
    // Contact triangles by bearing (0° = up), radius by in-range.
    for (final _Waypoint w in waypoints) {
      final double a = w.bearingRad - math.pi / 2; // 0° = north/up
      final double rad = (w.inRange ? 0.55 : 0.85) * r;
      final Offset p =
          Offset(c.dx + math.cos(a) * rad, c.dy + math.sin(a) * rad);
      canvas.drawCircle(
          p, 2.2, Paint()..color = w.inRange ? amber : dim);
    }
    // Self.
    canvas.drawCircle(c, 2.0, Paint()..color = amber);
    // Sweep line.
    if (sweep != null) {
      final double a = sweep! * 2 * math.pi;
      canvas.drawLine(
          c,
          Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r),
          Paint()
            ..strokeWidth = 1.5
            ..color = amber.withValues(alpha: 0.7));
    }
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.sweep != sweep || old.waypoints != waypoints;
}
