// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/sns/inferred_place_store.dart';
import 'package:meshmore_sns_app/sns/place_inference.dart';

InferredPlace _p(
  String anchor, {
  double conf = 0.85,
  double? bearing,
  double lat = 47.6,
  double lon = -122.3,
}) =>
    InferredPlace(
      displayName: anchor,
      anchorName: anchor,
      latitude: lat,
      longitude: lon,
      confidence: conf,
      cue: PlaceCueKind.fromHere,
      sourceSpan: 'from $anchor',
      bearingDegrees: bearing,
    );

void main() {
  final DateTime t0 = DateTime(2026, 6, 4, 12);

  test('a new place is held and returned', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Seattle'), now: t0);
    final List<InferredMarker> cur = s.current(now: t0);
    expect(cur, hasLength(1));
    expect(cur.first.place.anchorName, 'Seattle');
    expect(cur.first.mentions, 1);
  });

  test('repeat mentions reinforce (mentions++, confidence up, TTL reset)', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Seattle', conf: 0.82), now: t0);
    s.add(_p('Seattle', conf: 0.82), now: t0.add(const Duration(minutes: 5)));
    final InferredMarker m = s.current(now: t0).single;
    expect(m.mentions, 2);
    expect(m.confidence, greaterThan(0.82)); // reinforced
  });

  test('same anchor with a different bearing is a distinct marker', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Seattle', bearing: null), now: t0);
    s.add(_p('Seattle', bearing: 270), now: t0); // "west of Seattle"
    expect(s.current(now: t0), hasLength(2));
  });

  test('markers expire after the TTL with no new mention', () {
    final InferredPlaceStore s =
        InferredPlaceStore(ttl: const Duration(minutes: 45));
    s.add(_p('Tacoma'), now: t0);
    expect(s.current(now: t0.add(const Duration(minutes: 44))), hasLength(1));
    expect(s.current(now: t0.add(const Duration(minutes: 46))), isEmpty);
  });

  test('a fresh mention keeps a marker alive past the original TTL', () {
    final InferredPlaceStore s =
        InferredPlaceStore(ttl: const Duration(minutes: 45));
    s.add(_p('Tacoma'), now: t0);
    s.add(_p('Tacoma'), now: t0.add(const Duration(minutes: 40)));
    // 50 min after t0 but only 10 min after the refresh → still live.
    expect(s.current(now: t0.add(const Duration(minutes: 50))), hasLength(1));
  });

  test('current() is sorted strongest-first', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Olympia', conf: 0.81), now: t0);
    s.add(_p('Seattle', conf: 0.95), now: t0);
    expect(s.current(now: t0).first.place.anchorName, 'Seattle');
  });

  test('clear empties the store', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Seattle'), now: t0);
    s.clear();
    expect(s.isEmpty, isTrue);
  });
}
