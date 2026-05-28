// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'device_power_specs.dart';

/// One persisted battery reading: a UNIX-second timestamp and the
/// pack voltage in millivolts (what the companion protocol gives us).
typedef BatterySample = ({int atUnix, int millivolts});

/// Which method produced the time-to-empty figure.
enum BatteryMethod {
  /// Not enough data yet — only state-of-charge is shown.
  none,

  /// Charging (or at rest with a rising trend) — runtime not
  /// meaningful.
  charging,

  /// Measured drain: regression of state-of-charge over the observed
  /// history. The honest, device-specific answer.
  observed,

  /// Nameplate estimate: remaining capacity ÷ typical current draw
  /// from the device spec. A cold-start guess until enough drain has
  /// been observed.
  rated,
}

/// How much to trust the estimate. Drives the badge in the UI.
enum BatteryConfidence { none, low, medium, high }

/// Result of [estimateBattery]. Self-describing so the UI can render
/// the figure, the method, the confidence, and the reasoning behind
/// it without re-deriving anything.
class BatteryEstimate {
  const BatteryEstimate({
    required this.socPercent,
    required this.volts,
    required this.charging,
    required this.method,
    required this.confidence,
    this.drainPctPerHour,
    this.timeToEmpty,
    this.sampleCount = 0,
    this.observationSpan = Duration.zero,
    this.socDeltaObserved = 0,
  });

  /// State-of-charge (0..100) from the latest voltage via the spec's
  /// OCV curve. NaN only if there is no data at all.
  final double socPercent;

  /// Latest pack voltage in volts.
  final double volts;

  /// Charging trend from the controller's voltage heuristic.
  final bool? charging;

  final BatteryMethod method;
  final BatteryConfidence confidence;

  /// Discharge rate in percentage-points per hour (positive while
  /// draining). Null when charging / unknown.
  final double? drainPctPerHour;

  /// Projected time until empty. Null when charging / unknown.
  final Duration? timeToEmpty;

  // --- Diagnostics for the UI's "why" line ---
  final int sampleCount;
  final Duration observationSpan;
  final double socDeltaObserved;

  bool get hasData => !socPercent.isNaN;

  /// Empty-battery sentinel for the "no readings yet" state.
  static const BatteryEstimate empty = BatteryEstimate(
    socPercent: double.nan,
    volts: 0,
    charging: null,
    method: BatteryMethod.none,
    confidence: BatteryConfidence.none,
  );
}

/// Tunables for the observed-drain estimate. Defaults chosen for a
/// 60-second battery poll decimated to a few-minute history.
class BatteryEstimatorConfig {
  const BatteryEstimatorConfig({
    this.windowHours = 8.0,
    this.minSamples = 4,
    this.minSpanHours = 0.5,
    this.minSocDelta = 1.5,
  });

  /// Only regress over samples within this many hours of the latest
  /// reading — keeps a stale prior session from dominating.
  final double windowHours;

  /// Minimum samples in the window before observed drain is trusted.
  final int minSamples;

  /// Minimum time span the window must cover.
  final double minSpanHours;

  /// Minimum state-of-charge drop observed before a slope is
  /// believable (the mid-curve is flat, so tiny deltas are noise).
  final double minSocDelta;
}

/// Compute a battery-life estimate from a voltage history and a
/// device spec. Pure: no clocks, no IO. [nowUnix] is the reference
/// time for the time-to-empty projection (defaults to the latest
/// sample's timestamp).
///
/// Strategy (best-effort, honest about uncertainty):
/// 1. SoC from the latest voltage via the spec's OCV curve.
/// 2. If charging → report SoC only (runtime not meaningful).
/// 3. Observed: least-squares regression of SoC over the recent
///    window. If it's draining with enough span / delta / fit,
///    time-to-empty = SoC ÷ drain. Confidence scales with span + R².
/// 4. Rated: when the observed fit is too weak but the spec has a
///    capacity + current rating, fall back to capacity ÷ draw.
/// 5. Otherwise SoC only (method none).
BatteryEstimate estimateBattery({
  required List<BatterySample> samples,
  required DevicePowerSpec spec,
  bool? charging,
  int? nowUnix,
  BatteryEstimatorConfig config = const BatteryEstimatorConfig(),
}) {
  if (samples.isEmpty) return BatteryEstimate.empty;

  // Chronological order, latest last.
  final List<BatterySample> sorted = List<BatterySample>.of(samples)
    ..sort((a, b) => a.atUnix.compareTo(b.atUnix));
  final BatterySample latest = sorted.last;
  final double volts = latest.millivolts / 1000.0;
  final double soc = spec.socForVolts(volts).clamp(0.0, 100.0);
  final int now = nowUnix ?? latest.atUnix;

  // Charging → SoC only.
  if (charging == true) {
    return BatteryEstimate(
      socPercent: soc,
      volts: volts,
      charging: charging,
      method: BatteryMethod.charging,
      confidence: BatteryConfidence.none,
      sampleCount: sorted.length,
    );
  }

  // --- Observed drain ---
  final int windowStart =
      now - (config.windowHours * 3600).round();
  final List<BatterySample> window = sorted
      .where((BatterySample s) => s.atUnix >= windowStart)
      .toList(growable: false);

  _Fit? fit;
  double socDelta = 0;
  Duration span = Duration.zero;
  if (window.length >= 2) {
    final int t0 = window.first.atUnix;
    final List<double> xs = <double>[];
    final List<double> ys = <double>[];
    for (final BatterySample s in window) {
      xs.add((s.atUnix - t0) / 3600.0); // hours since window start
      ys.add(spec.socForVolts(s.millivolts / 1000.0).clamp(0.0, 100.0));
    }
    span = Duration(seconds: window.last.atUnix - window.first.atUnix);
    socDelta = (ys.first - ys.last).abs();
    fit = _linearFit(xs, ys);
  }

  final bool windowOk = window.length >= config.minSamples &&
      span.inSeconds >= (config.minSpanHours * 3600).round() &&
      socDelta >= config.minSocDelta;

  // A negative slope means SoC is falling = draining.
  if (windowOk && fit != null && fit.slope < 0) {
    final double drain = -fit.slope; // %/hour, positive
    final double hoursLeft = drain > 0 ? soc / drain : double.infinity;
    final BatteryConfidence conf = _confidenceFor(
      spanHours: span.inSeconds / 3600.0,
      r2: fit.r2,
      socDelta: socDelta,
    );
    return BatteryEstimate(
      socPercent: soc,
      volts: volts,
      charging: charging,
      method: BatteryMethod.observed,
      confidence: conf,
      drainPctPerHour: drain,
      timeToEmpty: hoursLeft.isFinite
          ? Duration(seconds: (hoursLeft * 3600).round())
          : null,
      sampleCount: sorted.length,
      observationSpan: span,
      socDeltaObserved: socDelta,
    );
  }

  // --- Rated cross-check / cold start ---
  if (spec.hasRating) {
    final double remainingMah = soc / 100.0 * spec.capacityMah;
    final double draw = spec.baselineCurrentMa!;
    final double hoursLeft = draw > 0 ? remainingMah / draw : double.infinity;
    // Full-scale drain implied by the nameplate draw (%/hour).
    final double ratedDrain = spec.capacityMah > 0
        ? draw / spec.capacityMah * 100.0
        : 0;
    return BatteryEstimate(
      socPercent: soc,
      volts: volts,
      charging: charging,
      method: BatteryMethod.rated,
      confidence: BatteryConfidence.low,
      drainPctPerHour: ratedDrain > 0 ? ratedDrain : null,
      timeToEmpty: hoursLeft.isFinite
          ? Duration(seconds: (hoursLeft * 3600).round())
          : null,
      sampleCount: sorted.length,
      observationSpan: span,
      socDeltaObserved: socDelta,
    );
  }

  // --- SoC only ---
  return BatteryEstimate(
    socPercent: soc,
    volts: volts,
    charging: charging,
    method: BatteryMethod.none,
    confidence: BatteryConfidence.none,
    sampleCount: sorted.length,
    observationSpan: span,
    socDeltaObserved: socDelta,
  );
}

BatteryConfidence _confidenceFor({
  required double spanHours,
  required double r2,
  required double socDelta,
}) {
  if (spanHours >= 3.0 && r2 >= 0.90 && socDelta >= 5.0) {
    return BatteryConfidence.high;
  }
  if (spanHours >= 1.0 && r2 >= 0.70 && socDelta >= 2.0) {
    return BatteryConfidence.medium;
  }
  return BatteryConfidence.low;
}

class _Fit {
  const _Fit(this.slope, this.intercept, this.r2);
  final double slope;
  final double intercept;
  final double r2;
}

/// Ordinary least-squares line fit. Returns slope/intercept and the
/// coefficient of determination (R²). Degenerate inputs (no variance
/// in x) yield slope 0 and r² 0.
_Fit _linearFit(List<double> xs, List<double> ys) {
  final int n = xs.length;
  double sx = 0, sy = 0, sxx = 0, sxy = 0, syy = 0;
  for (int i = 0; i < n; i++) {
    sx += xs[i];
    sy += ys[i];
    sxx += xs[i] * xs[i];
    sxy += xs[i] * ys[i];
    syy += ys[i] * ys[i];
  }
  final double denom = n * sxx - sx * sx;
  if (denom == 0) return const _Fit(0, 0, 0);
  final double slope = (n * sxy - sx * sy) / denom;
  final double intercept = (sy - slope * sx) / n;
  final double ssTot = syy - sy * sy / n;
  final double ssRes = syy - intercept * sy - slope * sxy;
  final double r2 = ssTot <= 0 ? 0 : (1 - ssRes / ssTot).clamp(0.0, 1.0);
  return _Fit(slope, intercept, r2);
}
