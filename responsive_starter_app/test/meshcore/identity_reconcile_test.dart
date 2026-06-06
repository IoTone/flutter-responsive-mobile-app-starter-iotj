// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshmore_sns_app/meshcore/discovered_node.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';

import 'fake_transport.dart';

/// R56 — "returning contact": a peer deleted + re-added on the other
/// device comes back with a NEW pubkey under the SAME name. We never
/// auto-migrate (names aren't unique — that would let an impostor inherit
/// your data); the user confirms, then `reconcileIdentity` moves it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<MeshcoreController> ready(FakeMeshcoreTransport fake) async {
    final MeshcoreController mc =
        MeshcoreController(transportFactory: () async => fake);
    await mc.connect();
    fake.emit(selfInfoFrame()); // → ready
    await Future<void>.delayed(Duration.zero);
    return mc;
  }

  test('reconcileIdentity moves star/tags/DM history to the live key and '
      'drops the stale node', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = await ready(fake);

    // Two same-name nodes, different keys (old 0xAA…, new 0xBB…).
    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xAA));
    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xBB));
    await Future<void>.delayed(Duration.zero);

    final String oldPk = mc.nodes
        .firstWhere((DiscoveredNode n) => n.pubKeyHex.startsWith('aa'))
        .pubKeyHex;
    final String newPk = mc.nodes
        .firstWhere((DiscoveredNode n) => n.pubKeyHex.startsWith('bb'))
        .pubKeyHex;

    // Put the user's data on the OLD key.
    await mc.toggleFavorite(oldPk);
    await mc.addTagTo(oldPk, 'home');
    await mc.markKnown(oldPk);
    fake.emit(contactMessageFrame(
        prefix: <int>[0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAF],
        text: 'hi from alice'));
    await Future<void>.delayed(Duration.zero);
    expect(mc.isFavorite(oldPk), isTrue);
    expect(mc.tagsFor(oldPk), contains('home'));
    expect(mc.dmHistoryFor(oldPk), isNotEmpty);

    // Reconcile old → new (the user-confirmed action).
    await mc.reconcileIdentity(fromPubKeyHex: oldPk, toPubKeyHex: newPk);

    // Data now lives on the new key…
    expect(mc.isFavorite(newPk), isTrue);
    expect(mc.tagsFor(newPk), contains('home'));
    expect(mc.isKnown(newPk), isTrue);
    expect(mc.dmHistoryFor(newPk), isNotEmpty);
    // …and is gone from the old key, which is dropped from the fabric.
    expect(mc.isFavorite(oldPk), isFalse);
    expect(mc.tagsFor(oldPk), isEmpty);
    expect(mc.dmHistoryFor(oldPk), isEmpty);
    expect(mc.nodes.any((DiscoveredNode n) => n.pubKeyHex == oldPk), isFalse);
    expect(mc.nodes.any((DiscoveredNode n) => n.pubKeyHex == newPk), isTrue);

    mc.dispose();
  });

  test('identityMatchFor flags a same-name pair off the DATA side, not '
      'timing (the real returning-contact case)', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = await ready(fake);

    // Both heard "now" (the old key keeps getting refreshed by sync). The
    // saved one (favourited) is the stale data side; the other is live.
    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xAA));
    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xBB));
    await Future<void>.delayed(Duration.zero);
    final String oldPk = mc.nodes
        .firstWhere((DiscoveredNode n) => n.pubKeyHex.startsWith('aa'))
        .pubKeyHex;
    final String newPk = mc.nodes
        .firstWhere((DiscoveredNode n) => n.pubKeyHex.startsWith('bb'))
        .pubKeyHex;
    await mc.toggleFavorite(oldPk);

    // Opening either key surfaces the same pair: stale = the saved key,
    // fresh = the new key — even though both were heard at the same time.
    for (final String pk in <String>[oldPk, newPk]) {
      final IdentityMatch? match = mc.identityMatchFor(pk);
      expect(match, isNotNull, reason: 'should flag from $pk');
      expect(match!.stale.pubKeyHex, oldPk);
      expect(match.fresh.pubKeyHex, newPk);
    }

    mc.dispose();
  });

  test('a reconciled-away key stays gone when the radio re-syncs it',
      () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = await ready(fake);

    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xAA));
    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xBB));
    await Future<void>.delayed(Duration.zero);
    final String oldPk = mc.nodes
        .firstWhere((DiscoveredNode n) => n.pubKeyHex.startsWith('aa'))
        .pubKeyHex;
    final String newPk = mc.nodes
        .firstWhere((DiscoveredNode n) => n.pubKeyHex.startsWith('bb'))
        .pubKeyHex;
    await mc.toggleFavorite(oldPk);
    await mc.reconcileIdentity(fromPubKeyHex: oldPk, toPubKeyHex: newPk);
    expect(mc.isSuperseded(oldPk), isTrue);

    // The radio still has the dead contact and re-adverts it — must not
    // come back, and must not trigger a backwards prompt on the new key.
    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xAA));
    await Future<void>.delayed(Duration.zero);
    expect(mc.nodes.any((DiscoveredNode n) => n.pubKeyHex == oldPk), isFalse);
    expect(mc.identityMatchFor(newPk), isNull);

    mc.dispose();
  });

  test('identityMatchFor returns null when no side holds data', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = await ready(fake);

    // Two coincidental same-name nodes, neither saved → no nag.
    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xAA));
    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xBB));
    await Future<void>.delayed(Duration.zero);
    for (final DiscoveredNode n in mc.nodes) {
      expect(mc.identityMatchFor(n.pubKeyHex), isNull);
    }

    mc.dispose();
  });

  test('identityMatchFor returns null when names differ', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = await ready(fake);

    fake.emit(advertFrame(name: 'Alice', firstPubByte: 0xAA));
    fake.emit(advertFrame(name: 'Bob', firstPubByte: 0xBB));
    await Future<void>.delayed(Duration.zero);
    for (final DiscoveredNode n in mc.nodes) {
      expect(mc.identityMatchFor(n.pubKeyHex), isNull);
    }

    mc.dispose();
  });
}
