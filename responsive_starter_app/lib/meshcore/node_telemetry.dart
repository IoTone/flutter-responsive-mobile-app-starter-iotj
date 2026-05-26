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

  /// True iff the device reported a non-zero GPS fix.
  bool get hasGpsFix => latitude != null && longitude != null;

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
    for (final LppEntry e in entries) {
      final ({double lat, double lon, double altMeters})? gps = e.gps;
      if (gps == null) continue;
      // All-zero triplet = unset / no fix.
      if (gps.lat.abs() < 1e-9 &&
          gps.lon.abs() < 1e-9 &&
          gps.altMeters.abs() < 1e-9) {
        continue;
      }
      lat = gps.lat;
      lon = gps.lon;
      alt = gps.altMeters;
      break;
    }
    return NodeTelemetry(
      pubKeyPrefixHex: pubKeyPrefixHex,
      receivedAt: receivedAt,
      entries: entries,
      latitude: lat,
      longitude: lon,
      altitudeMeters: alt,
    );
  }
}
