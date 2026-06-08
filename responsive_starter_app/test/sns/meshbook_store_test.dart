// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshmore_sns_app/meshcore/chat_message.dart';
import 'package:meshmore_sns_app/sns/meshbook_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  final DateTime t = DateTime(2026, 6, 7, 12); // a fixed "now"

  ChatMessage cm(String id, String text, int ch, DateTime at) => ChatMessage(
        id: id,
        channelIdx: ch,
        text: text,
        outgoing: false,
        at: at,
      );

  test('ingest: dedups by id, channel-only, last-24h; per-channel build',
      () {
    final MeshbookStore s = MeshbookStore();
    expect(s.ingest(cm('1', 'A: hi', 0, DateTime(2026, 6, 7, 9)), now: t),
        isTrue);
    expect(s.ingest(cm('1', 'A: hi', 0, DateTime(2026, 6, 7, 9)), now: t),
        isFalse); // duplicate id
    expect(s.ingest(cm('2', 'B: dm', -1, DateTime(2026, 6, 7, 9)), now: t),
        isFalse); // a DM
    expect(s.ingest(cm('3', 'C: old', 0, DateTime(2026, 6, 6, 9)), now: t),
        isFalse); // >24h ago (27h before t)
    expect(s.ingest(cm('4', 'X: hey', 1, DateTime(2026, 6, 7, 10)), now: t),
        isTrue); // channel 1

    expect(s.build(0, now: t).total, 1);
    expect(s.build(0, now: t).voices, 1);
    expect(s.build(1, now: t).total, 1); // stored separately per channel
    expect(s.channelHasData(0), isTrue);
    expect(s.channelHasData(2), isFalse);
  });

  test('messages roll out of the 24h window (not at calendar midnight)', () {
    final MeshbookStore s = MeshbookStore();
    s.ingest(cm('1', 'A: hi', 0, DateTime(2026, 6, 7, 9)), now: t);
    expect(s.build(0, now: t).total, 1);
    // Past local midnight but still inside 24h — survives (the morning case).
    expect(s.build(0, now: DateTime(2026, 6, 8, 8)).total, 1); // 23h later
    // Older than 24h — dropped.
    expect(s.build(0, now: DateTime(2026, 6, 8, 10)).total, 0); // 25h later
  });

  test('clearChannel empties it (and re-ingest works)', () {
    final MeshbookStore s = MeshbookStore();
    s.ingest(cm('1', 'A: hi', 0, DateTime(2026, 6, 7, 9)), now: t);
    s.clearChannel(0);
    expect(s.channelHasData(0), isFalse);
    expect(s.build(0, now: t).total, 0);
    expect(s.ingest(cm('1', 'A: hi', 0, DateTime(2026, 6, 7, 9)), now: t),
        isTrue); // id freed on clear
  });

  test('seed is idempotent and respects the channel', () {
    final MeshbookStore s = MeshbookStore();
    final List<ChatMessage> history = <ChatMessage>[
      cm('1', 'A: one', 0, DateTime(2026, 6, 7, 8)),
      cm('2', 'A: two', 0, DateTime(2026, 6, 7, 8)),
      cm('3', 'B: other', 1, DateTime(2026, 6, 7, 8)),
    ];
    s.seed(0, history, now: t);
    s.seed(0, history, now: t); // no double count
    expect(s.build(0, now: t).total, 2);
    expect(s.build(1, now: t).total, 0); // seeding ch0 didn't pull ch1
  });

  test('morning reopen: last evening (across midnight) still seeds in', () {
    // Evening chatter the night before, then the app is reopened at 07:00.
    final List<ChatMessage> history = <ChatMessage>[
      cm('1', 'A: hi', 0, DateTime(2026, 6, 7, 21)), // 21:00 last night
      cm('2', 'B: yo', 0, DateTime(2026, 6, 7, 22)), // 22:00 last night
    ];
    final DateTime morning = DateTime(2026, 6, 8, 7); // 07:00, ~9-10h later
    final MeshbookStore s = MeshbookStore();
    s.seed(0, history, now: morning);
    final day = s.build(0, now: morning);
    expect(day.total, 2); // survived past local midnight (rolling 24h)
    expect(day.hourly[21], 1); // hour-of-day buckets populate
    expect(day.hourly[22], 1);
  });

  test('save/load round-trips the day', () async {
    final MeshbookStore a = MeshbookStore();
    a.ingest(cm('1', 'A: hi', 0, DateTime(2026, 6, 7, 9)), now: t);
    a.ingest(cm('2', 'B: yo', 0, DateTime(2026, 6, 7, 9)), now: t);
    await a.save();

    final MeshbookStore b = MeshbookStore();
    await b.load();
    expect(b.build(0, now: t).total, 2);
    expect(b.build(0, now: t).voices, 2);
    // a re-seed with the same messages doesn't double count.
    b.seed(0, <ChatMessage>[cm('1', 'A: hi', 0, DateTime(2026, 6, 7, 9))],
        now: t);
    expect(b.build(0, now: t).total, 2);
  });
}
