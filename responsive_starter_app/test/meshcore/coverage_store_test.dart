// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/coverage_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('F8 CoverageStore', () {
    test('bucketFor groups nearby points into the same cell', () {
      // Two points within ~50m at 45° latitude should fall into the
      // same 0.002° bucket.
      final b1 = CoverageStore.bucketFor(45.5152, -122.6784);
      final b2 = CoverageStore.bucketFor(45.5153, -122.6783);
      expect(b1.latBucket, b2.latBucket);
      expect(b1.lonBucket, b2.lonBucket);

      // Points ~5 km apart go into different cells.
      final b3 = CoverageStore.bucketFor(45.5152, -122.6784);
      final b4 = CoverageStore.bucketFor(45.5600, -122.6500);
      expect(b3 == b4, isFalse);
    });

    test('cellKey + parseKey round-trip', () {
      const String k = '22756,-61339';
      final ({int latBucket, int lonBucket})? parsed =
          CoverageStore.parseKey(k);
      expect(parsed, isNotNull);
      expect(parsed!.latBucket, 22756);
      expect(parsed.lonBucket, -61339);
      expect(CoverageStore.cellKey(parsed.latBucket, parsed.lonBucket),
          k);
    });

    test('parseKey returns null for malformed input', () {
      expect(CoverageStore.parseKey(''), isNull);
      expect(CoverageStore.parseKey('123'), isNull);
      expect(CoverageStore.parseKey('abc,xyz'), isNull);
      expect(CoverageStore.parseKey('123,'), isNull);
      expect(CoverageStore.parseKey(',456'), isNull);
    });

    test('save + load round-trips with a non-trivial map', () async {
      final Map<String, int> in1 = <String, int>{
        '22756,-61339': 1716240000,
        '22756,-61338': 1716240100,
        '22757,-61339': 1716240200,
      };
      await CoverageStore.save(in1);
      final Map<String, int> back = await CoverageStore.load();
      expect(back, in1);
    });

    test('empty prefs → empty map', () async {
      expect(await CoverageStore.load(), isEmpty);
    });

    test('corrupt blob → empty map (no crash)', () async {
      final SharedPreferences p =
          await SharedPreferences.getInstance();
      await p.setString('mm.coverage.v1', '{not json');
      expect(await CoverageStore.load(), isEmpty);
    });

    test('cellCentre is the geographic centre of the bucket', () {
      // For bucket (22756, -61339), origin is at lat=22756*cellDeg,
      // lon=-61339*cellDeg; centre is +cellDeg/2 in each.
      final ({double lat, double lon}) c =
          CoverageStore.cellCentre(22756, -61339);
      expect(c.lat,
          closeTo(22756 * CoverageStore.cellDeg + CoverageStore.cellDeg / 2,
              1e-9));
      expect(c.lon,
          closeTo(-61339 * CoverageStore.cellDeg + CoverageStore.cellDeg / 2,
              1e-9));
    });
  });
}
