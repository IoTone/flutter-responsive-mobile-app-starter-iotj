// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// R28 — persistent free-text tags attached to discovered nodes.
///
/// Keyed by full pubkey hex (matches the rest of the codebase's
/// node-identity convention). Stored as a single JSON-encoded
/// `Map<pubKeyHex, List<tag>>` blob under one prefs key — the
/// dataset is small (tens of nodes, single-digit tags each) and a
/// JSON round-trip is faster than enumerating dozens of separate
/// string-list keys.
///
/// Tag normalization: trimmed, deduplicated within a node, lowercased
/// only for comparison; user-typed case is preserved on display.
/// Empty tags are rejected at save time.
abstract final class NodeTagsStore {
  static const String _kKey = 'mm.nodeTags.v1';

  static Future<Map<String, List<String>>> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString(_kKey);
    if (raw == null || raw.isEmpty) return <String, List<String>>{};
    try {
      final Map<String, dynamic> doc =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, List<String>> out = <String, List<String>>{};
      doc.forEach((String key, dynamic v) {
        if (v is List) {
          final List<String> tags = <String>[
            for (final dynamic t in v)
              if (t is String && t.trim().isNotEmpty) t,
          ];
          if (tags.isNotEmpty) out[key] = tags;
        }
      });
      return out;
    } catch (_) {
      // Corrupt/older format — start fresh rather than crash.
      return <String, List<String>>{};
    }
  }

  static Future<void> save(Map<String, List<String>> tags) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    // Drop empty lists on save so the blob doesn't accumulate
    // tombstones after every clearTagsFor() call.
    final Map<String, List<String>> trimmed = <String, List<String>>{
      for (final MapEntry<String, List<String>> e in tags.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    };
    await p.setString(_kKey, jsonEncode(trimmed));
  }

  static Future<void> clear() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}
