// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/device_power_specs.dart';

void main() {
  group('DevicePowerSpec.socForVolts (OCV interpolation)', () {
    final DevicePowerSpec g = DevicePowerSpec.genericLiion;

    test('clamps below empty and above full', () {
      expect(g.socForVolts(3.0), 0);
      expect(g.socForVolts(2.0), 0);
      expect(g.socForVolts(4.2), 100);
      expect(g.socForVolts(4.5), 100);
    });

    test('hits curve breakpoints exactly', () {
      expect(g.socForVolts(3.82), closeTo(50, 0.001));
      expect(g.socForVolts(4.08), closeTo(90, 0.001));
    });

    test('interpolates linearly between points', () {
      // Midpoint between (3.92→70) and (3.98→80) is 3.95 → 75.
      expect(g.socForVolts(3.95), closeTo(75, 0.001));
    });

    test('is monotonic non-decreasing across the range', () {
      double prev = -1;
      for (double v = 3.0; v <= 4.3; v += 0.01) {
        final double soc = g.socForVolts(v);
        expect(soc, greaterThanOrEqualTo(prev - 1e-9));
        prev = soc;
      }
    });
  });

  group('DevicePowerSpecs.parse + resolve', () {
    const String json = '''
    {
      "version": 1,
      "default": {
        "id": "generic", "label": "Generic", "chemistry": "liion",
        "cellCount": 1, "fullVolts": 4.2, "emptyVolts": 3.3,
        "capacityMah": 0, "currentMa": {},
        "ocvCurve": [[3.3,0],[3.8,50],[4.2,100]]
      },
      "specs": [
        {
          "id": "heltec", "label": "Heltec V3",
          "match": {"manufacturerContains": ["heltec"], "firmwareContains": []},
          "chemistry": "liion", "cellCount": 1,
          "fullVolts": 4.2, "emptyVolts": 3.3, "capacityMah": 0,
          "currentMa": {"idle": 38, "rx": 48, "tx": 120}
        },
        {
          "id": "tbeam", "label": "T-Beam",
          "match": {"manufacturerContains": ["t-beam","tbeam"], "firmwareContains": []},
          "chemistry": "liion", "cellCount": 1,
          "fullVolts": 4.2, "emptyVolts": 3.3, "capacityMah": 3000,
          "currentMa": {"rx": 95}
        }
      ]
    }
    ''';

    test('matches a device by manufacturer substring (case-insensitive)',
        () {
      final DevicePowerSpecs s = DevicePowerSpecs.parse(json);
      expect(s.resolve(manufacturer: 'Heltec Automation').id, 'heltec');
      expect(s.resolve(manufacturer: 'LILYGO T-Beam').id, 'tbeam');
    });

    test('falls back to the generic default when nothing matches', () {
      final DevicePowerSpecs s = DevicePowerSpecs.parse(json);
      final DevicePowerSpec r = s.resolve(manufacturer: 'NoSuchVendor');
      expect(r.isGeneric, isTrue);
      expect(r.id, 'generic');
    });

    test('null / empty inputs resolve to the fallback', () {
      final DevicePowerSpecs s = DevicePowerSpecs.parse(json);
      expect(s.resolve().isGeneric, isTrue);
      expect(s.resolve(manufacturer: '').isGeneric, isTrue);
    });

    test('specs inherit the default OCV curve when they omit one', () {
      final DevicePowerSpecs s = DevicePowerSpecs.parse(json);
      final DevicePowerSpec heltec = s.resolve(manufacturer: 'heltec');
      // Inherited 3-point curve: 3.8 → 50.
      expect(heltec.socForVolts(3.8), closeTo(50, 0.001));
    });

    test('hasRating only when capacity AND baseline current are known', () {
      final DevicePowerSpecs s = DevicePowerSpecs.parse(json);
      expect(s.resolve(manufacturer: 'heltec').hasRating, isFalse,
          reason: 'capacity 0 → no rated estimate');
      expect(s.resolve(manufacturer: 'tbeam').hasRating, isTrue);
      expect(s.resolve(manufacturer: 'tbeam').baselineCurrentMa, 95);
    });

    test('malformed JSON returns the builtin table', () {
      final DevicePowerSpecs s = DevicePowerSpecs.parse('{ not json');
      expect(s.entries, isEmpty);
      expect(s.fallback.isGeneric, isTrue);
    });
  });
}
