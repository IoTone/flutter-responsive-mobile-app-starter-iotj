// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/app_localizations.dart';
import '../../meshcore/discovered_node.dart';
import '../../meshcore/meshcore_controller.dart';
import '../../theme/mm_skin.dart';
import '../../theme/theme_controller.dart';
import '../../ui/mm_audio_toggle.dart';
import '../../ui/mm_scaffold.dart';
import '../device_manager_sheet.dart';
import 'dashboard_model.dart';

/// Concept B — **AG Systems HUD** dashboard: a Wipeout anti-grav cockpit.
/// One hero **radial gauge** (signal quality) with a rotating HUD sweep,
/// then a pair of livery stat tiles (peers / channel activity) with linear
/// meters in the team colours. Bold, glanceable, motion-forward (the sweep
/// is off under reduce-motion). Same DashboardModel as every other skin.
class AgHudDashboard extends StatefulWidget {
  const AgHudDashboard({super.key});

  @override
  State<AgHudDashboard> createState() => _AgHudDashboardState();
}

class _AgHudDashboardState extends State<AgHudDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
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

    // Signal quality 0..1 from the best peer SNR (≈ −15…+10 dB), or a
    // neutral reading when linked without telemetry; zero when offline.
    double? bestSnr;
    for (final DiscoveredNode n in mc.nodes) {
      final double? s = n.snrDb;
      if (s != null) bestSnr = (bestSnr == null) ? s : math.max(bestSnr, s);
    }
    final double linkQ = !mc.isReady
        ? 0.0
        : (bestSnr == null ? 0.65 : ((bestSnr + 15) / 25).clamp(0.0, 1.0));
    final int act = mc.messagesFor(mc.activeChannel).length;

    final Color cyan = skin.color.accent;
    final Color magenta = skin.color.alert;

    return MmScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          _BrandBar(model: m, skin: skin),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 240,
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (BuildContext _, Widget? __) => _RadialGauge(
                  value: linkQ,
                  sweep: reduceMotion ? null : _sweep.value,
                  big: mc.isReady ? '${(linkQ * 100).round()}' : '--',
                  unit: '%',
                  label: l.dashAgHudSignal,
                  track: skin.color.line,
                  arc: m.alert ? magenta : cyan,
                  head: m.alert ? magenta : cyan,
                  text: skin.color.fg,
                  textMuted: skin.color.fgMuted,
                  monoFamily: skin.type.monoFamily,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _LiveryTile(
                  skin: skin,
                  label: l.dashHyperPeers,
                  value: '${m.peersInRange}',
                  sub: l.dashAgHudOfKnown('${m.knownCount}'),
                  meter: m.knownCount == 0
                      ? 0
                      : (m.peersInRange / m.knownCount).clamp(0.0, 1.0),
                  livery: cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LiveryTile(
                  skin: skin,
                  label: m.channelLabel,
                  value: '$act',
                  sub: l.dashAgHudTraffic,
                  meter: (act / 30).clamp(0.0, 1.0),
                  livery: magenta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RadioStrip(model: m, skin: skin),
          const SizedBox(height: 12),
          _FeedPanel(model: m, skin: skin, l: l),
        ],
      ),
    );
  }
}

/// Recent-activity feed — fills the cockpit's lower deck with the mesh
/// event ticker (links, messages, discoveries) in the livery style.
class _FeedPanel extends StatelessWidget {
  const _FeedPanel(
      {required this.model, required this.skin, required this.l});
  final DashboardModel model;
  final MmSkin skin;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final TextStyle mono = TextStyle(
        fontFamily: skin.type.monoFamily, color: skin.color.fg, fontSize: 12);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: skin.color.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.dashNervEvents.toUpperCase(),
              style: TextStyle(
                  color: skin.color.accent,
                  fontSize: 11,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (model.events.isEmpty)
            Text(l.dashboardNoActivity,
                style: mono.copyWith(color: skin.color.fgMuted))
          else
            for (final ({String time, String text}) e
                in model.events.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsets.only(top: 5, right: 8),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          color: skin.color.accent, shape: BoxShape.circle),
                    ),
                    Text(e.time,
                        style: mono.copyWith(
                            color: skin.color.fgMuted, fontSize: 11)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.text, style: mono)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  const _BrandBar({required this.model, required this.skin});
  final DashboardModel model;
  final MmSkin skin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text('MESHMORE // AG',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: skin.type.headingFamily,
                color: skin.color.accent,
                fontSize: 17,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w700,
              )),
        ),
        _pill(model.statusLabel, model.alert ? skin.color.alert : skin.color.ok),
        const MmAudioToggle(),
        IconButton(
          tooltip: 'BLE',
          icon: Icon(Icons.bluetooth,
              size: 20,
              color: model.alert ? skin.color.alert : skin.color.accent),
          onPressed: () => DeviceManagerSheet.show(context),
        ),
      ],
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: c,
                fontFamily: skin.type.monoFamily,
                fontSize: 10,
                letterSpacing: 1)),
      );
}

/// A circular signal gauge: a 270° track + value arc + glowing head, a
/// big centred numeral, and (optionally) a rotating HUD sweep line.
class _RadialGauge extends StatelessWidget {
  const _RadialGauge({
    required this.value,
    required this.sweep,
    required this.big,
    required this.unit,
    required this.label,
    required this.track,
    required this.arc,
    required this.head,
    required this.text,
    required this.textMuted,
    required this.monoFamily,
  });

  final double value;
  final double? sweep;
  final String big;
  final String unit;
  final String label;
  final Color track;
  final Color arc;
  final Color head;
  final Color text;
  final Color textMuted;
  final String monoFamily;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _GaugePainter(
                value: value,
                sweep: sweep,
                track: track,
                arc: arc,
                head: head,
                tick: textMuted,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              RichText(
                text: TextSpan(children: <TextSpan>[
                  TextSpan(
                      text: big,
                      style: TextStyle(
                          color: text,
                          fontFamily: monoFamily,
                          fontSize: 52,
                          height: 1.0,
                          fontWeight: FontWeight.w600)),
                  TextSpan(
                      text: unit,
                      style: TextStyle(
                          color: textMuted,
                          fontFamily: monoFamily,
                          fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      letterSpacing: 3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.sweep,
    required this.track,
    required this.arc,
    required this.head,
    required this.tick,
  });

  final double value;
  final double? sweep;
  final Color track;
  final Color arc;
  final Color head;
  final Color tick;

  static const double _start = math.pi * 0.75; // 135°, gap at the bottom
  static const double _span = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 12;
    final Rect rect = Rect.fromCircle(center: c, radius: r);

    // Track.
    canvas.drawArc(
        rect,
        _start,
        _span,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = track);
    // Ticks every 10%.
    final Paint tk = Paint()
      ..strokeWidth = 1.5
      ..color = tick.withValues(alpha: 0.5);
    for (int i = 0; i <= 10; i++) {
      final double a = _start + _span * (i / 10);
      final Offset o = Offset(c.dx + math.cos(a) * (r + 5),
          c.dy + math.sin(a) * (r + 5));
      final Offset inn = Offset(c.dx + math.cos(a) * (r + 1),
          c.dy + math.sin(a) * (r + 1));
      canvas.drawLine(inn, o, tk);
    }
    // Value arc.
    canvas.drawArc(
        rect,
        _start,
        _span * value.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = arc);
    // Glowing head at the value position.
    final double ha = _start + _span * value.clamp(0.0, 1.0);
    final Offset hp = Offset(c.dx + math.cos(ha) * r, c.dy + math.sin(ha) * r);
    canvas.drawCircle(hp, 9, Paint()..color = head.withValues(alpha: 0.25));
    canvas.drawCircle(hp, 4.5, Paint()..color = head);

    // Rotating HUD sweep — a faint line + trailing wedge over the dial.
    if (sweep != null) {
      final double a = sweep! * 2 * math.pi;
      const double trail = math.pi / 4;
      canvas.drawArc(
        rect,
        a - trail,
        trail,
        true,
        Paint()
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: trail,
            colors: <Color>[
              arc.withValues(alpha: 0.0),
              arc.withValues(alpha: 0.16),
            ],
            transform: GradientRotation(a - trail),
          ).createShader(rect),
      );
      canvas.drawLine(
          c,
          Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r),
          Paint()
            ..strokeWidth = 1
            ..color = arc.withValues(alpha: 0.4));
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.sweep != sweep;
}

/// A flat livery stat tile: big numeral + a linear meter in the team
/// colour. The DR-Pop/Wipeout "one hero metric per card" idea.
class _LiveryTile extends StatelessWidget {
  const _LiveryTile({
    required this.skin,
    required this.label,
    required this.value,
    required this.sub,
    required this.meter,
    required this.livery,
  });

  final MmSkin skin;
  final String label;
  final String value;
  final String sub;
  final double meter;
  final Color livery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: skin.color.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: livery, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: TextStyle(
                  color: livery, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: skin.color.fg,
                  fontFamily: skin.type.monoFamily,
                  fontSize: 34,
                  height: 1.0,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: meter,
              minHeight: 5,
              backgroundColor: skin.color.line,
              valueColor: AlwaysStoppedAnimation<Color>(livery),
            ),
          ),
          const SizedBox(height: 6),
          Text(sub,
              style: TextStyle(color: skin.color.fgMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _RadioStrip extends StatelessWidget {
  const _RadioStrip({required this.model, required this.skin});
  final DashboardModel model;
  final MmSkin skin;

  @override
  Widget build(BuildContext context) {
    final TextStyle mono = TextStyle(
        fontFamily: skin.type.monoFamily,
        color: skin.color.fgMuted,
        fontSize: 12);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: skin.color.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.cell_tower, size: 16, color: skin.color.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(model.radioLine ?? '—',
                overflow: TextOverflow.ellipsis, style: mono),
          ),
          if (model.contactsLabel != null) ...<Widget>[
            const SizedBox(width: 8),
            Icon(Icons.contacts_outlined, size: 13, color: skin.color.fgMuted),
            const SizedBox(width: 2),
            Text(model.contactsLabel!, style: mono),
          ],
          if (model.batteryLine != null) ...<Widget>[
            const SizedBox(width: 8),
            Text(model.batteryLine!, style: mono),
          ],
        ],
      ),
    );
  }
}
