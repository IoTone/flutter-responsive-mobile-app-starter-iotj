// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore/meshcore.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_transport.dart';

String _pubHex(int firstByte) => <int>[
      for (int i = 0; i < 32; i++) (firstByte + i) & 0xFF,
    ].map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

Future<(MeshcoreController, FakeMeshcoreTransport)> _ready() async {
  final FakeMeshcoreTransport fake = FakeMeshcoreTransport(connected: true);
  final MeshcoreController ctrl = MeshcoreController(
    transportFactory: () async => fake,
    connection:
        MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
  );
  await ctrl.connect();
  fake.emit(selfInfoFrame());
  // Let the handshake complete + the ready-state propagate.
  for (int i = 0; i < 50 && !ctrl.isReady; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return (ctrl, fake);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('Contact telemetry-permission flag bits', () {
    test('bit layout: favourite=0x01, base=0x02, loc=0x04, env=0x08', () {
      expect(Contact.flagFavourite, 0x01);
      expect(Contact.flagTelemBase, 0x02);
      expect(Contact.flagTelemLocation, 0x04);
      expect(Contact.flagTelemEnvironment, 0x08);
    });

    test('getters decode flags', () {
      final Contact c = Contact(
        publicKey: Uint8List(32),
        type: 1,
        flags: 0x0A, // favourite off, base off, loc on (0x04? no) ...
        outPathLen: 0,
        outPath: Uint8List(64),
        name: 'x',
        lastAdvertTimestamp: 0,
        latitudeMicros: 0,
        longitudeMicros: 0,
        lastMod: 0,
      );
      // 0x0A = 0b1010 = base(0x02) + env(0x08).
      expect(c.allowsTelemBase, isTrue);
      expect(c.allowsTelemLocation, isFalse);
      expect(c.allowsTelemEnvironment, isTrue);
      expect(c.isDeviceFavourite, isFalse);
    });

    test('copyWith preserves all fields but the flags', () {
      final Contact c = Contact(
        publicKey: Uint8List.fromList(List<int>.filled(32, 9)),
        type: 2,
        flags: 0x01,
        outPathLen: 3,
        outPath: Uint8List.fromList(List<int>.generate(64, (int i) => i)),
        name: 'Repeater',
        lastAdvertTimestamp: 123,
        latitudeMicros: 456,
        longitudeMicros: 789,
        lastMod: 5,
      );
      final Contact u = c.copyWith(flags: 0x03);
      expect(u.flags, 0x03);
      expect(u.name, 'Repeater');
      expect(u.outPathLen, 3);
      expect(u.lastMod, 5);
      expect(u.latitudeMicros, 456);
    });
  });

  group('setContactTelemetryPermissions', () {
    test('stores the contact and grants base+env, preserving favourite',
        () async {
      final (MeshcoreController, FakeMeshcoreTransport) r = await _ready();
      final MeshcoreController ctrl = r.$1;
      final FakeMeshcoreTransport fake = r.$2;
      expect(ctrl.isReady, isTrue, reason: 'controller should be ready');
      // A synced contact that is a device-favourite (flags bit 0).
      fake.emit(contactFrame(name: 'Bob', firstPubByte: 70, flags: 0x01));
      await Future<void>.delayed(Duration.zero);

      final String hex = _pubHex(70);
      expect(ctrl.isSyncedContact(hex), isTrue);
      expect(ctrl.contactRecordFor(hex)!.allowsTelemBase, isFalse);

      fake.sent.clear();
      await ctrl.setContactTelemetryPermissions(hex,
          base: true, environment: true);

      // An ADD_UPDATE_CONTACT was sent with the new flags.
      final Iterable<Uint8List> updates = fake.sent.where(
          (Uint8List f) => f[0] == MeshcoreCommand.addUpdateContact.code);
      expect(updates, isNotEmpty);
      // flags byte is at offset 34 ([0]=op,[1..32]=pubkey,[33]=type).
      // 0x01 (favourite) | 0x02 (base) | 0x08 (env) = 0x0B.
      expect(updates.last[34], 0x0B);

      // Optimistic local update reflects it too.
      final Contact updated = ctrl.contactRecordFor(hex)!;
      expect(updated.allowsTelemBase, isTrue);
      expect(updated.allowsTelemEnvironment, isTrue);
      expect(updated.allowsTelemLocation, isFalse);
      expect(updated.isDeviceFavourite, isTrue); // preserved
    });

    test('revoking clears just that bit', () async {
      final (MeshcoreController, FakeMeshcoreTransport) r = await _ready();
      final MeshcoreController ctrl = r.$1;
      final FakeMeshcoreTransport fake = r.$2;
      // Start with base+loc+env granted (0x0E).
      fake.emit(contactFrame(name: 'Bob', firstPubByte: 70, flags: 0x0E));
      await Future<void>.delayed(Duration.zero);
      final String hex = _pubHex(70);

      await ctrl.setContactTelemetryPermissions(hex, location: false);
      final Contact c = ctrl.contactRecordFor(hex)!;
      expect(c.allowsTelemLocation, isFalse);
      expect(c.allowsTelemBase, isTrue); // untouched
      expect(c.allowsTelemEnvironment, isTrue); // untouched
    });

    test('no-op for an advert-only (non-contact) node', () async {
      final (MeshcoreController, FakeMeshcoreTransport) r = await _ready();
      final MeshcoreController ctrl = r.$1;
      final FakeMeshcoreTransport fake = r.$2;
      fake.sent.clear();
      await ctrl.setContactTelemetryPermissions('00112233', base: true);
      expect(
          fake.sent.where((Uint8List f) =>
              f[0] == MeshcoreCommand.addUpdateContact.code),
          isEmpty);
    });
  });
}
