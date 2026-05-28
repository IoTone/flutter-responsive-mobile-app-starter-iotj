// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/battery_model.dart';
import '../meshcore/device_power_specs.dart';
import '../meshcore/meshcore_controller.dart';

/// Battery-life analysis for the connected device.
///
/// The companion protocol only reports pack voltage, so this screen
/// turns voltage-over-time into a runtime estimate: state-of-charge
/// from the device's OCV curve, observed drain via regression of the
/// persisted history, and a nameplate cross-check from the matched
/// device spec. Honest about uncertainty — every figure carries its
/// method + confidence.
class BatteryScreen extends StatelessWidget {
  const BatteryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BatteryEstimate est = mc.batteryEstimate;
    final DevicePowerSpec spec = mc.resolvedPowerSpec;
    final List<BatterySample> history = mc.batteryHistory;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.batteryTitle),
        actions: <Widget>[
          if (history.isNotEmpty)
            IconButton(
              tooltip: l.batteryReset,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmReset(context, mc, l),
            ),
        ],
      ),
      body: !est.hasData
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l.batteryAwaiting,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: <Widget>[
                _GaugeRow(est: est, l: l, cs: cs),
                const SizedBox(height: 24),
                _EstimateCard(est: est, l: l, cs: cs),
                const SizedBox(height: 20),
                if (history.length >= 2) ...<Widget>[
                  _SectionLabel(l.batteryHistoryTitle, cs: cs),
                  const SizedBox(height: 8),
                  _HistorySparkline(
                      history: history, spec: spec, cs: cs, l: l),
                  const SizedBox(height: 20),
                ],
                _SectionLabel(l.batterySpecTitle, cs: cs),
                const SizedBox(height: 8),
                _SpecCard(spec: spec, l: l, cs: cs),
              ],
            ),
    );
  }

  Future<void> _confirmReset(
      BuildContext context, MeshcoreController mc, AppLocalizations l) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l.batteryReset),
        content: Text(l.batteryResetConfirm),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.batteryReset)),
        ],
      ),
    );
    if (ok == true) await mc.resetBatteryHistory();
  }
}

/// SoC ring gauge + voltage / charging readout.
class _GaugeRow extends StatelessWidget {
  const _GaugeRow({required this.est, required this.l, required this.cs});
  final BatteryEstimate est;
  final AppLocalizations l;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final double soc = est.socPercent.clamp(0, 100);
    final Color ringColor = _socColor(soc, cs);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 132,
          height: 132,
          child: CustomPaint(
            painter: _GaugePainter(
              soc: soc,
              color: ringColor,
              track: cs.outline.withValues(alpha: .25),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${soc.round()}',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  Text('%',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionLabel(l.batteryVoltageLabel, cs: cs),
              const SizedBox(height: 2),
              Text(
                '${est.volts.toStringAsFixed(2)} V',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 22,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              if (est.charging == true)
                Row(
                  children: <Widget>[
                    Icon(Icons.bolt, size: 16, color: cs.tertiary),
                    const SizedBox(width: 4),
                    Text(l.batteryCharging,
                        style: TextStyle(
                            color: cs.tertiary,
                            fontWeight: FontWeight.w600)),
                  ],
                )
              else
                Text(
                  _methodLabel(est.method, l),
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Time-to-empty + drain + confidence + the "why" line.
class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.est, required this.l, required this.cs});
  final BatteryEstimate est;
  final AppLocalizations l;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionLabel(l.batteryTimeToEmpty, cs: cs),
          const SizedBox(height: 4),
          if (est.charging == true)
            Text(l.batteryChargingNote,
                style: TextStyle(color: cs.onSurface, fontSize: 16))
          else if (est.timeToEmpty != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  _fmtDuration(est.timeToEmpty!, l),
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                _ConfidenceBadge(confidence: est.confidence, l: l, cs: cs),
              ],
            )
          else
            Text(l.batteryEstimating,
                style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (est.drainPctPerHour != null)
            _kv(l.batteryDrainRate,
                '${est.drainPctPerHour!.toStringAsFixed(1)} %/h', cs),
          if (est.method == BatteryMethod.observed &&
              est.observationSpan.inMinutes > 0)
            _kv(l.batteryBasis,
                l.batteryBasisObserved(_fmtDuration(est.observationSpan, l)),
                cs),
          if (est.method == BatteryMethod.rated)
            _kv(l.batteryBasis, l.batteryBasisRated, cs),
          if (est.method == BatteryMethod.none && est.charging != true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.batteryEstimating,
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(k, style: TextStyle(color: cs.onSurfaceVariant)),
            Text(v,
                style: TextStyle(
                    color: cs.onSurface, fontFamily: 'monospace')),
          ],
        ),
      );
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge(
      {required this.confidence, required this.l, required this.cs});
  final BatteryConfidence confidence;
  final AppLocalizations l;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (confidence == BatteryConfidence.none) return const SizedBox.shrink();
    final (String, Color) v = switch (confidence) {
      BatteryConfidence.high => (l.batteryConfHigh, cs.tertiary),
      BatteryConfidence.medium => (l.batteryConfMedium, cs.primary),
      BatteryConfidence.low => (l.batteryConfLow, cs.onSurfaceVariant),
      BatteryConfidence.none => ('', cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: v.$2.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: v.$2.withValues(alpha: .5)),
      ),
      child: Text(
        '${l.batteryConfidence}: ${v.$1}',
        style: TextStyle(
            color: v.$2, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Matched device spec card, or the generic-fallback note.
class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.spec, required this.l, required this.cs});
  final DevicePowerSpec spec;
  final AppLocalizations l;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final String capacity = spec.capacityMah > 0
        ? l.batterySpecCapacity(spec.capacityMah)
        : l.batterySpecCapacityUnknown;
    final double? rx = spec.currentMa['rx'] ?? spec.currentMa['idle'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(spec.isGeneric ? Icons.help_outline : Icons.memory,
                  size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(spec.label,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (spec.isGeneric)
            Text(l.batterySpecGeneric,
                style: TextStyle(
                    color: cs.onSurfaceVariant, height: 1.4))
          else ...<Widget>[
            Text('$capacity  ·  ${spec.chemistry.toUpperCase()}  ·  '
                '${spec.fullVolts.toStringAsFixed(2)}–'
                '${spec.emptyVolts.toStringAsFixed(2)} V',
                style: TextStyle(
                    color: cs.onSurface, fontFamily: 'monospace')),
            if (rx != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    l.batterySpecDraw(rx.round()),
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace')),
              ),
            if (spec.notes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(spec.notes!,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.4)),
              ),
          ],
        ],
      ),
    );
  }
}

/// Voltage history mini-chart over the retained window.
class _HistorySparkline extends StatelessWidget {
  const _HistorySparkline(
      {required this.history,
      required this.spec,
      required this.cs,
      required this.l});
  final List<BatterySample> history;
  final DevicePowerSpec spec;
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final int span = history.last.atUnix - history.first.atUnix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 96,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparkPainter(
              history: history,
              line: cs.primary,
              fill: cs.primary.withValues(alpha: .12),
              grid: cs.outline.withValues(alpha: .2),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.batteryHistorySpan(_fmtDuration(Duration(seconds: span), l),
              history.length),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.cs});
  final String text;
  final ColorScheme cs;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            color: cs.primary, fontSize: 11, letterSpacing: 3),
      );
}

Color _socColor(double soc, ColorScheme cs) {
  if (soc <= 15) return const Color(0xFFFF4030);
  if (soc <= 35) return const Color(0xFFFFB020);
  return cs.primary;
}

String _methodLabel(BatteryMethod m, AppLocalizations l) => switch (m) {
      BatteryMethod.observed => l.batteryMethodObserved,
      BatteryMethod.rated => l.batteryMethodRated,
      BatteryMethod.charging => l.batteryCharging,
      BatteryMethod.none => l.batteryMethodNone,
    };

String _fmtDuration(Duration d, AppLocalizations l) {
  final int days = d.inDays;
  final int hours = d.inHours % 24;
  final int mins = d.inMinutes % 60;
  if (days > 0) return l.batteryDurDH(days, hours);
  if (d.inHours > 0) return l.batteryDurHM(d.inHours, mins);
  return l.batteryDurM(d.inMinutes);
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(
      {required this.soc, required this.color, required this.track});
  final double soc;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = math.min(size.width, size.height) / 2 - 8;
    const double startAngle = math.pi * 0.75; // bottom-left
    const double sweepTotal = math.pi * 1.5; // 270° arc
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), startAngle, sweepTotal,
        false, base);
    final Paint fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), startAngle,
        sweepTotal * (soc / 100).clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.soc != soc || old.color != color;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(
      {required this.history,
      required this.line,
      required this.fill,
      required this.grid});
  final List<BatterySample> history;
  final Color line;
  final Color fill;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    final int t0 = history.first.atUnix;
    final int t1 = history.last.atUnix;
    final int tSpan = math.max(1, t1 - t0);
    int minMv = history.first.millivolts;
    int maxMv = history.first.millivolts;
    for (final BatterySample s in history) {
      if (s.millivolts < minMv) minMv = s.millivolts;
      if (s.millivolts > maxMv) maxMv = s.millivolts;
    }
    // Pad the voltage range so a flat trace isn't a hairline at the edge.
    final double pad = math.max(20, (maxMv - minMv) * 0.15);
    final double lo = minMv - pad;
    final double hi = maxMv + pad;
    final double vSpan = math.max(1, hi - lo);

    double x(int t) => (t - t0) / tSpan * size.width;
    double y(int mv) => size.height - (mv - lo) / vSpan * size.height;

    // Baseline grid.
    final Paint g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (int i = 1; i < 3; i++) {
      final double yy = size.height * i / 3;
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), g);
    }

    final Path path = Path()
      ..moveTo(x(history.first.atUnix), y(history.first.millivolts));
    for (final BatterySample s in history.skip(1)) {
      path.lineTo(x(s.atUnix), y(s.millivolts));
    }
    final Path area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = line);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.history.length != history.length ||
      (history.isNotEmpty &&
          old.history.isNotEmpty &&
          old.history.last.atUnix != history.last.atUnix);
}
