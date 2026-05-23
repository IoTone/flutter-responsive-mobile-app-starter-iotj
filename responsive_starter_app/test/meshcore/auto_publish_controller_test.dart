// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/auto_publish_controller.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/perms/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_transport.dart';

/// R36 — AutoPublishController.
///
/// We exercise the two trigger paths (periodic + smart-broadcast)
/// through the controller's public API and assert that each one
/// emits the expected on-the-wire frames: SET_ADVERT_LATLON (0x0E)
/// + SEND_SELF_ADVERT (0x07 with flood-flag 0).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({MeshcoreController mc, FakeMeshcoreTransport fake})>
      bringControllerReady() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    await mc.connect();
    fake.emit(selfInfoFrame());
    await Future<void>.delayed(Duration.zero);
    return (mc: mc, fake: fake);
  }

  bool has0E(FakeMeshcoreTransport f) =>
      f.sent.any((List<int> b) => b.isNotEmpty && b[0] == 0x0E);
  bool has07Flood0(FakeMeshcoreTransport f) =>
      f.sent.any((List<int> b) =>
          b.length >= 2 && b[0] == 0x07 && b[1] == 0x00);

  test('publishNow emits SET_ADVERT_LATLON (0x0E) + zero-hop '
      'SEND_SELF_ADVERT (0x07 flood=0)', () async {
    final r = await bringControllerReady();
    final NoopLocationService loc = NoopLocationService(
        next: const PhoneFix(latitude: 35.681, longitude: 139.767));
    final AutoPublishController ap =
        AutoPublishController(mc: r.mc, location: loc);
    await ap.load();
    await ap.setEnabled(true);

    // Master toggle on but no triggers configured: publishNow should
    // still produce one publish cycle.
    final int before0E = r.fake.sent.where((b) => b[0] == 0x0E).length;
    final int before07 = r.fake.sent.where((b) => b[0] == 0x07).length;
    await ap.publishNow();
    await Future<void>.delayed(Duration.zero);

    expect(
        r.fake.sent.where((b) => b[0] == 0x0E).length, before0E + 1,
        reason: 'publishNow should write lat/lon to the device once');
    expect(
        r.fake.sent.where((b) => b[0] == 0x07).length, before07 + 1,
        reason: 'publishNow should re-advert exactly once');
    expect(has07Flood0(r.fake), isTrue,
        reason: 'auto-publish must be zero-hop (flood=0)');
    expect(ap.lastLat, closeTo(35.681, 1e-9));
    expect(ap.lastTrigger, 'manual');

    ap.dispose();
    r.mc.dispose();
  });

  test('publishNow is a no-op when master toggle is off', () async {
    final r = await bringControllerReady();
    final NoopLocationService loc = NoopLocationService(
        next: const PhoneFix(latitude: 1.0, longitude: 2.0));
    final AutoPublishController ap =
        AutoPublishController(mc: r.mc, location: loc);
    await ap.load();
    // _enabled stays false.

    final int before = r.fake.sent.length;
    await ap.publishNow();
    expect(r.fake.sent.length, before,
        reason: 'disabled controller must not touch the wire');
    expect(loc.callCount, 0,
        reason: 'disabled controller must not even read GPS');

    ap.dispose();
    r.mc.dispose();
  });

  test('movement stream triggers a publish using the streamed fix '
      '(no extra currentFix call)', () async {
    final r = await bringControllerReady();
    final NoopLocationService loc = NoopLocationService();
    final AutoPublishController ap =
        AutoPublishController(mc: r.mc, location: loc);
    await ap.load();
    await ap.setEnabled(true);
    await ap.setMinMovementMeters(200);
    expect(loc.lastDistanceFilter, 200);

    loc.emit(const PhoneFix(latitude: 45.5, longitude: -122.7));
    // Stream is async — settle.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(has0E(r.fake), isTrue);
    expect(has07Flood0(r.fake), isTrue);
    expect(loc.callCount, 0,
        reason: 'streamed fix is reused; no one-shot currentFix needed');
    expect(ap.lastTrigger, 'movement');

    ap.dispose();
    r.mc.dispose();
  });

  test('settings persist across instances', () async {
    final r = await bringControllerReady();
    final NoopLocationService loc = NoopLocationService();
    final AutoPublishController a =
        AutoPublishController(mc: r.mc, location: loc);
    await a.load();
    await a.setEnabled(true);
    await a.setIntervalSec(900);
    await a.setMinMovementMeters(500);
    a.dispose();

    final AutoPublishController b =
        AutoPublishController(mc: r.mc, location: loc);
    await b.load();
    expect(b.enabled, isTrue);
    expect(b.intervalSec, 900);
    expect(b.minMovementMeters, 500);
    b.dispose();
    r.mc.dispose();
  });
}
