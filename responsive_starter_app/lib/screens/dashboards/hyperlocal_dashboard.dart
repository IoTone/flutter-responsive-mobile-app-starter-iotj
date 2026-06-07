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
import '../../theme/viz_palette.dart';
import '../../ui/mm_audio_toggle.dart';
import '../../ui/mm_scaffold.dart';
import '../../util/geo.dart';
import '../device_manager_sheet.dart';
import '../node_detail_sheet.dart';
import 'dashboard_model.dart';

/// Concept C — **Hyperlocal Field** dashboard: discovery-first. The hero
/// is a **node radar** — self at the centre, peers plotted as blips by
/// distance (real GPS distance when both ends have a fix, otherwise by
/// proximity band) and bearing (real bearing when known, otherwise a
/// stable per-node angle). Calm, field-legible, lower chrome than NERV;
/// a slow sweep gives it life (off under reduce-motion). Tap a blip →
/// the node sheet; tap the centre → self. A compact status rail sits
/// underneath. Renders from the same controller as every other skin.
class HyperlocalDashboard extends StatefulWidget {
  const HyperlocalDashboard({super.key});

  @override
  State<HyperlocalDashboard> createState() => _HyperlocalDashboardState();
}

class _HyperlocalDashboardState extends State<HyperlocalDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  Future<void> _showDetail(
      MeshcoreController mc, DiscoveredNode n, bool isSelf) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext _) => NodeDetailSheet(
        node: n,
        isSelf: isSelf,
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
    final bool reduceMotion =
        context.select<ThemeController, bool>((ThemeController t) => t.reduceMotion);
    final DashboardModel m = DashboardModel.gather(mc, l);

    // Honour reduce-motion: stop the sweep (battery + accessibility);
    // otherwise keep it rotating.
    if (reduceMotion) {
      if (_sweep.isAnimating) _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }

    return MmScaffold(
      child: Column(
        children: <Widget>[
          _TopBar(model: m, skin: skin),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: LayoutBuilder(
                builder: (BuildContext _, BoxConstraints c) {
                  final double side =
                      math.min(c.maxWidth, c.maxHeight);
                  final Offset center = Offset(side / 2, side / 2);
                  // Leave a gutter outside the outer ring for the name
                  // callouts (drawn beyond the rings, never over them).
                  final double maxR = side / 2 * 0.68;
                  final ({DiscoveredNode? self, List<_PositionedBlip> blips})
                      laid = _layout(mc, skin, center, maxR);
                  return Center(
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (TapUpDetails d) => _onTap(
                            d.localPosition, laid.blips, laid.self, center, mc),
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _sweep,
                                builder: (BuildContext _, Widget? __) =>
                                    CustomPaint(
                                  painter: _RadarPainter(
                                    center: center,
                                    maxR: maxR,
                                    blips: laid.blips,
                                    hasSelf: laid.self != null,
                                    sweep: reduceMotion ? null : _sweep.value,
                                    grid: VizPalette.of(skin).grid,
                                    accent: skin.color.accent,
                                    self: skin.color.accent,
                                    fg: skin.color.fg,
                                    fgMuted: skin.color.fgMuted,
                                    monoFamily: skin.type.monoFamily,
                                    northLabel: 'N',
                                  ),
                                ),
                              ),
                            ),
                            if (laid.blips.isEmpty)
                              Center(
                                child: Text(
                                  l.dashHyperEmpty,
                                  style: TextStyle(
                                      color: skin.color.fgMuted,
                                      fontFamily: skin.type.monoFamily,
                                      fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _StatusRail(model: m, mc: mc, skin: skin, l: l),
        ],
      ),
    );
  }

  void _onTap(Offset p, List<_PositionedBlip> blips, DiscoveredNode? self,
      Offset center, MeshcoreController mc) {
    // Centre (self) takes priority within a generous radius.
    if (self != null && (p - center).distance <= 22) {
      _showDetail(mc, self, true);
      return;
    }
    _PositionedBlip? best;
    double bestD = 28; // max tap slop, logical px
    for (final _PositionedBlip b in blips) {
      final double d = (p - b.offset).distance;
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    if (best != null) _showDetail(mc, best.node, false);
  }

  /// Project nodes onto the radar. Self (if present in the fabric) is
  /// returned separately — it always sits at the centre.
  ({DiscoveredNode? self, List<_PositionedBlip> blips}) _layout(
      MeshcoreController mc, MmSkin skin, Offset center, double maxR) {
    final String? selfPk = mc.ownPubKeyHex;
    DiscoveredNode? self;
    final List<DiscoveredNode> peers = <DiscoveredNode>[];
    for (final DiscoveredNode n in mc.nodes) {
      if (selfPk != null && n.pubKeyHex == selfPk) {
        self = n;
      } else {
        peers.add(n);
      }
    }

    final OwnLocation? own = mc.ownLocation;
    final Map<String, double?> dist = <String, double?>{};
    final Map<String, double?> bearing = <String, double?>{};
    double? maxMeters;
    for (final DiscoveredNode n in peers) {
      double? d;
      double? b;
      if (n.hasLocation) {
        d = mc.distanceMetersTo(n.latitude!, n.longitude!);
        if (own != null) {
          b = bearingRadians(
              own.latitude, own.longitude, n.latitude!, n.longitude!);
        }
      }
      dist[n.pubKeyHex] = (d != null && d.isFinite) ? d : null;
      bearing[n.pubKeyHex] = b;
      final double? dv = dist[n.pubKeyHex];
      if (dv != null) maxMeters = (maxMeters == null) ? dv : math.max(maxMeters, dv);
    }
    if (maxMeters != null && maxMeters < 1000) maxMeters = 1000;

    final List<_PositionedBlip> blips = <_PositionedBlip>[];
    for (final DiscoveredNode n in peers) {
      final NodeProximity prox = mc.proximityFor(n);
      final double? d = dist[n.pubKeyHex];
      double frac;
      if (d != null && maxMeters != null) {
        frac = (d / maxMeters).clamp(0.08, 0.97);
      } else {
        frac = switch (prox) {
          NodeProximity.near => 0.30,
          NodeProximity.recent => 0.42,
          NodeProximity.mid => 0.66,
          NodeProximity.far => 0.92,
          NodeProximity.unknown => 0.80,
        };
        // Deterministic jitter so same-band peers don't stack.
        frac = (frac + _hashUnit(n.pubKeyHex, 1) * 0.10 - 0.05)
            .clamp(0.08, 0.97);
      }
      final double angle =
          bearing[n.pubKeyHex] ?? (_hashUnit(n.pubKeyHex, 7) * 2 * math.pi);
      final double r = frac * maxR;
      // angle: 0 = North (up), clockwise.
      final Offset pos = Offset(
        center.dx + r * math.sin(angle),
        center.dy - r * math.cos(angle),
      );
      final bool inRange =
          prox == NodeProximity.near || prox == NodeProximity.recent;
      final Color color = switch (prox) {
        NodeProximity.near || NodeProximity.recent => skin.color.ok,
        NodeProximity.mid => skin.color.accent,
        NodeProximity.far || NodeProximity.unknown => skin.color.fgMuted,
      };
      blips.add(_PositionedBlip(
        offset: pos,
        node: n,
        color: color,
        inRange: inRange,
      ));
    }
    return (self: self, blips: blips);
  }
}

/// Stable pseudo-random unit value in [0,1) from a pubkey + salt — keeps
/// a node's radar angle/jitter fixed across rebuilds (FNV-1a).
double _hashUnit(String key, int salt) {
  int h = 0x811c9dc5 ^ salt;
  for (final int c in key.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return (h % 100000) / 100000.0;
}

class _PositionedBlip {
  _PositionedBlip({
    required this.offset,
    required this.node,
    required this.color,
    required this.inRange,
  });
  final Offset offset;
  final DiscoveredNode node;
  final Color color;
  final bool inRange;
}

/// A name callout being laid out: [y] is mutated by the declutter pass.
class _LabelSlot {
  _LabelSlot({required this.blip, required this.y, required this.tp});
  final _PositionedBlip blip;
  double y;
  final TextPainter tp;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.center,
    required this.maxR,
    required this.blips,
    required this.hasSelf,
    required this.sweep,
    required this.grid,
    required this.accent,
    required this.self,
    required this.fg,
    required this.fgMuted,
    required this.monoFamily,
    required this.northLabel,
  });

  final Offset center;
  final double maxR;
  final List<_PositionedBlip> blips;
  final bool hasSelf;

  /// Sweep phase in [0,1), or null under reduce-motion (no sweep drawn).
  final double? sweep;
  final Color grid;
  final Color accent;
  final Color self;
  final Color fg;
  final Color fgMuted;
  final String monoFamily;
  final String northLabel;

  @override
  void paint(Canvas canvas, Size size) {
    // Range rings.
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid.withValues(alpha: 0.45);
    for (final double f in <double>[0.33, 0.66, 1.0]) {
      canvas.drawCircle(center, maxR * f, ring);
    }
    // Cross-hairs.
    final Paint hair = Paint()
      ..strokeWidth = 1
      ..color = grid.withValues(alpha: 0.30);
    canvas.drawLine(Offset(center.dx, center.dy - maxR),
        Offset(center.dx, center.dy + maxR), hair);
    canvas.drawLine(Offset(center.dx - maxR, center.dy),
        Offset(center.dx + maxR, center.dy), hair);

    // Sweep — a leading line + a trailing gradient wedge.
    if (sweep != null) {
      final double a = sweep! * 2 * math.pi; // canvas angle (0 = +x)
      const double trail = math.pi / 3;
      final Rect rect = Rect.fromCircle(center: center, radius: maxR);
      final Paint wedge = Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: trail,
          colors: <Color>[
            accent.withValues(alpha: 0.0),
            accent.withValues(alpha: 0.22),
          ],
          transform: GradientRotation(a - trail),
        ).createShader(rect);
      canvas.drawArc(rect, a - trail, trail, true, wedge);
      final Paint lead = Paint()
        ..strokeWidth = 1.5
        ..color = accent.withValues(alpha: 0.65);
      canvas.drawLine(
          center,
          Offset(center.dx + maxR * math.cos(a),
              center.dy + maxR * math.sin(a)),
          lead);
    }

    // North marker.
    _label(canvas, northLabel, Offset(center.dx, center.dy - maxR - 12),
        fgMuted, 10, center: true);

    // Blips (dots only — in-range names are drawn as decluttered
    // callouts in the gutter outside the rings, below).
    for (final _PositionedBlip b in blips) {
      if (b.inRange) {
        canvas.drawCircle(b.offset, 9,
            Paint()..color = b.color.withValues(alpha: 0.18));
      }
      canvas.drawCircle(b.offset, b.inRange ? 4.5 : 3.5,
          Paint()..color = b.color);
    }

    // Self at the centre — a ringed accent pip.
    if (hasSelf) {
      canvas.drawCircle(center, 9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = self.withValues(alpha: 0.8));
      canvas.drawCircle(center, 4, Paint()..color = self);
    }

    _drawCallouts(canvas, size);
  }

  /// In-range peer names, placed **outside** the outer ring with leader
  /// lines back to their blips. Split into left/right columns and pushed
  /// vertically apart so they never overlap each other or the radar.
  void _drawCallouts(Canvas canvas, Size size) {
    const double fontSize = 11.5;
    const double minGap = 15;
    final double top = 10, bottom = size.height - 10;
    final double gutter = (size.width / 2 - maxR - 8).clamp(34, 96);

    final List<_LabelSlot> left = <_LabelSlot>[];
    final List<_LabelSlot> right = <_LabelSlot>[];
    for (final _PositionedBlip b in blips) {
      if (!b.inRange) continue;
      final TextPainter tp = _textPainter(
          _fit(b.node.name.isEmpty ? b.node.shortId : b.node.name,
              gutter, fontSize),
          fontSize);
      final bool isRight = b.offset.dx >= center.dx;
      (isRight ? right : left)
          .add(_LabelSlot(blip: b, y: b.offset.dy, tp: tp));
    }
    _declutter(left, top, bottom, minGap);
    _declutter(right, top, bottom, minGap);

    final Paint leader = Paint()
      ..strokeWidth = 1
      ..color = fgMuted.withValues(alpha: 0.5);
    for (final _LabelSlot s in right) {
      final double lx = center.dx + maxR + 6;
      canvas.drawLine(s.blip.offset, Offset(lx, s.y), leader);
      s.tp.paint(canvas, Offset(lx + 3, s.y - s.tp.height / 2));
    }
    for (final _LabelSlot s in left) {
      final double lx = center.dx - maxR - 6;
      canvas.drawLine(s.blip.offset, Offset(lx, s.y), leader);
      s.tp.paint(canvas, Offset(lx - 3 - s.tp.width, s.y - s.tp.height / 2));
    }
  }

  /// Push a column of label slots apart so adjacent rows clear [minGap],
  /// keeping the whole column within [top]..[bottom].
  void _declutter(List<_LabelSlot> slots, double top, double bottom,
      double minGap) {
    if (slots.isEmpty) return;
    slots.sort((_LabelSlot a, _LabelSlot b) => a.y.compareTo(b.y));
    for (int i = 1; i < slots.length; i++) {
      if (slots[i].y < slots[i - 1].y + minGap) {
        slots[i].y = slots[i - 1].y + minGap;
      }
    }
    if (slots.last.y > bottom) {
      slots.last.y = bottom;
      for (int i = slots.length - 2; i >= 0; i--) {
        if (slots[i].y > slots[i + 1].y - minGap) {
          slots[i].y = slots[i + 1].y - minGap;
        }
      }
    }
    for (final _LabelSlot s in slots) {
      if (s.y < top) s.y = top;
    }
  }

  /// Truncate [name] (with an ellipsis) to roughly fit [maxWidth] at the
  /// mono face — cheap char-width estimate, no per-frame measuring loop.
  String _fit(String name, double maxWidth, double fontSize) {
    final int maxChars = (maxWidth / (fontSize * 0.62)).floor();
    if (maxChars <= 1) return '…';
    if (name.length <= maxChars) return name;
    return '${name.substring(0, maxChars - 1)}…';
  }

  TextPainter _textPainter(String text, double size) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
              color: fg,
              fontSize: size,
              fontFamily: monoFamily,
              fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  void _label(Canvas canvas, String text, Offset at, Color color,
      double size,
      {bool center = false}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: color, fontSize: size, fontFamily: monoFamily),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Offset o =
        center ? Offset(at.dx - tp.width / 2, at.dy) : at;
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.sweep != sweep ||
      old.blips != blips ||
      old.maxR != maxR ||
      old.center != center;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.model, required this.skin});
  final DashboardModel model;
  final MmSkin skin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
      child: Row(
        children: <Widget>[
          // Title + channel take the remaining space and ellipsize, so
          // the fixed trailing controls never get squeezed into overflow.
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text('MESHMORE',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: skin.type.headingFamily,
                        color: skin.color.fg,
                        fontSize: 16,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('◦ ${model.channelLabel}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: skin.color.accent,
                          fontFamily: skin.type.monoFamily,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (model.alert ? skin.color.alert : skin.color.ok)
                  .withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(model.statusLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: model.alert ? skin.color.alert : skin.color.ok,
                    fontFamily: skin.type.monoFamily,
                    fontSize: 10,
                    letterSpacing: 1)),
          ),
          const MmAudioToggle(),
          IconButton(
            tooltip: 'BLE',
            icon: Icon(Icons.bluetooth,
                size: 20,
                color: model.alert ? skin.color.alert : skin.color.accent),
            onPressed: () => DeviceManagerSheet.show(context),
          ),
        ],
      ),
    );
  }
}

class _StatusRail extends StatelessWidget {
  const _StatusRail(
      {required this.model,
      required this.mc,
      required this.skin,
      required this.l});
  final DashboardModel model;
  final MeshcoreController mc;
  final MmSkin skin;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    double? bestSnr;
    for (final DiscoveredNode n in mc.nodes) {
      final double? s = n.snrDb;
      if (s != null) bestSnr = (bestSnr == null) ? s : math.max(bestSnr, s);
    }
    final List<({String k, String v})> cells = <({String k, String v})>[
      (k: l.dashHyperPeers, v: '${model.peersInRange}'),
      (k: model.channelLabel, v: '·'),
      if (model.contactsLabel != null)
        (k: l.dashContacts, v: model.contactsLabel!),
      if (model.batteryLine != null) (k: 'BATT', v: model.batteryLine!),
      if (bestSnr != null) (k: 'SNR', v: '${bestSnr.toStringAsFixed(0)}dB'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: skin.color.line, width: 1)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 6,
        children: <Widget>[
          for (final ({String k, String v}) c in cells)
            RichText(
              text: TextSpan(
                style: TextStyle(
                    fontFamily: skin.type.monoFamily, fontSize: 12),
                children: <TextSpan>[
                  TextSpan(
                      text: '${c.k} ',
                      style: TextStyle(
                          color: skin.color.fgMuted, fontSize: 10)),
                  TextSpan(text: c.v, style: TextStyle(color: skin.color.fg)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
