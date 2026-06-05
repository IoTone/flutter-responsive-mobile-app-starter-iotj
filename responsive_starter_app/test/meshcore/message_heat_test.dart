// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/message_heat.dart';

void main() {
  group('MessageHeatTracker', () {
    const double lat = 45.5;
    const double lon = -122.7;

    test('a single fresh message gives a small but non-zero hotness',
        () {
      final t = MessageHeatTracker();
      final int now = 1716800000;
      t.record(text: 'hi', atUnix: now, lat: lat, lon: lon);
      final scores = t.scores(nowUnix: now);
      expect(scores, hasLength(1));
      // 1 message / hotReference(5) = 0.2 at age 0.
      expect(scores.values.first, closeTo(0.2, 1e-6));
    });

    test('~5 fresh messages in a cell read as fully hot (>=0.8)', () {
      final t = MessageHeatTracker();
      final int now = 1716800000;
      for (int i = 0; i < 5; i++) {
        t.record(text: 'm$i', atUnix: now, lat: lat, lon: lon);
      }
      final scores = t.scores(nowUnix: now);
      expect(scores.values.first, greaterThanOrEqualTo(0.8));
    });

    test('heat decays with age (exp, tau=15min)', () {
      final t = MessageHeatTracker();
      final int now = 1716800000;
      for (int i = 0; i < 5; i++) {
        t.record(text: 'm$i', atUnix: now, lat: lat, lon: lon);
      }
      final double fresh = t.scores(nowUnix: now).values.first;
      // 15 minutes later (one tau) → each message * e^-1 ≈ 0.368.
      final double later =
          t.scores(nowUnix: now + 15 * 60).values.first;
      expect(later, lessThan(fresh));
      expect(later / fresh, closeTo(0.368, 0.02));
    });

    test('messages older than the 1-hour horizon are pruned', () {
      final t = MessageHeatTracker();
      final int now = 1716800000;
      t.record(text: 'old', atUnix: now, lat: lat, lon: lon);
      // Query 61 minutes later — the entry should be pruned and the
      // cell dropped entirely.
      final scores = t.scores(nowUnix: now + 61 * 60);
      expect(scores, isEmpty);
      expect(t.activeCellCount, 0);
    });

    test('counts() returns the raw last-hour message count per cell', () {
      final t = MessageHeatTracker();
      final int now = 1716800000;
      for (int i = 0; i < 3; i++) {
        t.record(text: 'm$i', atUnix: now, lat: lat, lon: lon);
      }
      // One message in the same cell but 2 hours ago — outside horizon.
      t.record(text: 'old', atUnix: now - 2 * 3600, lat: lat, lon: lon);
      final counts = t.counts(nowUnix: now);
      expect(counts, hasLength(1));
      expect(counts.values.first, 3); // old one pruned, 3 fresh remain
    });

    test('messages without a location produce a ping but no heat', () {
      final t = MessageHeatTracker();
      final int now = 1716800000;
      final ping = t.record(text: 'anon', atUnix: now);
      expect(ping.text, 'anon');
      expect(t.scores(nowUnix: now), isEmpty);
      expect(t.lastPing, isNotNull);
      expect(t.lastPing!.latitude, isNull);
    });

    test('(0,0) sentinel is not placed on the grid', () {
      final t = MessageHeatTracker();
      final int now = 1716800000;
      t.record(text: 'nullisland', atUnix: now, lat: 0, lon: 0);
      expect(t.scores(nowUnix: now), isEmpty);
    });

    test('seq increments monotonically; lastPing reflects newest', () {
      final t = MessageHeatTracker();
      final p1 = t.record(text: 'one', atUnix: 1, lat: lat, lon: lon);
      final p2 = t.record(text: 'two', atUnix: 2, lat: lat, lon: lon);
      expect(p2.seq, greaterThan(p1.seq));
      expect(t.lastPing!.text, 'two');
    });

    test('two messages in distinct cells score independently', () {
      final t = MessageHeatTracker();
      final int now = 1716800000;
      t.record(text: 'a', atUnix: now, lat: 45.5, lon: -122.7);
      // ~5 km away → different 0.002° bucket.
      t.record(text: 'b', atUnix: now, lat: 45.55, lon: -122.7);
      final scores = t.scores(nowUnix: now);
      expect(scores, hasLength(2));
    });

    test('clear wipes cells and lastPing', () {
      final t = MessageHeatTracker();
      t.record(text: 'x', atUnix: 1, lat: lat, lon: lon);
      t.clear();
      expect(t.scores(nowUnix: 1), isEmpty);
      expect(t.lastPing, isNull);
    });
  });

  group('parseChannelSenderName', () {
    test('extracts the "name: " prefix MeshCore prepends', () {
      expect(parseChannelSenderName('Alice: hello there'), 'Alice');
      expect(parseChannelSenderName('Bob-T1000: on my way'),
          'Bob-T1000');
    });

    test('trims surrounding whitespace in the name', () {
      expect(parseChannelSenderName('  Carol : hi'), 'Carol');
    });

    test('null when there is no prefix separator', () {
      expect(parseChannelSenderName('just a message'), isNull);
      expect(parseChannelSenderName(''), isNull);
    });

    test('null when the separator is too far in (not a name)', () {
      // A body with a late ": " and no short name prefix.
      expect(
          parseChannelSenderName(
              'this is a very long sentence with a colon: here'),
          isNull);
    });

    test('null when nothing precedes the separator', () {
      expect(parseChannelSenderName(': orphaned'), isNull);
    });
  });
}
