// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

/// R25+1 — coarse LoRa range estimator used to draw "approximate
/// signal radius" circles on the equal-grid view. Returns the
/// expected one-way reach in metres for the given radio tuple in a
/// **typical urban environment** (single-family + small commercial,
/// no dense skyscraper canyon).
///
/// This is deliberately a heuristic, not link-budget physics — we
/// have no antenna gain, no terrain, no precise sensitivity figures
/// from the firmware. The model walks down from a calibration anchor
/// (SF7 / 125 kHz / 14 dBm ≈ 1.5 km urban — community-typical for a
/// T1000-E) by three independent factors:
///
///   - **SF** — each spreading-factor bump adds ~3 dB of processing
///     gain. The relationship is roughly multiplicative on range.
///   - **BW** — halving bandwidth lowers the noise floor by 3 dB,
///     so range scales with √(refBw / bw).
///   - **TX power** — every 6 dB doubles theoretical range in
///     free space; we apply this directly.
///
/// Even with these knobs the answer is order-of-magnitude. Treat the
/// drawn circles as "where the node might be reachable", not as a
/// guarantee.
double estimatedLoraRangeMeters({
  required int spreadingFactor,
  required double bandwidthKhz,
  required int txPowerDbm,
}) {
  // Anchor — typical urban LoRa range at the reference tuple. Tuned
  // against community field reports for T1000-E SF7 BW125 14 dBm.
  const double baseRangeM = 1500.0;
  const int refSf = 7;
  const double refBwKhz = 125.0;
  const int refTxDbm = 14;

  // Each SF step roughly multiplies range by 2^0.5 (≈40 % per step)
  // in practice, much less than the link-budget number suggests
  // because urban multipath kills the theoretical processing gain.
  final double sfFactor =
      math.pow(2.0, (spreadingFactor - refSf) * 0.5).toDouble();

  // Halving BW yields √2× range; widening cuts it by the same.
  final double bwFactor = math.sqrt(refBwKhz / bandwidthKhz);

  // Free-space rule: 6 dB doubles range. Each dB → 10^(1/20).
  final double txFactor =
      math.pow(10.0, (txPowerDbm - refTxDbm) / 20.0).toDouble();

  return baseRangeM * sfFactor * bwFactor * txFactor;
}
