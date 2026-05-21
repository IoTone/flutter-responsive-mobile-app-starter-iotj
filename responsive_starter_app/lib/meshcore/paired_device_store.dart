// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:shared_preferences/shared_preferences.dart';

/// The last successfully-connected radio, persisted so the app can
/// auto-reconnect on startup.
class PairedDevice {
  const PairedDevice(this.remoteId, this.name);
  final String remoteId;
  final String name;
}

/// Tiny prefs-backed store for the paired radio (BLE remote id + name).
abstract final class PairedDeviceStore {
  static const String _kId = 'mm.paired.id';
  static const String _kName = 'mm.paired.name';

  static Future<void> save(String remoteId, String name) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(_kId, remoteId);
    await p.setString(_kName, name);
  }

  static Future<PairedDevice?> read() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? id = p.getString(_kId);
    if (id == null || id.isEmpty) return null;
    return PairedDevice(id, p.getString(_kName) ?? id);
  }

  static Future<bool> hasPaired() async => (await read()) != null;

  static Future<void> clear() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kId);
    await p.remove(_kName);
  }
}
