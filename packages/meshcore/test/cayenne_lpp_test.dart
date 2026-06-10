// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:meshcore/meshcore.dart';
import 'package:test/test.dart';

Uint8List _hex(String s) {
  final String clean = s.replaceAll(' ', '').toLowerCase();
  final Uint8List out = Uint8List(clean.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

void main() {
  group('CayenneLPP decoder', () {
    test('empty buffer → no entries', () {
      expect(decodeCayenneLpp(Uint8List(0)), isEmpty);
    });

    test('GPS fixture from MyDevices/Adafruit reference docs '
        '(lat=42.3519 lon=-87.9094 alt=10.00 m)', () {
      // Channel 1, type 0x88, lat=0x06765F, lon=0xF2960A, alt=0x0003E8.
      final Uint8List bytes = _hex('01 88 06 76 5F F2 96 0A 00 03 E8');
      final List<LppEntry> entries = decodeCayenneLpp(bytes);
      expect(entries, hasLength(1));
      final LppEntry e = entries.single;
      expect(e.channel, 1);
      expect(e.type, LppType.gpsLocation);
      expect(e.values, hasLength(3));
      expect(e.values[0], closeTo(42.3519, 1e-4));
      expect(e.values[1], closeTo(-87.9094, 1e-4));
      expect(e.values[2], closeTo(10.00, 1e-2));
      final ({double lat, double lon, double altMeters})? gps = e.gps;
      expect(gps, isNotNull);
      expect(gps!.altMeters, closeTo(10.00, 1e-2));
    });

    test('GPS with negative lon + below-sea-level altitude '
        '(exercises s24 two\'s-complement on the last two triplets)', () {
      // Hand-built fixture: lat=10.0000, lon=-20.0000, alt=-50.00 m.
      //   lat =  100000 = 0x0186A0          → 01 86 A0
      //   lon = -200000 = 0x1000000-200000  → FC F2 C0   (s24 two's comp)
      //   alt =   -5000 = 0x1000000-5000    → FF EC 78
      final Uint8List bytes = _hex('01 88 01 86 A0 FC F2 C0 FF EC 78');
      final List<LppEntry> entries = decodeCayenneLpp(bytes);
      expect(entries, hasLength(1));
      final ({double lat, double lon, double altMeters})? gps =
          entries.single.gps;
      expect(gps, isNotNull);
      expect(gps!.lat, closeTo(10.0, 1e-4));
      expect(gps.lon, closeTo(-20.0, 1e-4));
      expect(gps.altMeters, closeTo(-50.0, 1e-2));
    });

    test('multi-entry: temperature + GPS in one payload, in order', () {
      // Channel 3, type 0x67 (temperature), value 0x0110 = 272 / 10 = 27.2 °C.
      // Then the GPS fixture from above.
      final Uint8List bytes = _hex(
          '03 67 01 10 ' // temperature
          '01 88 06 76 5F F2 96 0A 00 03 E8'); // GPS
      final List<LppEntry> entries = decodeCayenneLpp(bytes);
      expect(entries, hasLength(2));
      expect(entries[0].channel, 3);
      expect(entries[0].type, LppType.temperature);
      expect(entries[0].values.single, closeTo(27.2, 1e-3));
      expect(entries[1].type, LppType.gpsLocation);
    });

    test('temperature, signed negative', () {
      // -12.4 °C → -124 → 0xFF84
      final Uint8List bytes = _hex('05 67 FF 84');
      final entries = decodeCayenneLpp(bytes);
      expect(entries.single.values.single, closeTo(-12.4, 1e-3));
    });

    test('humidity is uint8 / 2 (per cent)', () {
      // 0x55 = 85 → 42.5%
      final Uint8List bytes = _hex('02 68 55');
      expect(decodeCayenneLpp(bytes).single.values.single,
          closeTo(42.5, 1e-3));
    });

    test('truncated final entry is dropped, earlier entries returned', () {
      // Good temperature entry + half a GPS entry (channel+type+1 byte).
      final Uint8List bytes = _hex('03 67 01 10 01 88 06');
      final entries = decodeCayenneLpp(bytes);
      expect(entries, hasLength(1));
      expect(entries.single.type, LppType.temperature);
    });

    test('unknown type stops parsing — earlier entries kept', () {
      // Good temperature entry + a type 0xCC (not in the length table).
      final Uint8List bytes = _hex('03 67 01 10 01 CC 00 00');
      final entries = decodeCayenneLpp(bytes);
      expect(entries, hasLength(1));
      expect(entries.single.type, LppType.temperature);
    });

    test('GPS with zero lat/lon/alt (unset) decodes to (0,0,0)', () {
      final Uint8List bytes = _hex('01 88 00 00 00 00 00 00 00 00 00');
      final ({double lat, double lon, double altMeters})? gps =
          decodeCayenneLpp(bytes).single.gps;
      expect(gps, isNotNull);
      expect(gps!.lat, 0.0);
      expect(gps.lon, 0.0);
      expect(gps.altMeters, 0.0);
    });

    test('raw payload is exposed for unknown-divisor consumers', () {
      final Uint8List bytes = _hex('01 88 06 76 5F F2 96 0A 00 03 E8');
      final Uint8List raw = decodeCayenneLpp(bytes).single.rawPayload;
      expect(raw.length, 9);
      expect(raw.first, 0x06);
      expect(raw.last, 0xE8);
    });

    test(
        'T1000-E self-telemetry wire order: voltage → GPS → luminosity → '
        'temperature (regression: voltage 0x74 used to stall the decoder '
        'at entry #1, dropping ALL env telemetry behind it)', () {
      // Mirrors companion_radio MyMesh.cpp: addVoltage(ch1, battV) first,
      // then T1000SensorManager::querySensors → addGPS, addLuminosity,
      // addTemperature — all on TELEM_CHANNEL_SELF (1).
      //   voltage 4.12 V        → 01 74 01 9C   (412 / 100)
      //   gps 10.0000,-20.0000,-50.00 → 01 88 01 86 A0 FC F2 C0 FF EC 78
      //   luminosity 62         → 01 65 00 3E   (T1000 reports 0-100 scale)
      //   temperature 27.9 °C   → 01 67 01 17   (279 / 10)
      final Uint8List bytes = _hex(
          '01 74 01 9C  01 88 01 86 A0 FC F2 C0 FF EC 78  '
          '01 65 00 3E  01 67 01 17');
      final List<LppEntry> entries = decodeCayenneLpp(bytes);
      expect(entries, hasLength(4),
          reason: 'all four entries must decode — nothing dropped');
      expect(entries[0].type, LppType.voltage);
      expect(entries[0].values.single, closeTo(4.12, 1e-9));
      expect(entries[1].type, LppType.gpsLocation);
      expect(entries[1].gps!.lat, closeTo(10.0, 1e-4));
      expect(entries[2].type, LppType.illuminance);
      expect(entries[2].values.single, 62.0);
      expect(entries[3].type, LppType.temperature);
      expect(entries[3].values.single, closeTo(27.9, 1e-9));
      expect(entries.every((LppEntry e) => e.channel == 1), isTrue,
          reason: 'TELEM_CHANNEL_SELF = 1 throughout');
    });

    test('extended types decode with the ElectronicCats divisors', () {
      // current 0.250 A → 01 75 00 FA; altitude -120 m → 01 79 FF 88;
      // percentage 87 → 01 78 57; distance 3.5 m → 01 82 00 00 0D AC.
      final Uint8List bytes =
          _hex('01 75 00 FA  01 79 FF 88  01 78 57  01 82 00 00 0D AC');
      final List<LppEntry> entries = decodeCayenneLpp(bytes);
      expect(entries, hasLength(4));
      expect(entries[0].values.single, closeTo(0.250, 1e-9)); // current
      expect(entries[1].values.single, -120.0); // altitude (s16)
      expect(entries[2].values.single, 87.0); // percentage
      expect(entries[3].values.single, closeTo(3.5, 1e-9)); // distance
    });
  });
}
