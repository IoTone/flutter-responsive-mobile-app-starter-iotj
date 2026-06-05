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

  test('a new place is held with a last-hour count of 1', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Seattle'), now: t0);
    final List<InferredMarker> cur = s.current(now: t0);
    expect(cur, hasLength(1));
    expect(cur.first.place.anchorName, 'Seattle');
    expect(cur.first.recentCount, 1);
  });

  test('repeat mentions raise the count and confidence', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Seattle', conf: 0.82), now: t0);
    s.add(_p('Seattle', conf: 0.82), now: t0.add(const Duration(minutes: 5)));
    s.add(_p('Seattle', conf: 0.82), now: t0.add(const Duration(minutes: 9)));
    final InferredMarker m = s.current(now: t0.add(const Duration(minutes: 9)))
        .single;
    expect(m.recentCount, 3);
    expect(m.confidence, greaterThan(0.82)); // reinforced
  });

  test('same anchor with a different bearing is a distinct marker', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Seattle', bearing: null), now: t0);
    s.add(_p('Seattle', bearing: 270), now: t0); // "west of Seattle"
    expect(s.current(now: t0), hasLength(2));
  });

  test('mentions outside the 1-hour window are not counted', () {
    final InferredPlaceStore s =
        InferredPlaceStore(window: const Duration(hours: 1));
    s.add(_p('Tacoma'), now: t0);
    s.add(_p('Tacoma'), now: t0.add(const Duration(minutes: 30)));
    // 90 min after the first → only the 2nd (60 min ago) is in-window.
    final List<InferredMarker> cur =
        s.current(now: t0.add(const Duration(minutes: 90)));
    expect(cur.single.recentCount, 1);
  });

  test('a marker drops out once it has no mention in the window', () {
    final InferredPlaceStore s =
        InferredPlaceStore(window: const Duration(hours: 1));
    s.add(_p('Tacoma'), now: t0);
    expect(s.current(now: t0.add(const Duration(minutes: 59))), hasLength(1));
    expect(s.current(now: t0.add(const Duration(minutes: 61))), isEmpty);
  });

  test('current() is sorted strongest-first', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Olympia', conf: 0.81), now: t0);
    s.add(_p('Seattle', conf: 0.95), now: t0);
    expect(s.current(now: t0).first.place.anchorName, 'Seattle');
  });

  test('dismiss removes a single marker by key', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Seattle'), now: t0);
    s.add(_p('Tacoma'), now: t0);
    final InferredMarker seattle = s
        .current(now: t0)
        .firstWhere((InferredMarker m) => m.place.anchorName == 'Seattle');
    s.dismiss(seattle.key);
    final List<InferredMarker> left = s.current(now: t0);
    expect(left, hasLength(1));
    expect(left.single.place.anchorName, 'Tacoma');
  });

  test('clear empties the store', () {
    final InferredPlaceStore s = InferredPlaceStore();
    s.add(_p('Seattle'), now: t0);
    s.clear();
    expect(s.isEmpty, isTrue);
  });
}
