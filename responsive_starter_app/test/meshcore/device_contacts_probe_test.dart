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

  test('scrub: location-hidden (no-GPS) non-favourites count as out of '
      'range; favourites + known are protected; stale by last-advert',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = await ready(fake);

    // Two no-GPS contacts with an old last-advert (the helper default).
    fake.emit(contactsStart(2));
    fake.emit(contactFrame(name: 'A', firstPubByte: 0xAA));
    fake.emit(contactFrame(name: 'B', firstPubByte: 0xBB));
    fake.emit(endOfContacts());
    await Future<void>.delayed(Duration.zero);
    expect(mc.probedContacts.length, 2);

    final String aKey = hex(mc.probedContacts
        .firstWhere((Contact c) => c.name == 'A')
        .publicKey);
    await mc.toggleFavorite(aKey); // protect A

    // No own location, but a no-GPS contact is out of range by policy.
    expect(mc.ownLocation, isNull);
    expect(mc.outOfRangeContactCount(50), 1); // B only (A is a favourite)
    expect(mc.staleContactCount(30), 1); // B only

    final int removed = await mc.removeOutOfRangeContacts(50);
    expect(removed, 1);
    expect(
        mc.probedContacts.any((Contact c) => c.name == 'B'), isFalse);
    expect(mc.probedContacts.any((Contact c) => c.name == 'A'), isTrue);

    mc.dispose();
  });
}
