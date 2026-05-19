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
    fake.emit(currentTimeFrame()); // → 'device clock …'
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.recentEvents, isNotEmpty);
    expect(ctrl.recentEvents.first.text, contains('device clock'));
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

  test('a heard advert is in range (local receive time, not advert ts)',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl =
        MeshcoreController(transportFactory: () async => fake);
    await ctrl.connect();

    // ts=1 (1970) — under the old logic this made the node look
    // ancient and therefore "known" but not "in range".
    fake.emit(advertFrame(name: 'AdvNode', ts: 1));
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.nodes, hasLength(1));
    final n = ctrl.nodes.single;
    expect(n.name, 'AdvNode');
    expect(n.viaAdvert, isTrue);
    expect(n.inRange, isTrue); // heard now, regardless of sender clock
    ctrl.dispose();
  });

  test('reaching ready syncs the device clock (CMD_SET_DEVICE_TIME 0x06)',
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

    final setTime =
        fake.sent.where((f) => f.isNotEmpty && f[0] == 0x06).toList();
    expect(setTime, isNotEmpty);
    // Payload is a plausible recent unix time (u32 LE after opcode).
    final f = setTime.first;
    final int ts = f[1] | (f[2] << 8) | (f[3] << 16) | (f[4] << 24);
    expect(ts, greaterThan(1735689600)); // > 2025-01-01
    ctrl.dispose();
  });

  group('device clock + ERR hardening', () {
    test('reaching ready also requests device time (GET 0x05)',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );
      await ctrl.connect();
      fake.emit(selfInfoFrame());
      await Future<void>.delayed(Duration.zero);
      expect(fake.sent.where((f) => f.isNotEmpty && f[0] == 0x05),
          isNotEmpty); // GET_DEVICE_TIME
      expect(fake.sent.where((f) => f.isNotEmpty && f[0] == 0x06),
          isNotEmpty); // SET_DEVICE_TIME
      ctrl.dispose();
    });

    test('ErrorFrame surfaces in recent activity', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect();
      fake.emit(errorFrame(6)); // ERR code 6
      await Future<void>.delayed(Duration.zero);
      expect(
        ctrl.recentEvents.any((e) => e.text.contains('device error '
            '(code 6)')),
        isTrue,
      );
      ctrl.dispose();
    });

    test('contact "in range" is judged against the device clock',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect();
      final int phoneNow =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final int deviceNow = phoneNow - 100000; // device 100000s behind

      fake.emit(currentTimeFrameAt(deviceNow)); // learn offset
      fake.emit(contactFrame(
          name: 'FreshPeer', firstPubByte: 70, lastAdvertTs: deviceNow));
      fake.emit(contactFrame(
          name: 'OldPeer',
          firstPubByte: 120,
          lastAdvertTs: deviceNow - 10000));
      await Future<void>.delayed(Duration.zero);

      final fresh = ctrl.nodes.firstWhere((n) => n.name == 'FreshPeer');
      final old = ctrl.nodes.firstWhere((n) => n.name == 'OldPeer');
      expect(fresh.inRange, isTrue); // adv+offset ≈ phone now
      expect(old.inRange, isFalse); // 10000s stale in device time
      ctrl.dispose();
    });

    test('late CURR_TIME re-derives contact freshness', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect();
      final int phoneNow =
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final int deviceNow = phoneNow - 100000;

      // Contact arrives BEFORE the offset is known.
      fake.emit(contactFrame(
          name: 'P', firstPubByte: 70, lastAdvertTs: deviceNow));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.nodes.single.inRange, isFalse); // looks ancient

      fake.emit(currentTimeFrameAt(deviceNow)); // learn offset
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.nodes.single.inRange, isTrue); // re-derived
      ctrl.dispose();
    });
  });

  test('setChannel emits SET_CHANNEL (0x20) then GET_CHANNEL (0x1F)',
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

    await ctrl.setChannel(
        idx: 1, name: 'Ops', psk: List<int>.filled(16, 7));
    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x20), isTrue);
    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x1F), isTrue);
    expect(ctrl.channels.any((e) => e.key == 1 && e.value == 'Ops'),
        isTrue); // optimistic
    ctrl.dispose();
  });

  test('setChannel is a no-op when not ready', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl =
        MeshcoreController(transportFactory: () async => fake);
    await ctrl.connect(); // handshaking, not ready
    await ctrl.setChannel(idx: 2, name: 'X', psk: List<int>.filled(16, 1));
    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x20), isFalse);
    ctrl.dispose();
  });

  group('battery (R16)', () {
    test('reaching ready polls battery (GET_BATTERY 0x14)', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );
      await ctrl.connect();
      fake.emit(selfInfoFrame());
      await Future<void>.delayed(Duration.zero);
      expect(fake.sent.where((f) => f.isNotEmpty && f[0] == 0x14),
          isNotEmpty);
      ctrl.dispose();
    });

    test('BATT_AND_STORAGE populates level + approx percent', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect();
      fake.emit(batteryFrame(3970));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.batteryMillivolts, 3970);
      expect(ctrl.batteryVolts, closeTo(3.97, 0.001));
      expect(ctrl.batteryPercent, 74); // (3970-3300)/900*100
      ctrl.dispose();
    });

    test('charging heuristic: rise→true, fall→false, steady→null',
        () async {
      Future<MeshcoreController> feed(List<int> mvs) async {
        final FakeMeshcoreTransport fake =
            FakeMeshcoreTransport(connected: true);
        final MeshcoreController c =
            MeshcoreController(transportFactory: () async => fake);
        await c.connect();
        for (final int mv in mvs) {
          fake.emit(batteryFrame(mv));
          await Future<void>.delayed(Duration.zero);
        }
        return c;
      }

      final MeshcoreController rising = await feed(<int>[3700, 3760, 3800]);
      expect(rising.charging, isTrue);
      rising.dispose();

      final MeshcoreController falling =
          await feed(<int>[3900, 3850, 3800]);
      expect(falling.charging, isFalse);
      falling.dispose();

      final MeshcoreController steady = await feed(<int>[3800, 3805]);
      expect(steady.charging, isNull); // < 40 mV → unknown
      steady.dispose();
    });
  });

  group('inbound queue drain (CMD_SYNC_NEXT_MESSAGE)', () {
    int syncs(FakeMeshcoreTransport f) =>
        f.sent.where((s) => s.isNotEmpty && s[0] == 0x0A).length;

    test('MSGS_WAITING drains via SYNC until NO_MORE; items ingested',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect(); // handshaking (no ready-drain)
      expect(syncs(fake), 0);

      // Device says items are queued → app starts pulling.
      fake.emit(msgsWaitingFrame(count: 1));
      await Future<void>.delayed(Duration.zero);
      expect(syncs(fake), 1);

      // The SYNC reply is a queued channel message → pull the next.
      fake.emit(channelMsgFrame(text: 'queued ping'));
      await Future<void>.delayed(Duration.zero);
      expect(syncs(fake), 2);
      expect(ctrl.messagesFor(0).single.text, 'queued ping');

      // Queue empty → stop (no further SYNC).
      fake.emit(noMoreMessagesFrame());
      await Future<void>.delayed(Duration.zero);
      expect(syncs(fake), 2);

      // A later unrelated frame must not resume draining.
      fake.emit(channelMsgFrame(text: 'live'));
      await Future<void>.delayed(Duration.zero);
      expect(syncs(fake), 2);
      ctrl.dispose();
    });

    test('reaching ready kicks a drain', () async {
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
      expect(syncs(fake), greaterThanOrEqualTo(1));
      ctrl.dispose();
    });
  });
}
