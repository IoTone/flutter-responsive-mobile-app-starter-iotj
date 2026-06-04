// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/sns/inferred_place_store.dart';
import 'package:meshmore_sns_app/sns/place_inference.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../meshcore/fake_transport.dart';

/// Gazetteer with one in-region city near the test's self location.
class _Gaz implements PlaceGazetteer {
  @override
  List<GazPlace> lookup(String name) => name.toLowerCase() == 'seattle'
      ? const <GazPlace>[
          GazPlace(
              name: 'Seattle',
              latitude: 47.6062,
              longitude: -122.3321,
              population: 750000),
        ]
      : const <GazPlace>[];
}

Future<(MeshcoreController, FakeMeshcoreTransport)> _located(
    {bool withFix = true}) async {
  final FakeMeshcoreTransport fake = FakeMeshcoreTransport();
  final MeshcoreController ctrl = MeshcoreController(
    transportFactory: () async => fake,
    connection:
        MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    placeInferenceEngine: PlaceInferenceEngine(gazetteer: _Gaz()),
  );
  await ctrl.connect();
  fake.emit(withFix
      ? selfInfoFrameAt(lat: 47.61, lon: -122.33)
      : selfInfoFrame()); // (0,0) → unlocated
  await Future<void>.delayed(Duration.zero);
  return (ctrl, fake);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('channel banter on the public channel plots an inferred place',
      () async {
    final (MeshcoreController, FakeMeshcoreTransport) r = await _located();
    r.$2.emit(channelMsgFrame(idx: 0, text: 'Hello from Seattle, 73'));
    await Future<void>.delayed(Duration.zero);

    final List<InferredMarker> places = r.$1.inferredPlaces();
    expect(places, isNotEmpty);
    expect(places.first.place.anchorName, 'Seattle');
  });

  test('disabled channel is not scanned', () async {
    final (MeshcoreController, FakeMeshcoreTransport) r = await _located();
    await r.$1.setPlaceInferenceEnabled(0, false);
    r.$2.emit(channelMsgFrame(idx: 0, text: 'Hello from Seattle'));
    await Future<void>.delayed(Duration.zero);
    expect(r.$1.inferredPlaces(), isEmpty);
  });

  test('a non-public channel is off by default', () async {
    final (MeshcoreController, FakeMeshcoreTransport) r = await _located();
    r.$2.emit(channelMsgFrame(idx: 2, text: 'Hello from Seattle'));
    await Future<void>.delayed(Duration.zero);
    expect(r.$1.inferredPlaces(), isEmpty);
    // ...but enabling it makes it scan.
    await r.$1.setPlaceInferenceEnabled(2, true);
    r.$2.emit(channelMsgFrame(idx: 2, text: 'Hello from Seattle'));
    await Future<void>.delayed(Duration.zero);
    expect(r.$1.inferredPlaces(), isNotEmpty);
  });

  test('no inference without a known location', () async {
    final (MeshcoreController, FakeMeshcoreTransport) r =
        await _located(withFix: false);
    r.$2.emit(channelMsgFrame(idx: 0, text: 'Hello from Seattle'));
    await Future<void>.delayed(Duration.zero);
    expect(r.$1.inferredPlaces(), isEmpty);
  });

  test('clearInferredPlaces empties the store', () async {
    final (MeshcoreController, FakeMeshcoreTransport) r = await _located();
    r.$2.emit(channelMsgFrame(idx: 0, text: 'Hello from Seattle'));
    await Future<void>.delayed(Duration.zero);
    expect(r.$1.inferredPlaces(), isNotEmpty);
    r.$1.clearInferredPlaces();
    expect(r.$1.inferredPlaces(), isEmpty);
  });
}
