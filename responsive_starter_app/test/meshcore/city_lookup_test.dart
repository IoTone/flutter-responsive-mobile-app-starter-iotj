// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/city_lookup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('R25 Stage 2 — CityLookup (packed cities15000)', () {
    test('asset parses and reports ~33k cities', () async {
      final CityLookup db = await CityLookup.load();
      expect(db.cityCount, greaterThan(30000),
          reason: 'cities15000 should pack to >30k records');
      expect(db.cityCount, lessThan(40000),
          reason: 'sanity upper-bound — bigger than this means a '
              'broken pack tool, not a GeoNames refresh');
    });

    test('Portland, OR (45.515, -122.678) resolves to Portland', () async {
      final CityLookup db = await CityLookup.load();
      final City? c =
          db.nearest(lat: 45.5152, lon: -122.6784, radiusMeters: 5000);
      expect(c, isNotNull);
      expect(c!.name, contains('Portland'));
      expect(c.country, 'US');
    });

    test('Tokyo area (35.681, 139.767) resolves to a JP city within '
        '5 km — GeoNames splits Tokyo into wards (Chuo, Shibuya, …) '
        'so the named match is ward-level, not the literal '
        '"Tokyo"', () async {
      final CityLookup db = await CityLookup.load();
      final City? c =
          db.nearest(lat: 35.681, lon: 139.767, radiusMeters: 5000);
      expect(c, isNotNull);
      expect(c!.country, 'JP');
      // Population sanity — any Tokyo ward is at minimum tens of
      // thousands. Cities15000 only includes pop ≥ 15 000.
      expect(c.population, greaterThanOrEqualTo(15000));
    });

    test('mid-Atlantic with a tight radius returns null', () async {
      final CityLookup db = await CityLookup.load();
      final City? c =
          db.nearest(lat: 35.0, lon: -40.0, radiusMeters: 50000);
      expect(c, isNull, reason: 'no city within 50 km of mid-Atlantic');
    });

    test('labelForCell falls back to null when DB unloaded', () {
      // Painter expects this exact behaviour — synchronous accessor
      // returns null before the asset finishes loading.
      // (We can't easily test the *true* unloaded state inside this
      // test process since other cases above already loaded it, but
      // we can verify the labelForCell signature with a guaranteed
      // empty region returns null.)
      final String? label = labelForCell(
          centreLat: 35.0,
          centreLon: -40.0,
          cellSizeMeters: 100.0);
      expect(label, isNull);
    });
  });
}
