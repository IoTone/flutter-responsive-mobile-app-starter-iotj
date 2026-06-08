// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../meshcore/chat_message.dart';
import 'meshbook.dart';

/// Persistence for Meshbook (MBk) P3. Holds, **per channel**, a rolling
/// **last-24-hours** window of contributing channel messages (id/time/text
/// only) and runs the pure [MbkEngine] over them on demand. This is its own
/// copy — independent of the volatile chat buffer — so it survives restarts
/// and a trimmed history.
///
/// The window is rolling (not calendar-day): on every ingest/build/seed we
/// prune anything older than 24h. That's deliberate — collection doesn't run
/// in the background, so a calendar-day reset at local midnight would wipe
/// the evening's activity and leave nothing to show when the app is reopened
/// in the morning. A rolling 24h keeps last night visible. The hourly
/// histogram still buckets by local hour-of-day (00..23), so it reads as a
/// 24-hour clock.
///
/// Ingestion is **idempotent by message id**, so seeding from history and
/// live ingestion can both run without double counting.
class MeshbookStore {
  static const String _kKey = 'mm.meshbook.v1';

  /// Rolling retention window.
  static const int _windowMs = 24 * 60 * 60 * 1000;

  /// Cap per channel so a very busy channel can't bloat storage.
  static const int _perChannelCap = 800;

  final Map<int, List<_Msg>> _ch = <int, List<_Msg>>{};
  final Set<String> _ids = <String>{}; // global id dedup
  final Set<int> _seeded = <int>{};

  /// Drop everything older than the rolling 24h window.
  void _prune(DateTime now) {
    final int lo = now.millisecondsSinceEpoch - _windowMs;
    final List<int> emptied = <int>[];
    _ch.forEach((int ch, List<_Msg> list) {
      list.removeWhere((_Msg m) {
        final bool stale = m.atMs < lo;
        if (stale) _ids.remove(m.id);
        return stale;
      });
      if (list.isEmpty) emptied.add(ch);
    });
    for (final int ch in emptied) {
      _ch.remove(ch);
    }
  }

  /// Add one channel message. Returns true if it was newly counted.
  bool ingest(ChatMessage m, {DateTime? now}) {
    if (m.channelIdx < 0) return false; // channel only — never DMs
    final DateTime n = now ?? DateTime.now();
    _prune(n);
    final int atMs = m.at.millisecondsSinceEpoch;
    final int lo = n.millisecondsSinceEpoch - _windowMs;
    if (atMs < lo || m.at.isAfter(n)) return false; // outside the 24h window
    if (!_ids.add(m.id)) return false; // already counted
    final List<_Msg> list = _ch.putIfAbsent(m.channelIdx, () => <_Msg>[]);
    list.add(_Msg(m.id, atMs, m.text));
    if (list.length > _perChannelCap) {
      _ids.remove(list.removeAt(0).id);
    }
    return true;
  }

  /// One-time per-session seed from message history (idempotent via id
  /// dedup). `_seeded` is in-memory, so this re-runs on each app launch —
  /// which is what backfills the last 24h when the app is reopened.
  void seed(int channelIdx, Iterable<ChatMessage> history, {DateTime? now}) {
    final DateTime n = now ?? DateTime.now();
    _prune(n);
    if (_seeded.contains(channelIdx)) return;
    for (final ChatMessage m in history) {
      if (m.channelIdx == channelIdx) ingest(m, now: n);
    }
    _seeded.add(channelIdx);
  }

  /// Analyse the rolling 24h window for [channelIdx].
  MbkDay build(int channelIdx, {DateTime? now, int topN = 10}) {
    final DateTime n = now ?? DateTime.now();
    _prune(n);
    final List<_Msg> list = _ch[channelIdx] ?? const <_Msg>[];
    return MbkEngine.analyse(
      list.map((_Msg x) => ChatMessage(
            id: x.id,
            channelIdx: channelIdx,
            text: x.text,
            outgoing: false,
            at: DateTime.fromMillisecondsSinceEpoch(x.atMs),
          )),
      channelIdx: channelIdx,
      dayStart: n.subtract(const Duration(milliseconds: _windowMs)),
      now: n,
      topN: topN,
    );
  }

  bool channelHasData(int channelIdx) =>
      _ch[channelIdx]?.isNotEmpty ?? false;

  /// Forget a channel's window (the user clearing it). Re-seeds next build.
  void clearChannel(int channelIdx) {
    final List<_Msg>? list = _ch.remove(channelIdx);
    if (list != null) {
      for (final _Msg m in list) {
        _ids.remove(m.id);
      }
    }
    _seeded.remove(channelIdx);
  }

  void clearAll() {
    _ch.clear();
    _ids.clear();
    _seeded.clear();
  }

  // --- persistence ----------------------------------------------------

  Future<void> save() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final Map<String, Object?> j = <String, Object?>{
      'ch': <String, Object?>{
        for (final MapEntry<int, List<_Msg>> e in _ch.entries)
          '${e.key}': <List<Object>>[
            for (final _Msg m in e.value) <Object>[m.id, m.atMs, m.text],
          ],
      },
    };
    await p.setString(_kKey, jsonEncode(j));
  }

  Future<void> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString(_kKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> j = jsonDecode(raw) as Map<String, dynamic>;
      // The first build/ingest prunes anything now outside the 24h window.
      final Map<String, dynamic>? ch = j['ch'] as Map<String, dynamic>?;
      if (ch != null) {
        ch.forEach((String k, dynamic v) {
          final int? idx = int.tryParse(k);
          if (idx == null) return;
          final List<_Msg> list = <_Msg>[];
          for (final dynamic row in v as List<dynamic>) {
            final List<dynamic> a = row as List<dynamic>;
            final String id = a[0] as String;
            if (_ids.add(id)) {
              list.add(_Msg(id, (a[1] as num).toInt(), a[2] as String));
            }
          }
          _ch[idx] = list;
        });
      }
    } catch (_) {
      // Corrupt blob — start fresh.
      _ch.clear();
      _ids.clear();
    }
  }

  Future<void> clearPersisted() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}

class _Msg {
  _Msg(this.id, this.atMs, this.text);
  final String id;
  final int atMs;
  final String text;
}
