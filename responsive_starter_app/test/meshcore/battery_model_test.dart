// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/battery_model.dart';
import 'package:meshmore_sns_app/meshcore/device_power_specs.dart';

void main() {
  // A deliberately *linear* OCV curve so tests can control SoC
  // exactly: soc% == (volts - 3.0) * 100. 3.00 V → 0 %, 4.00 V → 100 %.
  const DevicePowerSpec linear = DevicePowerSpec(
    id: 'linear',
    label: 'Linear test cell',
    chemistry: 'liion',
    cellCount: 1,
    fullVolts: 4.0,
    emptyVolts: 3.0,
    capacityMah: 0,
    currentMa: <String, double>{},
    ocvCurve: <({double volts, double soc})>[
      (volts: 3.0, soc: 0),
      (volts: 4.0, soc: 100),
    ],
  );

  // Same curve, but with a nameplate rating for the rated branch.
  const DevicePowerSpec linearRated = DevicePowerSpec(
    id: 'linear_rated',
    label: 'Linear rated cell',
    chemistry: 'liion',
    cellCount: 1,
    fullVolts: 4.0,
    emptyVolts: 3.0,
    capacityMah: 3000,
    currentMa: <String, double>{'rx': 100},
    ocvCurve: <({double volts, double soc})>[
      (volts: 3.0, soc: 0),
      (volts: 4.0, soc: 100),
    ],
  );

  const int base = 1700000000;
  int mvForSoc(double soc) => (3000 + soc * 10).round(); // 3.0V + soc%

  test('no samples → empty estimate', () {
    final BatteryEstimate e =
        estimateBattery(samples: const <BatterySample>[], spec: linear);
    expect(e.hasData, isFalse);
    expect(e.method, BatteryMethod.none);
  });

  test('SoC tracks the latest voltage via the OCV curve', () {
    final BatteryEstimate e = estimateBattery(
      samples: <BatterySample>[(atUnix: base, millivolts: mvForSoc(62))],
      spec: linear,
    );
    expect(e.socPercent, closeTo(62, 0.5));
    expect(e.volts, closeTo(3.62, 0.001));
  });

  test('charging → SoC only, runtime paused (even with drain data)', () {
    final List<BatterySample> samples = <BatterySample>[
      for (int h = 0; h <= 4; h++)
        (atUnix: base + h * 3600, millivolts: mvForSoc(80.0 - h * 10)),
    ];
    final BatteryEstimate e = estimateBattery(
      samples: samples,
      spec: linear,
      charging: true,
    );
    expect(e.method, BatteryMethod.charging);
    expect(e.timeToEmpty, isNull);
    expect(e.drainPctPerHour, isNull);
  });

  test('observed drain: 10 %/h over 4 h → ~4 h to empty, high confidence',
      () {
    // SoC 80 → 40 across 4 hours == 10 %/h. Final SoC 40 → 4 h left.
    final List<BatterySample> samples = <BatterySample>[
      for (int h = 0; h <= 4; h++)
        (atUnix: base + h * 3600, millivolts: mvForSoc(80.0 - h * 10)),
    ];
    final BatteryEstimate e = estimateBattery(
      samples: samples,
      spec: linear,
      nowUnix: base + 4 * 3600,
    );
    expect(e.method, BatteryMethod.observed);
    expect(e.drainPctPerHour, closeTo(10, 0.2));
    expect(e.timeToEmpty!.inMinutes, closeTo(240, 10));
    expect(e.confidence, BatteryConfidence.high);
    expect(e.socDeltaObserved, closeTo(40, 0.5));
  });

  test('flat voltage (not draining) → no observed estimate', () {
    final List<BatterySample> samples = <BatterySample>[
      for (int h = 0; h <= 4; h++)
        (atUnix: base + h * 3600, millivolts: mvForSoc(60)),
    ];
    final BatteryEstimate e = estimateBattery(
      samples: samples,
      spec: linear, // no rating → falls through to none
      nowUnix: base + 4 * 3600,
    );
    expect(e.method, BatteryMethod.none);
    expect(e.timeToEmpty, isNull);
  });

  test('rated cold-start: too few samples but spec has a rating', () {
    // One reading at 60 % → 0.6 × 3000 mAh ÷ 100 mA = 18 h.
    final BatteryEstimate e = estimateBattery(
      samples: <BatterySample>[(atUnix: base, millivolts: mvForSoc(60))],
      spec: linearRated,
    );
    expect(e.method, BatteryMethod.rated);
    expect(e.confidence, BatteryConfidence.low);
    expect(e.timeToEmpty!.inHours, closeTo(18, 1));
  });

  test('observed beats rated once enough discharge is seen', () {
    final List<BatterySample> samples = <BatterySample>[
      for (int h = 0; h <= 4; h++)
        (atUnix: base + h * 3600, millivolts: mvForSoc(80.0 - h * 10)),
    ];
    final BatteryEstimate e = estimateBattery(
      samples: samples,
      spec: linearRated, // has a rating, but observed should win
      nowUnix: base + 4 * 3600,
    );
    expect(e.method, BatteryMethod.observed);
  });

  test('stale samples outside the window are ignored', () {
    // A discharge burst 30 h ago, then a single fresh reading. With
    // the default 8 h window the old burst is excluded, so there's not
    // enough recent data for an observed fit.
    final List<BatterySample> samples = <BatterySample>[
      for (int h = 0; h <= 4; h++)
        (atUnix: base + h * 3600, millivolts: mvForSoc(80.0 - h * 10)),
      (atUnix: base + 30 * 3600, millivolts: mvForSoc(35)),
    ];
    final BatteryEstimate e = estimateBattery(
      samples: samples,
      spec: linear,
      nowUnix: base + 30 * 3600,
    );
    expect(e.method, BatteryMethod.none,
        reason: 'only the lone fresh sample is in-window');
    expect(e.socPercent, closeTo(35, 0.5));
  });
}
