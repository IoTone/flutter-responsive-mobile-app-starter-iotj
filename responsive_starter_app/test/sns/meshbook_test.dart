// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/chat_message.dart';
import 'package:meshmore_sns_app/sns/meshbook.dart';

void main() {
  final DateTime day = DateTime(2026, 6, 7); // local midnight
  final DateTime end = DateTime(2026, 6, 7, 23, 59);

  ChatMessage cm(String text, int hour, {int ch = 0}) => ChatMessage(
        channelIdx: ch,
        text: text,
        outgoing: false,
        at: DateTime(2026, 6, 7, hour),
      );

  test('top voices, hourly histogram, reply rate', () {
    final List<ChatMessage> msgs = <ChatMessage>[
      cm('Kanako.1: weather fukuoka 28', 9),
      cm('Davi1: on my way', 9),
      cm('Kanako.1: > on my way\n\nsee you', 10), // a reply
      cm('Kanako.1: another', 10),
      cm('hi with no name prefix', 11), // counts to total, not a voice
      cm('Davi1: ok', 23, ch: 1), // different channel → excluded
    ];

    final MbkDay d =
        MbkEngine.analyse(msgs, channelIdx: 0, dayStart: day, now: end);

    expect(d.total, 5); // the CH1 message is excluded
    expect(d.voices, 2); // Kanako.1, Davi1 (the no-name line isn't a voice)
    expect(d.replies, 1);
    expect(d.replyPercent, 20);
    expect(d.top.first.name, 'Kanako.1');
    expect(d.top.first.count, 3);
    expect(d.top.first.replies, 1);
    expect(d.hourly[9], 2);
    expect(d.hourly[10], 2);
    expect(d.hourly[11], 1);
    expect(d.peakHour, 2);
  });

  test('only counts the current day window', () {
    final List<ChatMessage> msgs = <ChatMessage>[
      ChatMessage(
          channelIdx: 0,
          text: 'A: yesterday',
          outgoing: false,
          at: DateTime(2026, 6, 6, 23)), // before dayStart
      cm('A: today', 8),
      ChatMessage(
          channelIdx: 0,
          text: 'A: future',
          outgoing: false,
          at: DateTime(2026, 6, 8, 1)), // after now
    ];
    final MbkDay d =
        MbkEngine.analyse(msgs, channelIdx: 0, dayStart: day, now: end);
    expect(d.total, 1);
    expect(d.hourly[8], 1);
  });

  test('empty day', () {
    final MbkDay d = MbkEngine.analyse(const <ChatMessage>[],
        channelIdx: 0, dayStart: day, now: end);
    expect(d.isEmpty, isTrue);
    expect(d.replyPercent, 0);
    expect(d.voices, 0);
  });

  test('topN caps the leaderboard', () {
    final List<ChatMessage> msgs = <ChatMessage>[
      for (int i = 0; i < 15; i++) cm('user$i: hi', 12),
    ];
    final MbkDay d = MbkEngine.analyse(msgs,
        channelIdx: 0, dayStart: day, now: end, topN: 10);
    expect(d.voices, 15);
    expect(d.top.length, 10);
  });
}
