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
}
