// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/util/lora_range.dart';

void main() {
  group('R25+1 estimatedLoraRangeMeters', () {
    test('SF7 / 125 kHz / 14 dBm anchor → ~1.5 km', () {
      final double r = estimatedLoraRangeMeters(
        spreadingFactor: 7,
        bandwidthKhz: 125.0,
        txPowerDbm: 14,
      );
      expect(r, closeTo(1500.0, 1.0));
    });

    test('US canonical (SF7 / 62.5 / 22 dBm) is a few km', () {
      final double r = estimatedLoraRangeMeters(
        spreadingFactor: 7,
        bandwidthKhz: 62.5,
        txPowerDbm: 22,
      );
      // Plausible urban range for the canonical US tuple.
      expect(r, greaterThan(3000.0));
      expect(r, lessThan(8000.0));
    });

    test('SF12 narrow-band reaches an order of magnitude further', () {
      final double low = estimatedLoraRangeMeters(
        spreadingFactor: 7,
        bandwidthKhz: 125.0,
        txPowerDbm: 14,
      );
      final double high = estimatedLoraRangeMeters(
        spreadingFactor: 12,
        bandwidthKhz: 62.5,
        txPowerDbm: 22,
      );
      expect(high / low, greaterThan(10.0),
          reason: 'SF12/62.5 should comfortably exceed SF7/125 reach');
    });

    test('range scales monotonically with TX power', () {
      double prev = 0;
      for (final int tx in <int>[10, 14, 17, 20, 22, 25]) {
        final double r = estimatedLoraRangeMeters(
          spreadingFactor: 7,
          bandwidthKhz: 125.0,
          txPowerDbm: tx,
        );
        expect(r, greaterThan(prev));
        prev = r;
      }
    });
  });

  group('R48 loraSensitivityDbm', () {
    test('SF7 / 125 kHz → ~-123 dBm (SX1276 datasheet)', () {
      expect(
          loraSensitivityDbm(spreadingFactor: 7, bandwidthKhz: 125.0),
          closeTo(-123.0, 0.5));
    });

    test('SF12 / 125 kHz → ~-137 dBm (datasheet)', () {
      expect(
          loraSensitivityDbm(spreadingFactor: 12, bandwidthKhz: 125.0),
          closeTo(-137.0, 0.5));
    });

    test('narrower BW (62.5 kHz) → ~3 dB better sensitivity', () {
      final double s125 =
          loraSensitivityDbm(spreadingFactor: 7, bandwidthKhz: 125.0);
      final double s62 =
          loraSensitivityDbm(spreadingFactor: 7, bandwidthKhz: 62.5);
      expect(s62 - s125, closeTo(-3.0, 0.2));
    });
  });

  group('R48 estimatedPeerReachMeters', () {
    test('with RSSI + distance — strong signal at short distance '
        'extrapolates to a large reach', () {
      // Hearing -70 dBm at 500 m on SF7/125 → ~50 dB headroom over
      // -123 dBm floor. With n=3, reach ≈ 500 × 10^(50/30) ≈ 500 × 46
      // ≈ 23 km (then clamped to 20 km).
      final double r = estimatedPeerReachMeters(
        rssiDbm: -70,
        distanceMeters: 500,
        ourSpreadingFactor: 7,
        ourBandwidthKhz: 125.0,
        ourTxPowerDbm: 14,
      );
      expect(r, closeTo(20000.0, 1.0)); // clamp ceiling
    });

    test('RSSI right at the sensitivity floor → reach == distance '
        '(peer is barely hearable; no headroom to extrapolate)', () {
      final double r = estimatedPeerReachMeters(
        rssiDbm: -123,
        distanceMeters: 2000,
        ourSpreadingFactor: 7,
        ourBandwidthKhz: 125.0,
        ourTxPowerDbm: 14,
      );
      expect(r, closeTo(2000.0, 1.0));
    });

    test('RSSI below the floor → clamped to current distance (we '
        'should not be hearing them at all; trust the lower bound)',
        () {
      final double r = estimatedPeerReachMeters(
        rssiDbm: -130,
        distanceMeters: 1500,
        ourSpreadingFactor: 7,
        ourBandwidthKhz: 125.0,
        ourTxPowerDbm: 14,
      );
      expect(r, closeTo(1500.0, 1.0));
    });

    test('mid-range RSSI + distance produces a sensible mid reach', () {
      // -100 dBm @ 1 km, SF7/125 → headroom 23 dB, n=3 → 1000 × 10^(23/30)
      // ≈ 1000 × 5.86 ≈ 5860 m.
      final double r = estimatedPeerReachMeters(
        rssiDbm: -100,
        distanceMeters: 1000,
        ourSpreadingFactor: 7,
        ourBandwidthKhz: 125.0,
        ourTxPowerDbm: 14,
      );
      expect(r, inInclusiveRange(4500, 8000));
    });

    test('no distance, only RSSI → coarse RSSI-bin fallback', () {
      final double weak = estimatedPeerReachMeters(
        rssiDbm: -118,
        distanceMeters: null,
        ourSpreadingFactor: 7,
        ourBandwidthKhz: 125.0,
        ourTxPowerDbm: 14,
      );
      final double strong = estimatedPeerReachMeters(
        rssiDbm: -70,
        distanceMeters: null,
        ourSpreadingFactor: 7,
        ourBandwidthKhz: 125.0,
        ourTxPowerDbm: 14,
      );
      expect(weak, lessThan(strong));
      expect(weak, lessThan(1000));
      expect(strong, greaterThan(3000));
    });

    test('no RSSI and no distance → coarse radio-tuple anchor '
        '(same as estimatedLoraRangeMeters)', () {
      final double anchor = estimatedLoraRangeMeters(
        spreadingFactor: 7,
        bandwidthKhz: 125.0,
        txPowerDbm: 14,
      );
      final double r = estimatedPeerReachMeters(
        rssiDbm: null,
        distanceMeters: null,
        ourSpreadingFactor: 7,
        ourBandwidthKhz: 125.0,
        ourTxPowerDbm: 14,
      );
      expect(r, closeTo(anchor, 1.0));
    });

    test('clamps to ceiling and floor', () {
      // Crazy headroom — should clamp to ceiling.
      expect(
          estimatedPeerReachMeters(
            rssiDbm: -30,
            distanceMeters: 100,
            ourSpreadingFactor: 12,
            ourBandwidthKhz: 62.5,
            ourTxPowerDbm: 22,
          ),
          equals(20000.0));
      // No data + ridiculous radio that would otherwise estimate
      // below the floor — clamped up.
      expect(
          estimatedPeerReachMeters(
            rssiDbm: -120,
            distanceMeters: 10,
            ourSpreadingFactor: 7,
            ourBandwidthKhz: 500.0,
            ourTxPowerDbm: 5,
            clampMin: 200.0,
          ),
          greaterThanOrEqualTo(200.0));
    });
  });
}
