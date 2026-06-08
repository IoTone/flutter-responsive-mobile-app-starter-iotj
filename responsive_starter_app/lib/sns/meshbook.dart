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

/// A recurring term and how many of the day's messages used it (P2).
class MbkTopic {
  const MbkTopic(this.term, this.count);
  final String term;
  final int count;
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
    required this.topics,
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

  /// Recurring terms in the day's messages, strongest first (P2).
  final List<MbkTopic> topics;
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
    final Map<String, int> terms = <String, int>{};
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

      // Topic terms — once per message (a word repeated in one message
      // counts once, so "topics" reflect how many *people/messages*
      // mentioned it, not raw word counts).
      for (final String t in _topicTokens(body)) {
        terms[t] = (terms[t] ?? 0) + 1;
      }

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

    // Topics: recurring terms, minus the day's voice handles (people
    // aren't topics) and anything mentioned only once.
    final Set<String> nameTokens = <String>{};
    for (final String n in byName.keys) {
      for (final String t in _tokenize(n)) {
        nameTokens.add(t);
      }
    }
    final List<MbkTopic> topics = <MbkTopic>[
      for (final MapEntry<String, int> e in terms.entries)
        if (e.value >= 2 && !nameTokens.contains(e.key))
          MbkTopic(e.key, e.value),
    ]..sort((MbkTopic a, MbkTopic b) {
        final int c = b.count.compareTo(a.count);
        return c != 0 ? c : a.term.compareTo(b.term);
      });

    return MbkDay(
      channelIdx: channelIdx,
      dayStart: dayStart,
      hourly: hourly,
      top: ranked.take(topN).toList(growable: false),
      total: total,
      replies: replies,
      voices: byName.length,
      topics: topics.take(8).toList(growable: false),
      computedAt: end,
    );
  }

  /// Tokens from a message body for topic counting: strips reply-quote
  /// lines (`> …`), lowercases, splits on non-letters/digits, drops
  /// stopwords / short tokens / pure numbers. De-duped per message.
  static Set<String> _topicTokens(String body) {
    final StringBuffer kept = StringBuffer();
    for (final String line in body.split('\n')) {
      if (line.trimLeft().startsWith('>')) continue; // quoted text
      kept
        ..write(line)
        ..write(' ');
    }
    return <String>{
      for (final String t in _tokenize(kept.toString()))
        if (t.length >= 3 &&
            !_stopwords.contains(t) &&
            !RegExp(r'^\d+$').hasMatch(t))
          t
    };
  }

  static List<String> _tokenize(String s) => s
      .toLowerCase()
      .split(RegExp(r"[^a-z0-9À-ɏ぀-ヿ一-鿿]+"))
      .where((String t) => t.isNotEmpty)
      .toList(growable: false);

  static const Set<String> _stopwords = <String>{
    'the', 'and', 'for', 'are', 'was', 'were', 'been', 'being', 'this',
    'that', 'these', 'those', 'with', 'from', 'have', 'has', 'had', 'not',
    'you', 'your', 'youre', 'yours', 'they', 'them', 'their', 'theyre',
    'she', 'him', 'her', 'his', 'hers', 'our', 'ours', 'its', 'who', 'whom',
    'what', 'when', 'where', 'which', 'how', 'why', 'all', 'any', 'some',
    'can', 'cant', 'cannot', 'will', 'wont', 'would', 'could', 'should',
    'shouldnt', 'does', 'doesnt', 'did', 'didnt', 'dont', 'get', 'got',
    'getting', 'going', 'gonna', 'wanna', 'like', 'just', 'now', 'here',
    'there', 'then', 'than', 'too', 'very', 'about', 'out', 'over', 'into',
    'onto', 'off', 'down', 'back', 'still', 'also', 'much', 'many', 'more',
    'most', 'lot', 'lots', 'yeah', 'yep', 'nope', 'okay', 'lol', 'haha',
    'hey', 'hello', 'thanks', 'thx', 'please', 'pls', 'http', 'https',
    'www', 'com', 'one', 'two', 'see', 'good', 'well', 'sure',
    'know', 'think', 'need', 'want', 'make', 'made', 'time', 'today',
    'tonight', 'morning', 'afternoon', 'evening', 'guys', 'everyone',
  };

  /// The message body with the `name: ` prefix stripped (so reply
  /// detection isn't fooled by the sender's name).
  static String _bodyOf(String text) {
    final int sep = text.indexOf(': ');
    return (sep > 0 && sep <= 32) ? text.substring(sep + 2) : text;
  }
}
