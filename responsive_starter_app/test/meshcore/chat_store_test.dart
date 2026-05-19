import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshmore_sns_app/meshcore/chat_message.dart';
import 'package:meshmore_sns_app/meshcore/chat_store.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';

import 'fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ChatMessage JSON round-trips (in + out)', () {
    final ChatMessage incoming = ChatMessage(
      channelIdx: 2,
      text: 'hello ✓',
      outgoing: false,
      at: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      snrDb: -7.5,
      isFlood: true,
    );
    final ChatMessage r = ChatMessage.fromJson(incoming.toJson());
    expect(r.channelIdx, 2);
    expect(r.text, 'hello ✓');
    expect(r.outgoing, isFalse);
    expect(r.at, incoming.at);
    expect(r.snrDb, -7.5);
    expect(r.isFlood, isTrue);

    final ChatMessage out = ChatMessage(
        channelIdx: 0, text: 'sent', outgoing: true);
    final ChatMessage ro = ChatMessage.fromJson(out.toJson());
    expect(ro.outgoing, isTrue);
    expect(ro.snrDb, isNull);
    expect(ro.isFlood, isFalse);
  });

  group('ChatStore', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('save → load preserves messages; clear empties', () async {
      final List<ChatMessage> msgs = <ChatMessage>[
        ChatMessage(channelIdx: 0, text: 'a', outgoing: true),
        ChatMessage(channelIdx: 0, text: 'b', outgoing: false),
      ];
      await ChatStore.save(msgs);
      final List<ChatMessage> back = await ChatStore.load();
      expect(back.map((ChatMessage m) => m.text), <String>['a', 'b']);

      await ChatStore.clear();
      expect(await ChatStore.load(), isEmpty);
    });

    test('save caps to the newest ChatStore.cap entries', () async {
      final List<ChatMessage> many = <ChatMessage>[
        for (int i = 0; i < ChatStore.cap + 30; i++)
          ChatMessage(channelIdx: 0, text: 'm$i', outgoing: false),
      ];
      await ChatStore.save(many);
      final List<ChatMessage> back = await ChatStore.load();
      expect(back.length, ChatStore.cap);
      expect(back.first.text, 'm30'); // oldest 30 dropped
      expect(back.last.text, 'm${ChatStore.cap + 29}');
    });

    test('corrupt store loads clean (no throw)', () async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{'mm.chat.v1': 'not json'});
      expect(await ChatStore.load(), isEmpty);
    });
  });

  group('controller persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('restores persisted history on construction', () async {
      final List<ChatMessage> seed = <ChatMessage>[
        ChatMessage(channelIdx: 0, text: 'earlier public msg',
            outgoing: false),
      ];
      await ChatStore.save(seed); // persist before constructing

      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ctrl.messagesFor(0).map((m) => m.text),
          contains('earlier public msg'));
      ctrl.dispose();
    });

    test('sent + received messages are persisted', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection:
            MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
      );
      await ctrl.connect();
      fake.emit(selfInfoFrame()); // → ready
      await Future<void>.delayed(Duration.zero);

      await ctrl.sendChannelText('outgoing one');
      fake.emit(channelMsgFrame(text: 'incoming one'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final List<ChatMessage> persisted = await ChatStore.load();
      final Iterable<String> texts =
          persisted.map((ChatMessage m) => m.text);
      expect(texts, containsAll(<String>['outgoing one', 'incoming one']));
      ctrl.dispose();
    });
  });
}
