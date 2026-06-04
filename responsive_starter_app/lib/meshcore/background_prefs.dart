// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted opt-in for the Android background keep-alive foreground
/// service (R17 / U8). Default **on** — the user accepted the
/// persistent notification as the cost of reliable background
/// delivery; users can still turn it off in App settings.
abstract final class BackgroundKeepalivePrefs {
  static const String _kEnabled = 'mm.bg.keepalive';

  static Future<bool> enabled() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? true;
  }

  static Future<void> setEnabled(bool v) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, v);
  }
}

/// Persisted opt-in for the background peer-telemetry poller — the
/// controller politely cycles through synced contacts requesting
/// telemetry so temperature / altitude populate across the fabric
/// without the user tapping each node. Default **on** but
/// airtime-conscious (one request per ~10 s, capped attempts, then
/// quiet). Toggle in App settings.
abstract final class TelemetryPollPrefs {
  static const String _kEnabled = 'mm.telemetryPoll';

  static Future<bool> enabled() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? true;
  }

  static Future<void> setEnabled(bool v) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, v);
  }
}

/// R54 — per-channel opt-in for **message-derived place inference**
/// ("place echoes"): when on for a channel, incoming messages on it are
/// scanned for place references and plotted on the SNS grid. Stored as a
/// JSON map of `channelIdx → bool` of *explicit* overrides; channels
/// with no override fall back to the default, which is **on only for the
/// public channel** (index [publicChannelIndex]) and off elsewhere.
abstract final class PlaceInferencePrefs {
  static const String _kMap = 'mm.placeInfer.channels';
  static const int publicChannelIndex = 0;

  /// The effective default when a channel has no explicit override.
  static bool defaultFor(int channelIdx) => channelIdx == publicChannelIndex;

  /// Load the explicit per-channel overrides.
  static Future<Map<int, bool>> overrides() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString(_kMap);
    if (raw == null || raw.isEmpty) return <int, bool>{};
    try {
      final Map<String, dynamic> m = jsonDecode(raw) as Map<String, dynamic>;
      return <int, bool>{
        for (final MapEntry<String, dynamic> e in m.entries)
          if (int.tryParse(e.key) != null) int.parse(e.key): e.value == true,
      };
    } catch (_) {
      return <int, bool>{};
    }
  }

  static Future<void> save(Map<int, bool> overrides) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(
      _kMap,
      jsonEncode(<String, bool>{
        for (final MapEntry<int, bool> e in overrides.entries)
          '${e.key}': e.value,
      }),
    );
  }
}
