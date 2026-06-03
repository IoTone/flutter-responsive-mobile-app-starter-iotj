// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:meshcore/meshcore.dart';

/// Telemetry payload received for one node (self or peer) — the
/// digested form of a `PUSH_CODE_TELEMETRY_RESPONSE` (0x8B) plus the
/// CayenneLPP payload that came with it.
///
/// Only fields we actually decode today are surfaced; the raw LPP
/// entries are kept so callers can pull additional sensor values
/// (temperature, humidity, etc.) without re-decoding.
class NodeTelemetry {
  const NodeTelemetry({
    required this.pubKeyPrefixHex,
    required this.receivedAt,
    required this.entries,
    this.latitude,
    this.longitude,
    this.altitudeMeters,
    this.temperatureC,
    this.humidityPct,
    this.pressureHpa,
  });

  /// 12-char lower-case hex of the 6-byte pubkey prefix that the
  /// device echoed back in the 0x8B push. Matches the prefix
  /// convention used elsewhere in the controller for peer addressing.
  final String pubKeyPrefixHex;

  /// Wall-clock when the response landed on the BLE link.
  final DateTime receivedAt;

  /// All LPP entries decoded from this telemetry payload, in order.
  /// Empty if the device had nothing to report.
  final List<LppEntry> entries;

  /// Decoded GPS triplet. Null when no GPS entry was present, or when
  /// the entry decoded to the canonical (0, 0, 0) "no fix yet"
  /// sentinel — telemetry from a chip without a GPS fix produces an
  /// all-zero GPS triplet that we should *not* misread as
  /// "located at Null Island at sea level."
  final double? latitude;
  final double? longitude;
  final double? altitudeMeters;

  /// Environment readings, when the node carries the sensors (e.g. a
  /// BME280 — the T1000-E has one onboard). Decoded from the
  /// CayenneLPP temperature (0x67), humidity (0x68), and barometer
  /// (0x73) entries. Null when the node didn't report that sensor.
  /// Note: sensors near the electronics (T1000-E) read a few degrees
  /// warm — treat temperature as indicative.
  final double? temperatureC;
  final double? humidityPct;
  final double? pressureHpa;

  /// True iff the device reported a non-zero GPS fix.
  bool get hasGpsFix => latitude != null && longitude != null;

  /// True iff any environment sensor value was reported.
  bool get hasEnvironment =>
      temperatureC != null || humidityPct != null || pressureHpa != null;

  /// Build a [NodeTelemetry] from a freshly-arrived telemetry frame.
  /// Pulls the first GPS entry it finds (any channel) and treats
  /// (0, 0, 0) as "no fix" rather than a real location.
  factory NodeTelemetry.fromFrame({
    required String pubKeyPrefixHex,
    required DateTime receivedAt,
    required List<LppEntry> entries,
  }) {
    double? lat;
    double? lon;
    double? alt;
    double? temp;
    double? humidity;
    double? pressure;
    for (final LppEntry e in entries) {
      // GPS — first non-(0,0,0) triplet wins.
      final ({double lat, double lon, double altMeters})? gps = e.gps;
      if (gps != null &&
          lat == null &&
          !(gps.lat.abs() < 1e-9 &&
              gps.lon.abs() < 1e-9 &&
              gps.altMeters.abs() < 1e-9)) {
        lat = gps.lat;
        lon = gps.lon;
        alt = gps.altMeters;
      }
      // Environment — first reading of each type wins. Values are
      // already in physical units (°C, %, hPa).
      if (e.values.isNotEmpty) {
        if (e.type == LppType.temperature) {
          temp ??= e.values[0];
        } else if (e.type == LppType.humidity) {
          humidity ??= e.values[0];
        } else if (e.type == LppType.barometer) {
          pressure ??= e.values[0];
        }
      }
    }
    return NodeTelemetry(
      pubKeyPrefixHex: pubKeyPrefixHex,
      receivedAt: receivedAt,
      entries: entries,
      latitude: lat,
      longitude: lon,
      altitudeMeters: alt,
      temperatureC: temp,
      humidityPct: humidity,
      pressureHpa: pressure,
    );
  }
}
