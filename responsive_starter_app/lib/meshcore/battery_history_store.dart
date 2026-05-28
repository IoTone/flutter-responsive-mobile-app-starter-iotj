// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'battery_model.dart' show BatterySample;

/// Persistent battery-voltage history, keyed per device.
///
/// The companion protocol only gives us pack voltage (mV); to
/// estimate runtime we need that voltage *over time*, surviving app
/// restarts. We poll every 60 s but decimate to one stored sample
/// every few minutes so a multi-hour/day span fits in a bounded
/// store — long enough for the drain regression, cheap enough for
/// shared_preferences.
///
/// Mirrors [CoverageStore]: a JSON blob in shared_preferences,
/// validated on load, with corrupt entries silently dropped.
/// Keyed by the device's 12-hex-char pubkey prefix (pub6) so a user
/// who swaps devices keeps a separate history for each.
class BatteryHistoryStore {
  BatteryHistoryStore._();

  static const String _kKey = 'mm.battery_history.v1';

  /// Minimum spacing between *stored* samples. The poll is 60 s; we
  /// keep one reading per ~3 min so a day of history is ~480 samples.
  static const int minIntervalSec = 180;

  /// Per-device cap. 500 × 3 min ≈ 25 h of history; older samples
  /// drop off the front. Plenty for the 8 h estimator window with
  /// headroom for gaps.
  static const int maxSamplesPerDevice = 500;

  /// Cap on distinct devices retained (drops the device with the
  /// oldest newest-sample when exceeded).
  static const int maxDevices = 8;

  /// Plausible single-cell pack voltage window (mV). Readings outside
  /// are treated as decode garbage and dropped on load.
  static const int _minMv = 2000;
  static const int _maxMv = 5000;

  static Future<Map<String, List<BatterySample>>> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString(_kKey);
    if (raw == null || raw.isEmpty) {
      return <String, List<BatterySample>>{};
    }
    try {
      final Map<String, dynamic> doc =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, List<BatterySample>> out =
          <String, List<BatterySample>>{};
      doc.forEach((String pub, dynamic v) {
        if (v is! List) return;
        final List<BatterySample> samples = <BatterySample>[];
        for (final dynamic e in v) {
          if (e is! List || e.length < 2) continue;
          final dynamic t = e[0];
          final dynamic mv = e[1];
          if (t is! num || mv is! num) continue;
          final int mvi = mv.toInt();
          if (mvi < _minMv || mvi > _maxMv) continue;
          samples.add((atUnix: t.toInt(), millivolts: mvi));
        }
        if (samples.isNotEmpty) {
          samples.sort((a, b) => a.atUnix.compareTo(b.atUnix));
          out[pub] = samples;
        }
      });
      return out;
    } catch (_) {
      return <String, List<BatterySample>>{};
    }
  }

  static Future<void> save(
      Map<String, List<BatterySample>> history) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final Map<String, List<List<int>>> doc = <String, List<List<int>>>{};
    history.forEach((String pub, List<BatterySample> samples) {
      doc[pub] = <List<int>>[
        for (final BatterySample s in samples)
          <int>[s.atUnix, s.millivolts],
      ];
    });
    await p.setString(_kKey, jsonEncode(doc));
  }

  static Future<void> clear() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}
