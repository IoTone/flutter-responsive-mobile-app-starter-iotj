// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/chat_message.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_transport.dart';

/// RESP_CODE_SENT (0x06): [06][flood][ack u32 LE][timeout u32 LE].
Uint8List msgSentFrame({
  required int ack,
  required bool flood,
  int timeoutMs = 1000,
}) {
  final Uint8List f = Uint8List(10);
  f[0] = 0x06;
  f[1] = flood ? 1 : 0;
  final ByteData bd = ByteData.view(f.buffer);
  bd.setUint32(2, ack, Endian.little);
  bd.setUint32(6, timeoutMs, Endian.little);
  return f;
}

/// PUSH_CODE_ACK (0x82): [82][ack u32 LE].
Uint8List ackFrame(int ack) {
  final Uint8List f = Uint8List(5);
  f[0] = 0x82;
  ByteData.view(f.buffer).setUint32(1, ack, Endian.little);
  return f;
}

Future<MeshcoreController> readyController(
  FakeMeshcoreTransport fake, {
  Duration? deliveryTimeoutOverride,
}) async {
  final MeshcoreController ctrl = MeshcoreController(
    transportFactory: () async => fake,
    connection:
        MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    deliveryTimeoutOverride: deliveryTimeoutOverride,
  );
  await ctrl.connect();
  fake.emit(selfInfoFrame()); // → ready
  await Future<void>.delayed(Duration.zero);
  return ctrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('ChatMessage delivery persistence', () {
    test('round-trips delivery + expectedAck', () {
      final ChatMessage m = ChatMessage(
        channelIdx: 0,
        text: 'hi',
        outgoing: true,
        delivery: MessageDelivery.delivered,
        expectedAck: 0x12345678,
      );
      final ChatMessage back = ChatMessage.fromJson(m.toJson());
      expect(back.delivery, MessageDelivery.delivered);
      expect(back.expectedAck, 0x12345678);
    });

    test('a persisted "sending" resolves to "failed" on restore', () {
      final ChatMessage m = ChatMessage(
        channelIdx: 0,
        text: 'hi',
        outgoing: true,
        delivery: MessageDelivery.sending,
      );
      expect(ChatMessage.fromJson(m.toJson()).delivery,
          MessageDelivery.failed);
    });

    test('incoming messages carry no delivery state', () {
      final ChatMessage m =
          ChatMessage(channelIdx: 0, text: 'rx', outgoing: false);
      expect(ChatMessage.fromJson(m.toJson()).delivery, isNull);
    });
  });

  group('controller delivery tracking', () {
    const String peer = 'aabbccddeeff00112233';

    test('DM: sending → sent (MsgSent) → delivered (Ack)', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = await readyController(fake);

      await ctrl.sendDirectText(peer, 'ping');
      // Optimistic row starts in `sending`.
      expect(ctrl.dmHistoryFor(peer).single.delivery,
          MessageDelivery.sending);

      // Device confirms (direct, not flood) with an ack tag.
      fake.emit(msgSentFrame(ack: 0xCAFEBABE, flood: false));
      await Future<void>.delayed(Duration.zero);
      final ChatMessage sent = ctrl.dmHistoryFor(peer).single;
      expect(sent.delivery, MessageDelivery.sent);
      expect(sent.expectedAck, 0xCAFEBABE);

      // Recipient ack arrives → delivered.
      fake.emit(ackFrame(0xCAFEBABE));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.dmHistoryFor(peer).single.delivery,
          MessageDelivery.delivered);
      ctrl.dispose();
    });

    test('channel: sent is terminal (flood → no ack expected)', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      // Short override would fire a timeout if one were armed; proves
      // channel messages don't arm an ack timeout.
      final MeshcoreController ctrl = await readyController(fake,
          deliveryTimeoutOverride: const Duration(milliseconds: 30));

      await ctrl.sendChannelText('hello');
      fake.emit(msgSentFrame(ack: 0x1, flood: true));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.messagesFor(0).single.delivery, MessageDelivery.sent);

      // Wait past the override; channel must stay `sent`, not `failed`.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(ctrl.messagesFor(0).single.delivery, MessageDelivery.sent);
      ctrl.dispose();
    });

    test('DM with no ack within timeout → failed', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = await readyController(fake,
          deliveryTimeoutOverride: const Duration(milliseconds: 30));

      await ctrl.sendDirectText(peer, 'ping');
      fake.emit(msgSentFrame(ack: 0xABCD, flood: false));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.dmHistoryFor(peer).single.delivery, MessageDelivery.sent);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(ctrl.dmHistoryFor(peer).single.delivery,
          MessageDelivery.failed);
      ctrl.dispose();
    });

    test('confirm watchdog: no MsgSent → failed', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = await readyController(fake,
          deliveryTimeoutOverride: const Duration(milliseconds: 30));

      await ctrl.sendDirectText(peer, 'ping');
      expect(ctrl.dmHistoryFor(peer).single.delivery,
          MessageDelivery.sending);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(ctrl.dmHistoryFor(peer).single.delivery,
          MessageDelivery.failed);
      ctrl.dispose();
    });

    test('two DMs confirm in FIFO order', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = await readyController(fake);

      await ctrl.sendDirectText(peer, 'first');
      await ctrl.sendDirectText(peer, 'second');
      // First MsgSent attaches to the oldest pending (first).
      fake.emit(msgSentFrame(ack: 0x111, flood: false));
      await Future<void>.delayed(Duration.zero);
      fake.emit(msgSentFrame(ack: 0x222, flood: false));
      await Future<void>.delayed(Duration.zero);

      final List<ChatMessage> hist = ctrl.dmHistoryFor(peer);
      expect(hist[0].text, 'first');
      expect(hist[0].expectedAck, 0x111);
      expect(hist[1].text, 'second');
      expect(hist[1].expectedAck, 0x222);

      // Ack for the second only.
      fake.emit(ackFrame(0x222));
      await Future<void>.delayed(Duration.zero);
      expect(hist[0].delivery, MessageDelivery.sent);
      expect(ctrl.dmHistoryFor(peer)[1].delivery,
          MessageDelivery.delivered);
      ctrl.dispose();
    });
  });
}
