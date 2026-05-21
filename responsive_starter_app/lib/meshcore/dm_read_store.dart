// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-peer **last-seen** timestamps for DM unread tracking.
/// Stores `pubkeyHex → lastReadAt (unix millis)`. Inbound DMs whose
/// timestamp is *after* the peer's lastReadAt are counted as unread.
///
/// Persisted as a single JSON map in shared_preferences under the key
/// `mm.dmRead.v1`. The reads are async (file I/O); writes are
/// fire-and-forget so the UI never blocks on marking a thread read.
class DmReadStore {
  DmReadStore({Map<String, int>? seed})
      : _data = <String, int>{...?seed};

  static const String _key = 'mm.dmRead.v1';

  final Map<String, int> _data;

  /// `true` once [load] has resolved at least once.
  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> j =
            jsonDecode(raw) as Map<String, dynamic>;
        _data.clear();
        for (final MapEntry<String, dynamic> e in j.entries) {
          final int v = (e.value as num).toInt();
          _data[e.key] = v;
        }
      } catch (_) {
        // Corrupt blob → start fresh; not worth surfacing.
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_data));
  }

  /// Returns the lastReadAt millis for [pubKeyHex] or `0` if never read.
  int lastReadAtMs(String pubKeyHex) => _data[pubKeyHex] ?? 0;

  /// Mark the thread with [pubKeyHex] as read up to [at] (defaults now).
  /// Idempotent — if the new value is older than the stored one we
  /// keep the newer (so a stale "read" never un-reads later messages).
  Future<void> markRead(String pubKeyHex, {DateTime? at}) async {
    final int t = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final int cur = _data[pubKeyHex] ?? 0;
    if (t <= cur) return;
    _data[pubKeyHex] = t;
    await _persist();
  }

  /// Test helper.
  Map<String, int> snapshot() => Map<String, int>.unmodifiable(_data);
}
