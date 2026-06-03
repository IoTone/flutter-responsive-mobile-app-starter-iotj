// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
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
