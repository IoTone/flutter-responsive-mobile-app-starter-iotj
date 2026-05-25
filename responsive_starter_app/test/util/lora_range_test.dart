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
}
