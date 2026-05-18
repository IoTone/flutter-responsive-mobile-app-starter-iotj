import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore/meshcore.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('connect() injects transport, handshakes, reaches ready', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final List<MeshcoreConnectionState> seen = <MeshcoreConnectionState>[];
    ctrl.addListener(() => seen.add(ctrl.state));

    await ctrl.connect();
    expect(ctrl.isConnecting, isFalse);
    expect(fake.sent, isNotEmpty); // APP_START

    fake.emit(selfInfoFrame());
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.isReady, isTrue);
    expect(ctrl.selfInfo, isNotNull);
    expect(seen, contains(MeshcoreConnectionState.ready));
    ctrl.dispose();
  });

  test('connect() surfaces transport factory failure', () async {
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => throw StateError('no device'),
    );
    await ctrl.connect();
    expect(ctrl.state, MeshcoreConnectionState.failed);
    expect(ctrl.error, contains('no device'));
    ctrl.dispose();
  });

  test('lastFrame updates as inbound frames arrive', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl =
        MeshcoreController(transportFactory: () async => fake);
    await ctrl.connect();

    fake.emit(currentTimeFrame());
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.lastFrame, isA<CurrentTimeFrame>());
    ctrl.dispose();
  });

  group('auto-reconnect on startup', () {
    test('no paired device → does not connect', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      bool called = false;
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async {
          called = true;
          return FakeMeshcoreTransport(connected: true);
        },
      );
      await ctrl.autoConnectIfPaired();
      await Future<void>.delayed(Duration.zero);
      expect(called, isFalse);
      expect(ctrl.hasPairedDevice, isFalse);
      expect(ctrl.state, MeshcoreConnectionState.disconnected);
      ctrl.dispose();
    });

    test('paired device → auto-reconnects, exposes name', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'mm.paired.id': 'AA:BB:CC',
        'mm.paired.name': 'T1000-E',
      });
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );
      await ctrl.autoConnectIfPaired();
      fake.emit(selfInfoFrame());
      await Future<void>.delayed(Duration.zero);

      expect(ctrl.hasPairedDevice, isTrue);
      expect(ctrl.pairedName, 'T1000-E');
      expect(ctrl.isReady, isTrue);
      ctrl.dispose();
    });
  });

  test('recentEvents derives readable lines, newest first', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl =
        MeshcoreController(transportFactory: () async => fake);
    await ctrl.connect();

    fake.emit(selfInfoFrame()); // → ready + 'self-info'
    fake.emit(currentTimeFrame()); // → 'device time synced'
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.recentEvents, isNotEmpty);
    expect(ctrl.recentEvents.first.text, contains('device time'));
    expect(
      ctrl.recentEvents.any((e) => e.text.contains('self-info')),
      isTrue,
    );
    ctrl.dispose();
  });

  group('channel chat (R6)', () {
    test('inbound channel message lands in store + incoming stream',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect();

      final List<String> streamed = <String>[];
      ctrl.incomingChannelMessages.listen((m) => streamed.add(m.text));

      fake.emit(channelMsgFrame(text: 'ping mesh'));
      await Future<void>.delayed(Duration.zero);

      final msgs = ctrl.messagesFor(0);
      expect(msgs, hasLength(1));
      expect(msgs.single.text, 'ping mesh');
      expect(msgs.single.outgoing, isFalse);
      expect(streamed, <String>['ping mesh']);
      ctrl.dispose();
    });

    test('sendChannelText emits 0x03 + optimistic outgoing line',
        () async {
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

      await ctrl.sendChannelText('  hello  ');
      expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x03), isTrue);
      final msgs = ctrl.messagesFor(0);
      expect(msgs.single.text, 'hello'); // trimmed
      expect(msgs.single.outgoing, isTrue);
      ctrl.dispose();
    });

    test('sendChannelText is a no-op when not ready / blank', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect(); // handshaking, not ready
      await ctrl.sendChannelText('nope');
      expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x03), isFalse);
      expect(ctrl.messagesFor(0), isEmpty);
      ctrl.dispose();
    });

    test('CHANNEL_INFO names channels; setActiveChannel switches',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect();

      expect(ctrl.activeChannel, 0);
      expect(ctrl.activeChannelName, 'Public'); // default

      fake.emit(channelInfoFrame(idx: 1, name: 'Ops'));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.channels.map((e) => e.value), contains('Ops'));

      ctrl.setActiveChannel(1);
      expect(ctrl.activeChannel, 1);
      expect(ctrl.activeChannelName, 'Ops');
      ctrl.dispose();
    });

    test('reaching ready probes channels (CMD_GET_CHANNEL 0x1F)',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection:
            MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
      );
      await ctrl.connect();
      fake.emit(selfInfoFrame()); // → ready triggers probe
      await Future<void>.delayed(Duration.zero);

      expect(fake.sent.where((f) => f.isNotEmpty && f[0] == 0x1F),
          isNotEmpty);
      ctrl.dispose();
    });
  });
}
