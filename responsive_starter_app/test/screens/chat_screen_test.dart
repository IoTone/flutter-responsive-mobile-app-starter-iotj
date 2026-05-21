import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/chat_screen.dart';
import 'package:meshmore_sns_app/tts/tts_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../meshcore/fake_transport.dart';

class FakeTtsSpeaker implements TtsSpeaker {
  final List<String> spoken = <String>[];
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

Widget _host(MeshcoreController mc, TtsController tts) => MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<MeshcoreController>.value(value: mc),
            ChangeNotifierProvider<TtsController>.value(value: tts),
          ],
          child: const ChatScreen(),
        ),
      ),
    );

void main() {
  // TtsController.setEnabled persists via shared_preferences; without
  // a mock its platform channel never answers and the test hangs.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('compose + send emits 0x03 and shows the line (R6)',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final TtsController tts = TtsController(speaker: FakeTtsSpeaker());
    await t.pumpWidget(_host(mc, tts));

    await mc.connect();
    fake.emit(selfInfoFrame()); // → ready
    await t.pumpAndSettle();

    expect(find.text('— no messages on this channel —'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'hello mesh');
    await t.tap(find.byIcon(Icons.send));
    await t.pumpAndSettle();

    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x03), isTrue);
    expect(find.text('hello mesh'), findsOneWidget);
    mc.dispose();
  });

  testWidgets('channel chips switch the active channel', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final TtsController tts = TtsController(speaker: FakeTtsSpeaker());
    await t.pumpWidget(_host(mc, tts));
    await mc.connect();
    fake.emit(selfInfoFrame()); // → ready
    await t.pump();
    fake.emit(channelInfoFrame(idx: 1, name: 'Ops'));
    await t.pump();

    expect(find.text('CHANNEL · PUBLIC'), findsOneWidget);
    await t.tap(find.text('Ops'));
    await t.pump();
    expect(find.text('CHANNEL · OPS'), findsOneWidget);
    expect(mc.activeChannel, 1);
    mc.dispose();
  });

  testWidgets('inbound message is NOT spoken when TTS is off (R5)',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final FakeTtsSpeaker spk = FakeTtsSpeaker();
    final TtsController off = TtsController(speaker: spk); // default off
    await t.pumpWidget(_host(mc, off));
    await mc.connect();
    fake.emit(selfInfoFrame()); // → ready (no reconnect churn)
    await t.pump();
    fake.emit(channelMsgFrame(text: 'silent'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 10));
    expect(spk.spoken, isEmpty);
    mc.dispose();
  });

  testWidgets('long-press → Delete removes the row locally (R20)',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final TtsController tts = TtsController(speaker: FakeTtsSpeaker());
    await t.pumpWidget(_host(mc, tts));
    await mc.connect();
    fake.emit(selfInfoFrame()); // → ready
    await t.pump();
    fake.emit(channelMsgFrame(text: 'delete me'));
    await t.pump();
    expect(find.text('delete me'), findsOneWidget);

    await t.longPress(find.text('delete me'));
    await t.pumpAndSettle();
    expect(find.text('Delete locally'), findsOneWidget);
    await t.tap(find.text('Delete locally'));
    await t.pumpAndSettle();
    expect(find.text('Delete this message locally?'), findsOneWidget);
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();

    expect(find.text('delete me'), findsNothing);
    expect(mc.messagesFor(0).where((m) => m.text == 'delete me'),
        isEmpty);
    mc.dispose();
  });

  testWidgets('Reply prepends a quoted prefix into the composer (R20)',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final TtsController tts = TtsController(speaker: FakeTtsSpeaker());
    await t.pumpWidget(_host(mc, tts));
    await mc.connect();
    fake.emit(selfInfoFrame());
    await t.pump();
    fake.emit(channelMsgFrame(text: 'hey there'));
    await t.pump();

    await t.longPress(find.text('hey there'));
    await t.pumpAndSettle();
    await t.tap(find.text('Reply'));
    await t.pumpAndSettle();

    final TextField field =
        t.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, startsWith('> hey there'));
    mc.dispose();
  });

  testWidgets('inbound message IS spoken when TTS is on (R5)',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final FakeTtsSpeaker spk = FakeTtsSpeaker();
    final TtsController on = TtsController(speaker: spk);
    await on.setEnabled(true);
    await t.pumpWidget(_host(mc, on));
    await mc.connect();
    fake.emit(selfInfoFrame()); // → ready
    await t.pump();
    fake.emit(channelMsgFrame(text: 'spoken aloud'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 10));
    expect(spk.spoken, <String>['spoken aloud']);
    mc.dispose();
  });
}
