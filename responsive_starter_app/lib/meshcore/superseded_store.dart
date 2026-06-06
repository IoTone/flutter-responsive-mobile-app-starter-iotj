// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted set of **superseded** node public keys (hex) — old keys the
/// user reconciled away when a contact returned under a new key (R56).
///
/// The companion protocol has no delete-contact command, so the radio
/// keeps re-syncing the dead contact on every connect. We remember the
/// superseded keys locally and prune them from the fabric on ingest, so a
/// reconciled-away identity never reappears as a confusing duplicate.
abstract final class SupersededStore {
  static const String _kKey = 'mm.superseded.v1';

  static Future<Set<String>> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final List<String>? v = p.getStringList(_kKey);
    return v == null ? <String>{} : v.toSet();
  }

  static Future<void> save(Set<String> pubKeyHexes) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setStringList(_kKey, pubKeyHexes.toList(growable: false));
  }
}
