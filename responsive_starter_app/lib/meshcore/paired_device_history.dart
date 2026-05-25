// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'paired_device_store.dart';

/// R41+1 — a paired device the user has connected to in the past,
/// with the wall-clock time of its last successful link. Persisted
/// in a small JSON list under [PairedDeviceHistoryStore].
class PairedDeviceHistoryEntry {
  const PairedDeviceHistoryEntry({
    required this.remoteId,
    required this.name,
    required this.lastUsedUnix,
  });

  final String remoteId;
  final String name;

  /// Wall-clock UNIX seconds of the most recent successful pair to
  /// this device. Drives the "Recently paired" sort order.
  final int lastUsedUnix;

  PairedDevice toPaired() => PairedDevice(remoteId, name);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': remoteId,
        'name': name,
        't': lastUsedUnix,
      };

  static PairedDeviceHistoryEntry? fromJson(Map<String, Object?> j) {
    final Object? id = j['id'];
    if (id is! String || id.isEmpty) return null;
    final Object? n = j['name'];
    final Object? t = j['t'];
    return PairedDeviceHistoryEntry(
      remoteId: id,
      name: n is String ? n : id,
      lastUsedUnix: t is int ? t : 0,
    );
  }
}

/// Rolling list of the most-recently-paired radios.
///
/// Capped at [maxEntries]; older devices drop off the end when a new
/// one is upserted. Stored as a single JSON blob so the persistence
/// stays cheap regardless of how many devices the user has touched.
///
/// **Promotion behaviour:** when [touch] is called for a remoteId
/// already in the history, that entry's [PairedDeviceHistoryEntry.
/// lastUsedUnix] is updated to "now" and it floats to the top of
/// the list — we never duplicate entries by id.
abstract final class PairedDeviceHistoryStore {
  static const String _kKey = 'mm.pairedHistory.v1';
  static const int maxEntries = 5;

  static Future<List<PairedDeviceHistoryEntry>> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString(_kKey);
    if (raw == null || raw.isEmpty) {
      return <PairedDeviceHistoryEntry>[];
    }
    try {
      final List<dynamic> doc = jsonDecode(raw) as List<dynamic>;
      final List<PairedDeviceHistoryEntry> out =
          <PairedDeviceHistoryEntry>[];
      for (final dynamic e in doc) {
        if (e is Map<String, Object?>) {
          final PairedDeviceHistoryEntry? entry =
              PairedDeviceHistoryEntry.fromJson(e);
          if (entry != null) out.add(entry);
        }
      }
      // Defensive sort + cap in case the persisted blob came from an
      // older codepath that didn't enforce ordering.
      out.sort((PairedDeviceHistoryEntry a, PairedDeviceHistoryEntry b) =>
          b.lastUsedUnix.compareTo(a.lastUsedUnix));
      if (out.length > maxEntries) {
        return out.sublist(0, maxEntries);
      }
      return out;
    } catch (_) {
      // Corrupt blob — start fresh rather than crash.
      return <PairedDeviceHistoryEntry>[];
    }
  }

  /// Upsert [remoteId]/[name] as the most-recently-used device.
  /// Existing entries with the same id are promoted (no duplicate);
  /// the list is then capped at [maxEntries] from the head.
  static Future<void> touch(String remoteId, String name) async {
    final List<PairedDeviceHistoryEntry> list = await load();
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    list.removeWhere(
        (PairedDeviceHistoryEntry e) => e.remoteId == remoteId);
    list.insert(
      0,
      PairedDeviceHistoryEntry(
        remoteId: remoteId,
        name: name,
        lastUsedUnix: now,
      ),
    );
    while (list.length > maxEntries) {
      list.removeLast();
    }
    await _persist(list);
  }

  /// Drop a specific entry. No-op when [remoteId] isn't in the list.
  static Future<void> remove(String remoteId) async {
    final List<PairedDeviceHistoryEntry> list = await load();
    final int before = list.length;
    list.removeWhere(
        (PairedDeviceHistoryEntry e) => e.remoteId == remoteId);
    if (list.length == before) return;
    await _persist(list);
  }

  /// Wipe the whole history (used by tests + the master Forget).
  static Future<void> clear() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }

  static Future<void> _persist(
      List<PairedDeviceHistoryEntry> list) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(
        _kKey,
        jsonEncode(<Map<String, Object?>>[
          for (final PairedDeviceHistoryEntry e in list) e.toJson(),
        ]));
  }
}
