// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore/meshcore.dart';
import 'package:meshmore_sns_app/meshcore/node_telemetry.dart';

LppEntry _entry(int type, List<double> values) => LppEntry(
      channel: 1,
      type: type,
      values: values,
      rawPayload: Uint8List(0),
    );

NodeTelemetry _from(List<LppEntry> entries) => NodeTelemetry.fromFrame(
      pubKeyPrefixHex: 'aabbccddeeff',
      receivedAt: DateTime(2026),
      entries: entries,
    );

void main() {
  test('extracts temperature / humidity / pressure from LPP entries', () {
    final NodeTelemetry t = _from(<LppEntry>[
      _entry(LppType.temperature, <double>[21.5]),
      _entry(LppType.humidity, <double>[48.0]),
      _entry(LppType.barometer, <double>[1013.2]),
    ]);
    expect(t.temperatureC, 21.5);
    expect(t.humidityPct, 48.0);
    expect(t.pressureHpa, 1013.2);
    expect(t.hasEnvironment, isTrue);
  });

  test('environment fields are null when not reported', () {
    final NodeTelemetry t = _from(<LppEntry>[
      _entry(LppType.gpsLocation, <double>[45.5, -122.7, 60.0]),
    ]);
    expect(t.temperatureC, isNull);
    expect(t.humidityPct, isNull);
    expect(t.pressureHpa, isNull);
    expect(t.hasEnvironment, isFalse);
    // GPS still resolves alongside.
    expect(t.altitudeMeters, 60.0);
    expect(t.hasGpsFix, isTrue);
  });

  test('GPS + environment coexist in one payload', () {
    final NodeTelemetry t = _from(<LppEntry>[
      _entry(LppType.gpsLocation, <double>[45.5, -122.7, 60.0]),
      _entry(LppType.temperature, <double>[18.3]),
    ]);
    expect(t.altitudeMeters, 60.0);
    expect(t.temperatureC, 18.3);
  });

  test('first reading of each type wins', () {
    final NodeTelemetry t = _from(<LppEntry>[
      _entry(LppType.temperature, <double>[20.0]),
      _entry(LppType.temperature, <double>[25.0]),
    ]);
    expect(t.temperatureC, 20.0);
  });
}
