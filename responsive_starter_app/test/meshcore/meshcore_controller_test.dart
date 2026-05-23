// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore/meshcore.dart';
import 'package:meshmore_sns_app/meshcore/background_prefs.dart';
import 'package:meshmore_sns_app/meshcore/favorite_store.dart';
import 'package:meshmore_sns_app/meshcore/known_store.dart';
import 'package:meshmore_sns_app/meshcore/mesh_event.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/meshcore/own_location.dart';
import 'package:meshmore_sns_app/perms/location_service.dart';
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

  test('ownLocation is null when SelfInfo carries (0, 0) and resolves '
      'to deviceReported when the device returns a non-zero fix',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    await ctrl.connect();
    fake.emit(selfInfoFrame()); // lat=0, lon=0
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.selfInfo, isNotNull);
    expect(ctrl.ownLocation, isNull,
        reason: '(0,0) is the unset sentinel');

    fake.emit(selfInfoFrameAt(lat: 37.421, lon: -122.084));
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.ownLocation, isNotNull);
    expect(ctrl.ownLocation!.latitude, closeTo(37.421, 1e-5));
    expect(ctrl.ownLocation!.longitude, closeTo(-122.084, 1e-5));

    // Distance to a known point: ~0 km away from itself.
    final double? d0 =
        ctrl.distanceMetersTo(37.421, -122.084);
    expect(d0, closeTo(0.0, 1.0));

    // Distance ~1 km north (lat + ~0.009° ≈ 1 km).
    final double? d1 =
        ctrl.distanceMetersTo(37.421 + 0.009, -122.084);
    expect(d1, isNotNull);
    expect(d1!, inInclusiveRange(900, 1100));
    ctrl.dispose();
  });

  test('phone fix is used as ownLocation fallback when device unset; '
      'device fix overrides it once it arrives', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final NoopLocationService loc =
        NoopLocationService(next: const PhoneFix(latitude: 1.0, longitude: 2.0));
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
      locationService: loc,
    );
    await ctrl.connect();
    fake.emit(selfInfoFrame()); // device says (0,0) → unset
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.ownLocation, isNull);

    final bool ok = await ctrl.requestPhoneLocationFix();
    expect(ok, isTrue);
    expect(loc.callCount, 1);
    expect(ctrl.ownLocation, isNotNull);
    expect(ctrl.ownLocation!.source, OwnLocationSource.phoneFix);
    expect(ctrl.ownLocation!.latitude, closeTo(1.0, 1e-6));

    // Device now reports a real fix → it takes precedence.
    fake.emit(selfInfoFrameAt(lat: 37.421, lon: -122.084));
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.ownLocation!.source, OwnLocationSource.deviceReported);
    expect(ctrl.ownLocation!.latitude, closeTo(37.421, 1e-5));

    // Clearing the phone fix doesn't affect device-reported.
    ctrl.clearPhoneLocationFix();
    expect(ctrl.ownLocation!.source, OwnLocationSource.deviceReported);
    expect(ctrl.phoneLocationFix, isNull);
    ctrl.dispose();
  });

  test('setAdvertLocPolicy emits CMD_SET_OTHER_PARAMS (0x26) and '
      'preserves manualAdd/telemetry/multiAcks from SelfInfo',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    await ctrl.connect();
    // selfInfoFrame() is all-zero past the opcode — so
    // manualAddContacts=false → 0, telemetryModeRaw=0, multiAcks=0.
    fake.emit(selfInfoFrame());
    await Future<void>.delayed(Duration.zero);
    fake.sent.clear(); // ignore APP_START etc. before the SET

    await ctrl.setAdvertLocPolicy(2);
    final Iterable<List<int>> setFrames =
        fake.sent.where((f) => f.isNotEmpty && f[0] == 0x26);
    expect(setFrames, hasLength(1));
    final List<int> frame = setFrames.first;
    // [0x26][manualAdd=0][telemetry=0][locPolicy=2][multiAcks=0]
    expect(frame, <int>[0x26, 0x00, 0x00, 0x02, 0x00]);
    ctrl.dispose();
  });

  test('setManualAddContacts emits 0x26 with the new bool + preserved fields',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    await ctrl.connect();
    fake.emit(selfInfoFrame()); // all-zero
    await Future<void>.delayed(Duration.zero);
    fake.sent.clear();

    await ctrl.setManualAddContacts(true);
    final List<int> frame =
        fake.sent.firstWhere((f) => f.isNotEmpty && f[0] == 0x26);
    // [opcode, manualAdd=1, telemetry=0, loc=0, multiAcks=0]
    expect(frame, <int>[0x26, 0x01, 0x00, 0x00, 0x00]);
    ctrl.dispose();
  });

  test('setTelemetryMode + setMultiAcks emit 0x26 with the right fields',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    await ctrl.connect();
    fake.emit(selfInfoFrame());
    await Future<void>.delayed(Duration.zero);
    fake.sent.clear();

    await ctrl.setTelemetryMode(7);
    expect(
        fake.sent.firstWhere((f) => f.isNotEmpty && f[0] == 0x26),
        <int>[0x26, 0x00, 0x07, 0x00, 0x00]);
    fake.sent.clear();
    await ctrl.setMultiAcks(2);
    expect(
        fake.sent.firstWhere((f) => f.isNotEmpty && f[0] == 0x26),
        <int>[0x26, 0x00, 0x00, 0x00, 0x02]);
    ctrl.dispose();
  });

  test('refreshSelfInfo emits sendSelfAdvert (0x07, flood=0) + appStart (0x01) '
      'and a follow-up SelfInfoFrame propagates to ownLocation',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    await ctrl.connect();
    fake.emit(selfInfoFrameAt(lat: 35.681, lon: 139.767)); // Tokyo
    await Future<void>.delayed(Duration.zero);

    // Initial state — Tokyo.
    expect(ctrl.ownLocation, isNotNull);
    expect(ctrl.ownLocation!.latitude, closeTo(35.681, 1e-3));
    expect(ctrl.ownLocation!.longitude, closeTo(139.767, 1e-3));

    fake.sent.clear();
    await ctrl.refreshSelfInfo();
    await Future<void>.delayed(Duration.zero);

    // Three frames are expected: 0x26 (CMD_SET_OTHER_PARAMS — the
    // Option-B no-op policy re-set), 0x07 (CMD_SEND_SELF_ADVERT,
    // flood=0), 0x01 (CMD_APP_START with appName).
    final List<int> otherParams = fake.sent
        .firstWhere((List<int> f) => f.isNotEmpty && f[0] == 0x26,
            orElse: () => Uint8List(0))
        .toList();
    final List<int> advert = fake.sent
        .firstWhere((List<int> f) => f.isNotEmpty && f[0] == 0x07,
            orElse: () => Uint8List(0))
        .toList();
    final List<int> appStart = fake.sent
        .firstWhere((List<int> f) => f.isNotEmpty && f[0] == 0x01,
            orElse: () => Uint8List(0))
        .toList();
    expect(otherParams, isNotEmpty,
        reason: 'refreshSelfInfo should re-send the current '
            'advertLocPolicy via setOtherParams (0x26)');
    expect(advert, isNotEmpty,
        reason: 'refreshSelfInfo should emit sendSelfAdvert (0x07)');
    expect(advert.length, 2,
        reason: 'sendSelfAdvert payload = [opcode, flood-flag]');
    expect(advert[1], 0,
        reason: 'flood=false means flood-flag byte = 0');
    expect(appStart, isNotEmpty,
        reason: 'refreshSelfInfo should also emit appStart (0x01)');
    expect(appStart[0], 0x01);

    // Simulate the firmware's response — fresh GPS into selfInfo —
    // and verify the controller surfaces the new value via
    // ownLocation. Confirms the app-side data path; if the field
    // shows frozen lat/lon after this test passes, the bug is
    // firmware-side (not honouring Device GPS on advert build).
    fake.emit(selfInfoFrameAt(lat: 35.700, lon: 139.800));
    await Future<void>.delayed(Duration.zero);
    expect(ctrl.ownLocation!.latitude, closeTo(35.700, 1e-3));
    expect(ctrl.ownLocation!.longitude, closeTo(139.800, 1e-3));
    ctrl.dispose();
  });

  test('setAdvertLocPolicy is a no-op when SelfInfo unavailable',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    await ctrl.connect();
    fake.sent.clear();
    // No selfInfoFrame emitted — controller stays in handshaking and
    // selfInfo is null.
    await ctrl.setAdvertLocPolicy(1);
    expect(fake.sent.where((f) => f.isNotEmpty && f[0] == 0x26),
        isEmpty);
    ctrl.dispose();
  });

  test('requestPhoneLocationFix returns false when service has no fix',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final NoopLocationService loc = NoopLocationService(); // next == null
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
      locationService: loc,
    );
    // Drain the constructor's async pref loads (_loadBackgroundPref,
    // ChatStore restore) before exercising the controller, otherwise
    // a late notifyListeners fires on a disposed ChangeNotifier.
    await Future<void>.delayed(Duration.zero);
    final bool ok = await ctrl.requestPhoneLocationFix();
    expect(ok, isFalse);
    expect(ctrl.ownLocation, isNull);
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
    expect(
        ctrl.recentEvents.first.kind,
        anyOf(MeshEventKind.deviceClockSynced,
            MeshEventKind.deviceClockSkew));
    expect(
      ctrl.recentEvents
          .any((e) => e.kind == MeshEventKind.selfInfo),
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
        ctrl.recentEvents.any((e) =>
            e.kind == MeshEventKind.deviceError &&
            e.args['code'] == '6'),
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

  group('device info + identity/advert (R7)', () {
    test('reaching ready queries device info (DEVICE_QUERY 0x16); '
        'DEVICE_INFO populates deviceInfo', () async {
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
      expect(fake.sent.where((f) => f.isNotEmpty && f[0] == 0x16),
          isNotEmpty);

      expect(ctrl.deviceInfo, isNull);
      fake.emit(deviceInfoFrame(fw: 'v1.15.0', mfr: 'Seeed'));
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.deviceInfo, isNotNull);
      expect(ctrl.deviceInfo!.firmwareVersion, 'v1.15.0');
      expect(ctrl.deviceInfo!.manufacturer, 'Seeed');
      ctrl.dispose();
    });

    test('setAdvertName/LatLon emit 0x08/0x0E when ready, else no-op',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );
      await ctrl.connect();

      // Not ready yet → no-op.
      await ctrl.setAdvertName('Nope');
      expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x08), isFalse);

      fake.emit(selfInfoFrame()); // → ready
      await Future<void>.delayed(Duration.zero);

      await ctrl.setAdvertName('NodeA');
      await ctrl.setAdvertLatLon(latitude: 35.681, longitude: 139.767);
      expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x08), isTrue);
      expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x0E), isTrue);
      ctrl.dispose();
    });
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

  group('direct messages (P2P)', () {
    test('sendDirectText emits 0x02 with 6-byte prefix; optimistic '
        'outgoing in dmHistoryFor', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );
      await ctrl.connect();
      fake.emit(selfInfoFrame()); // → ready
      await Future<void>.delayed(Duration.zero);

      const String peer = 'aabbccddeeff' '00000000000000000000000000'
          '00000000000000000000000000';
      await ctrl.sendDirectText(peer, 'hello peer');

      final dm = fake.sent.firstWhere(
          (f) => f.isNotEmpty && f[0] == 0x02,
          orElse: () => fake.sent.last);
      expect(dm[7], 0xaa);
      expect(dm[8], 0xbb);
      expect(dm[9], 0xcc);
      expect(dm[10], 0xdd);
      expect(dm[11], 0xee);
      expect(dm[12], 0xff);
      expect(ctrl.dmHistoryFor(peer).single.text, 'hello peer');
      ctrl.dispose();
    });

    test('inbound DM threads under matched fabric pubkey; emits stream',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect();

      // Surface a fabric node first (pubkey starts 0x10..0x15…).
      fake.emit(advertFrame(name: 'P', firstPubByte: 0x10));
      await Future<void>.delayed(Duration.zero);
      final String peer = ctrl.nodes.single.pubKeyHex;

      final List<String> streamed = <String>[];
      ctrl.incomingDirectMessages.listen((m) => streamed.add(m.text));
      fake.emit(contactMessageFrame(
          prefix: <int>[0x10, 0x11, 0x12, 0x13, 0x14, 0x15],
          text: 'hello me'));
      await Future<void>.delayed(Duration.zero);

      expect(ctrl.dmHistoryFor(peer).single.text, 'hello me');
      expect(streamed, <String>['hello me']);
      ctrl.dispose();
    });
  });

  group('known = direct comms (R18)', () {
    test('incoming DM marks the matching fabric node as known',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect();

      // Advert with pubkey starting 0x10..0x15 → hex "101112131415…"
      fake.emit(advertFrame(name: 'DmPeer', firstPubByte: 0x10));
      // DM from the same 6-byte prefix.
      fake.emit(contactMessageFrame(
          prefix: <int>[0x10, 0x11, 0x12, 0x13, 0x14, 0x15],
          text: 'hello'));
      await Future<void>.delayed(Duration.zero);

      final String pub = ctrl.nodes.single.pubKeyHex;
      expect(pub.startsWith('101112131415'), isTrue);
      expect(ctrl.isKnown(pub), isTrue);
      ctrl.dispose();
    });

    test('markKnown persists; restored on construction', () async {
      await KnownStore.save(<String>{'aa'});
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ctrl.isKnown('aa'), isTrue);
      ctrl.dispose();
    });
  });

  group('favourites = contacts', () {
    test('toggleFavorite adds + persists + notifies, then removes',
        () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      int notifs = 0;
      ctrl.addListener(() => notifs++);

      await ctrl.toggleFavorite('aa');
      expect(ctrl.isFavorite('aa'), isTrue);
      expect(ctrl.favorites, contains('aa'));
      expect(notifs, greaterThan(0));
      expect(await FavoriteStore.load(), contains('aa'));

      await ctrl.toggleFavorite('aa');
      expect(ctrl.isFavorite('aa'), isFalse);
      expect(await FavoriteStore.load(), isEmpty);
      ctrl.dispose();
    });

    test('persisted favourites restore on construction', () async {
      await FavoriteStore.save(<String>{'aa', 'bb'});
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ctrl.isFavorite('aa'), isTrue);
      expect(ctrl.isFavorite('bb'), isTrue);
      ctrl.dispose();
    });
  });

  group('background keep-alive (R17/U8)', () {
    test('reaching ready starts keep-alive (default on); '
        'disconnect stops it', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final FakeBackgroundKeepalive ka = FakeBackgroundKeepalive();
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
        backgroundKeepalive: ka,
      );
      await ctrl.connect();
      fake.emit(selfInfoFrame()); // → ready
      await Future<void>.delayed(Duration.zero);
      expect(ka.starts, greaterThanOrEqualTo(1));

      await ctrl.disconnect();
      expect(ka.stops, greaterThanOrEqualTo(1));
      ctrl.dispose();
    });

    test('disabled → not started on ready; pref persists', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final FakeBackgroundKeepalive ka = FakeBackgroundKeepalive();
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
        backgroundKeepalive: ka,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await ctrl.setBackgroundKeepaliveEnabled(false);
      expect(ctrl.backgroundKeepaliveEnabled, isFalse);
      expect(await BackgroundKeepalivePrefs.enabled(), isFalse);

      await ctrl.connect();
      fake.emit(selfInfoFrame());
      await Future<void>.delayed(Duration.zero);
      expect(ka.starts, 0);
      ctrl.dispose();
    });

    test('toggling while ready stops/starts immediately', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final FakeBackgroundKeepalive ka = FakeBackgroundKeepalive();
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
        backgroundKeepalive: ka,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await ctrl.connect();
      fake.emit(selfInfoFrame());
      await Future<void>.delayed(Duration.zero);
      final int s0 = ka.starts;

      await ctrl.setBackgroundKeepaliveEnabled(false);
      expect(ka.stops, greaterThanOrEqualTo(1));
      await ctrl.setBackgroundKeepaliveEnabled(true);
      expect(ka.starts, greaterThan(s0));
      ctrl.dispose();
    });
  });

  group('app lifecycle resume (R17)', () {
    int syncs(FakeMeshcoreTransport f) =>
        f.sent.where((s) => s.isNotEmpty && s[0] == 0x0A).length;

    test('onAppResumed while ready drains the queue', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );
      await ctrl.connect();
      fake.emit(selfInfoFrame()); // → ready (kicks a drain)
      await Future<void>.delayed(Duration.zero);
      fake.emit(noMoreMessagesFrame()); // end the ready-drain
      await Future<void>.delayed(Duration.zero);

      final int before = syncs(fake);
      await ctrl.onAppResumed();
      await Future<void>.delayed(Duration.zero);
      expect(syncs(fake), greaterThan(before));
      ctrl.dispose();
    });

    test('onAppResumed is a no-op after a manual disconnect', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl =
          MeshcoreController(transportFactory: () async => fake);
      await ctrl.connect();
      await ctrl.disconnect(); // latches _manualDisconnect
      final int before = fake.sent.length;
      await ctrl.onAppResumed();
      await Future<void>.delayed(Duration.zero);
      expect(fake.sent.length, before); // nothing sent
      ctrl.dispose();
    });

    test('onAppResumed does not connect when no device is paired',
        () async {
      bool called = false;
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async {
          called = true;
          return FakeMeshcoreTransport(connected: true);
        },
      );
      await ctrl.onAppResumed(); // disconnected, not manual, unpaired
      await Future<void>.delayed(Duration.zero);
      expect(called, isFalse);
      expect(ctrl.state, MeshcoreConnectionState.disconnected);
      ctrl.dispose();
    });
  });
}
