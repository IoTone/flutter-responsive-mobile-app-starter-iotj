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
/// R48 — per-peer reach estimator. When we have a heard RSSI **and**
/// the peer's distance (both have GPS), the answer is much sharper
/// than the coarse [estimatedLoraRangeMeters] anchor: we extrapolate
/// the known measurement out to where the signal would hit the LoRa
/// sensitivity floor.
///
/// Model — log-distance path loss:
///   `reach = distance × 10^((RSSI − sensitivityFloor) / (10·n))`
/// where `n` is the path-loss exponent (2 = free space, 3 = suburban,
/// 4 = dense urban). Default 3.0 — a community-typical mid-value.
///
/// Sensitivity floor is derived from the **local** radio's SF + BW
/// (the only side we know). We assume the peer uses matching params,
/// which is true for any node sharing our channel — and if not, the
/// figure is still indicative.
///
/// Falls back to:
/// - **RSSI-bin** (no distance): coarse buckets so the circle still
///   tells a useful story.
/// - **Radio-tuple anchor** (no RSSI either): the existing
///   [estimatedLoraRangeMeters], same as the self-circle uses.
///
/// Clamped to `[clampMin, clampMax]` so a degenerate input can't
/// render a microscopic dot or a planet-spanning blob.
double estimatedPeerReachMeters({
  required double? rssiDbm,
  required double? distanceMeters,
  required int ourSpreadingFactor,
  required double ourBandwidthKhz,
  required int ourTxPowerDbm,
  double pathLossExponent = 3.0,
  double clampMin = 200.0,
  double clampMax = 20000.0,
}) {
  final double sensitivity = loraSensitivityDbm(
      spreadingFactor: ourSpreadingFactor, bandwidthKhz: ourBandwidthKhz);
  if (rssiDbm != null && distanceMeters != null && distanceMeters > 0) {
    final double headroom = rssiDbm - sensitivity;
    if (headroom <= 0) return distanceMeters.clamp(clampMin, clampMax);
    final double reach = distanceMeters *
        math.pow(10.0, headroom / (10.0 * pathLossExponent)).toDouble();
    return reach.clamp(clampMin, clampMax);
  }
  if (rssiDbm != null) {
    // No distance to anchor the model — coarse RSSI bin keeps the
    // circle vaguely truthful without lying about precision we don't
    // have.
    final double binned;
    if (rssiDbm > -75) {
      binned = 5000.0;
    } else if (rssiDbm > -90) {
      binned = 2500.0;
    } else if (rssiDbm > -105) {
      binned = 1200.0;
    } else if (rssiDbm > -115) {
      binned = 600.0;
    } else {
      binned = 300.0;
    }
    return binned.clamp(clampMin, clampMax);
  }
  return estimatedLoraRangeMeters(
    spreadingFactor: ourSpreadingFactor,
    bandwidthKhz: ourBandwidthKhz,
    txPowerDbm: ourTxPowerDbm,
  ).clamp(clampMin, clampMax);
}

/// LoRa receiver sensitivity (dBm) for a given SF + BW. Reference
/// values at 125 kHz from Semtech's SX1276 datasheet; the BW adjust
/// follows the standard `10·log10(BW/125)` noise-floor scaling.
double loraSensitivityDbm({
  required int spreadingFactor,
  required double bandwidthKhz,
}) {
  // SX1276-class numbers at BW = 125 kHz. Anything outside SF7..SF12
  // is clamped to the closest entry.
  const Map<int, double> base125 = <int, double>{
    7: -123.0,
    8: -126.0,
    9: -129.0,
    10: -132.0,
    11: -134.5,
    12: -137.0,
  };
  final int sf = spreadingFactor.clamp(7, 12);
  final double base = base125[sf] ?? -126.0;
  // Doubling BW adds 3 dB to the noise floor — sensitivity worsens.
  final double bwAdj = 10.0 * math.log(bandwidthKhz / 125.0) / math.ln10;
  return base + bwAdj;
}

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
