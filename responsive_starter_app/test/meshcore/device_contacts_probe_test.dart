// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore/meshcore.dart';
import 'package:meshmore_sns_app/meshcore/discovered_node.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';

import 'fake_transport.dart';

Uint8List contactsStart(int count) => Uint8List.fromList(<int>[
      0x02,
      count & 0xFF,
      (count >> 8) & 0xFF,
      (count >> 16) & 0xFF,
      (count >> 24) & 0xFF,
    ]);

Uint8List endOfContacts() =>
    Uint8List.fromList(<int>[0x04, 0, 0, 0, 0]);

String hex(List<int> b) =>
    b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MeshcoreController> ready(FakeMeshcoreTransport fake) async {
    final MeshcoreController mc =
        MeshcoreController(transportFactory: () async => fake);
    await mc.connect();
    fake.emit(selfInfoFrame());
    await Future<void>.delayed(Duration.zero);
    return mc;
  }

  test('probe captures the RAW device contact list + count, including '
      'superseded keys the app otherwise hides', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = await ready(fake);

    // Two same-name nodes; favourite + reconcile one away so its key is
    // superseded (the app will hide it from `_contacts`).
    fake.emit(advertFrame(name: 'Dup', firstPubByte: 0xAA));
    fake.emit(advertFrame(name: 'Dup', firstPubByte: 0xBB));
    await Future<void>.delayed(Duration.zero);
    final String aaKey = mc.nodes
        .firstWhere((DiscoveredNode n) => n.pubKeyHex.startsWith('aa'))
        .pubKeyHex;
    final String bbKey = mc.nodes
        .firstWhere((DiscoveredNode n) => n.pubKeyHex.startsWith('bb'))
        .pubKeyHex;
    await mc.toggleFavorite(aaKey);
    await mc.reconcileIdentity(fromPubKeyHex: aaKey, toPubKeyHex: bbKey);
    expect(mc.isSuperseded(aaKey), isTrue);

    // The radio still stores the (now-dead) AA contact — a full sync.
    fake.emit(contactsStart(1));
    fake.emit(contactFrame(name: 'Dup', firstPubByte: 0xAA));
    fake.emit(endOfContacts());
    await Future<void>.delayed(Duration.zero);

    expect(mc.deviceContactCount, 1);
    // App-level view hides it…
    expect(mc.isSyncedContact(aaKey), isFalse);
    // …but the raw probe shows exactly what the radio has.
    expect(
        mc.probedContacts.any((Contact c) => hex(c.publicKey) == aaKey),
        isTrue);

    mc.dispose();
  });
}
