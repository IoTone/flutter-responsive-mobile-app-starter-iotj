// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import '../meshcore/chat_message.dart';
import '../meshcore/message_heat.dart' show parseChannelSenderName;

/// Meshbook (MBk) — the pure, offline analyser for a channel's day (P1).
///
/// `MbkEngine.analyse` turns the day's channel messages into an [MbkDay]:
/// a leaderboard of the top "names" (channel senders are anonymous-by-
/// protocol → "names" are the inline `name:` display handles, NOT keys),
/// an hourly volume histogram, and the reply rate. No topical analysis yet
/// (P2). Mirrors the wx/microclimate engine's pure-data shape.

class MbkSender {
  MbkSender(this.name) : perHour = List<int>.filled(24, 0);

  final String name;
  int count = 0;
  int replies = 0;
  DateTime? lastAt;

  /// Per-local-hour message counts (24 slots).
  final List<int> perHour;
}

class MbkDay {
  MbkDay({
    required this.channelIdx,
    required this.dayStart,
    required this.hourly,
    required this.top,
    required this.total,
    required this.replies,
    required this.voices,
    required this.computedAt,
  });

  final int channelIdx;

  /// Local midnight that this day's window started at.
  final DateTime dayStart;

  /// Channel-wide message counts per local hour (24 slots).
  final List<int> hourly;

  /// Most-active senders, strongest first (capped to the top N).
  final List<MbkSender> top;

  final int total;
  final int replies;

  /// Distinct named senders seen today.
  final int voices;
  final DateTime computedAt;

  double get replyFraction => total == 0 ? 0 : replies / total;
  int get replyPercent => (replyFraction * 100).round();
  bool get isEmpty => total == 0;

  /// The busiest hour's count, for scaling the histogram.
  int get peakHour =>
      hourly.fold<int>(0, (int m, int h) => h > m ? h : m);
}

abstract final class MbkEngine {
  static const int defaultTopN = 10;

  /// Analyse [messages] for one channel's day. Counts only channel
  /// messages (DMs have channelIdx -1) within `[dayStart, now]`. Every
  /// channel message feeds the hourly/total/replies tallies; only those
  /// with a parseable `name:` prefix feed the sender leaderboard.
  static MbkDay analyse(
    Iterable<ChatMessage> messages, {
    required int channelIdx,
    required DateTime dayStart,
    DateTime? now,
    int topN = defaultTopN,
  }) {
    final DateTime end = now ?? DateTime.now();
    final List<int> hourly = List<int>.filled(24, 0);
    final Map<String, MbkSender> byName = <String, MbkSender>{};
    int total = 0;
    int replies = 0;

    for (final ChatMessage m in messages) {
      if (m.channelIdx != channelIdx) continue; // channel only, no DMs
      if (m.at.isBefore(dayStart) || m.at.isAfter(end)) continue;

      final int hour = m.at.hour; // m.at is local time
      hourly[hour]++;
      total++;

      final String? name = parseChannelSenderName(m.text);
      final String body = _bodyOf(m.text);
      final bool isReply = body.trimLeft().startsWith('>');
      if (isReply) replies++;

      if (name != null) {
        final MbkSender s =
            byName.putIfAbsent(name, () => MbkSender(name));
        s.count++;
        if (isReply) s.replies++;
        s.perHour[hour]++;
        if (s.lastAt == null || m.at.isAfter(s.lastAt!)) s.lastAt = m.at;
      }
    }

    final List<MbkSender> ranked = byName.values.toList()
      ..sort((MbkSender a, MbkSender b) {
        final int c = b.count.compareTo(a.count);
        return c != 0 ? c : a.name.compareTo(b.name);
      });

    return MbkDay(
      channelIdx: channelIdx,
      dayStart: dayStart,
      hourly: hourly,
      top: ranked.take(topN).toList(growable: false),
      total: total,
      replies: replies,
      voices: byName.length,
      computedAt: end,
    );
  }

  /// The message body with the `name: ` prefix stripped (so reply
  /// detection isn't fooled by the sender's name).
  static String _bodyOf(String text) {
    final int sep = text.indexOf(': ');
    return (sep > 0 && sep <= 32) ? text.substring(sep + 2) : text;
  }
}
