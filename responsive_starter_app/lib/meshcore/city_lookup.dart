// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../util/geo.dart' as geo;

/// R25 Stage 2 — offline reverse-geocoder backed by the packed
/// GeoNames cities15000 dataset (~33 k cities, ~810 KB asset,
/// CC-BY 4.0 — see About screen for attribution).
///
/// Asset is loaded once on first lookup and cached for the rest of
/// the process. Lookups bucket cities by 1° lat × 1° lon cells and
/// scan the nine surrounding buckets, returning the **nearest**
/// city within `radiusMeters` of the query point (or null if none
/// qualifies). Typical lookup over ~30 candidate cities: <1 ms.
///
/// Stage 2 wires this into the equal-grid view to replace
/// grid-coord cell labels with real city/town names. Stage 3 will
/// layer OSM raster tiles underneath; this lookup is independent
/// of either.

class City {
  const City({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.population,
    required this.country,
  });
  final String name;
  final double latitude;
  final double longitude;
  final int population;

  /// Two-letter ISO country code, or `'  '` (two spaces) when the
  /// GeoNames row didn't carry one.
  final String country;
}

/// Singleton-style loader. The first call to [load] reads the
/// bundled `assets/data/cities15000.bin` and builds the bucket
/// index; subsequent calls return the same shared instance.
class CityLookup {
  CityLookup._(this._cities, this._buckets);

  final List<City> _cities;

  /// Cities bucketed by (floor(lat), floor(lon)). Keyed as
  /// `lat * 1000 + lon` to avoid pair allocations.
  final Map<int, List<int>> _buckets;

  static const String _assetPath = 'assets/data/cities15000.bin';
  static const int _magic = 0x35315443; // 'CT15' LE

  static Future<CityLookup>? _loading;
  static CityLookup? _cached;

  /// Returns the shared instance, loading from the bundled asset on
  /// first call. Subsequent calls reuse the cached instance.
  static Future<CityLookup> load() {
    if (_cached != null) return Future<CityLookup>.value(_cached);
    return _loading ??= _loadFromAsset();
  }

  /// Synchronous accessor — returns null if [load] hasn't completed.
  /// Painters call this from `paint()` (which can't be async); when
  /// null, callers fall through to grid-coord placeholders and the
  /// next frame after load completes will show real labels.
  static CityLookup? get cachedOrNull => _cached;

  static Future<CityLookup> _loadFromAsset() async {
    final ByteData raw = await rootBundle.load(_assetPath);
    final Uint8List bytes = raw.buffer.asUint8List(
        raw.offsetInBytes, raw.lengthInBytes);
    final ByteData view = ByteData.sublistView(bytes);
    if (view.getUint32(0, Endian.little) != _magic) {
      throw const FormatException(
          'cities15000.bin: wrong magic (expected CT15)');
    }
    final int count = view.getUint32(4, Endian.little);
    final List<City> cities = <City>[];
    int off = 8;
    for (int i = 0; i < count; i++) {
      final int lat = view.getInt32(off, Endian.little);
      final int lon = view.getInt32(off + 4, Endian.little);
      final int pop = view.getUint32(off + 8, Endian.little);
      final String country = String.fromCharCodes(
          <int>[view.getUint8(off + 12), view.getUint8(off + 13)]);
      final int nameLen = view.getUint8(off + 14);
      final String name =
          utf8.decode(bytes.sublist(off + 15, off + 15 + nameLen));
      cities.add(City(
        name: name,
        latitude: lat / 1e6,
        longitude: lon / 1e6,
        population: pop,
        country: country,
      ));
      off += 15 + nameLen;
    }
    final Map<int, List<int>> buckets = <int, List<int>>{};
    for (int i = 0; i < cities.length; i++) {
      final City c = cities[i];
      final int key = _bucketKey(c.latitude.floor(), c.longitude.floor());
      buckets.putIfAbsent(key, () => <int>[]).add(i);
    }
    final CityLookup inst = CityLookup._(cities, buckets);
    _cached = inst;
    return inst;
  }

  static int _bucketKey(int latFloor, int lonFloor) {
    // Encode signed lat/lon into a single int. lat ∈ [-90, 89], lon ∈
    // [-180, 179]; shift up to non-negative ranges before combining.
    final int la = latFloor + 90; // 0..179
    final int lo = lonFloor + 180; // 0..359
    return la * 360 + lo;
  }

  /// Find the nearest city to (lat, lon) within [radiusMeters].
  /// Returns null when no city in the bundled set qualifies (sparse
  /// regions: ocean, polar, very rural). Ties broken by population
  /// (larger wins), since `City A` and `City B` 100 m apart with the
  /// user landing exactly between them should label as the more
  /// prominent.
  City? nearest({
    required double lat,
    required double lon,
    required double radiusMeters,
  }) {
    final int la = lat.floor();
    final int lo = lon.floor();
    City? best;
    double bestDist = double.infinity;
    int bestPop = -1;
    for (int dla = -1; dla <= 1; dla++) {
      for (int dlo = -1; dlo <= 1; dlo++) {
        // Longitude wraps at ±180. Skip OOB latitude (no buckets
        // past the poles).
        final int laN = la + dla;
        if (laN < -90 || laN > 89) continue;
        int loN = lo + dlo;
        if (loN < -180) loN += 360;
        if (loN > 179) loN -= 360;
        final List<int>? bucket =
            _buckets[_bucketKey(laN, loN)];
        if (bucket == null) continue;
        for (final int idx in bucket) {
          final City c = _cities[idx];
          final double d = geo.haversineMeters(
              lat, lon, c.latitude, c.longitude);
          if (d > radiusMeters) continue;
          if (d < bestDist || (d == bestDist && c.population > bestPop)) {
            best = c;
            bestDist = d;
            bestPop = c.population;
          }
        }
      }
    }
    return best;
  }

  /// Total city count loaded — for diagnostics / "About" attribution.
  int get cityCount => _cities.length;
}

/// Pre-warm the city lookup. Call once from app launch so first-
/// frame-after-load isn't blocked on the parse. Safe to call
/// multiple times — the second call hits the in-flight Future.
Future<void> warmCityLookup() async {
  try {
    await CityLookup.load();
  } catch (e) {
    // Asset missing or corrupt — log and degrade. The grid view
    // will fall through to coord-based cell labels.
    // ignore: avoid_print
    print('[city_lookup] warm failed: $e');
  }
}

/// Used by the equal-grid painter: pick a sensible label for the
/// cell at (centreLat, centreLon) of the given size. Looks up the
/// nearest city within half the cell's diagonal so the label is
/// always "a city whose centroid lies inside this cell".
String? labelForCell({
  required double centreLat,
  required double centreLon,
  required double cellSizeMeters,
}) {
  final CityLookup? lookup = CityLookup.cachedOrNull;
  if (lookup == null) return null;
  // Half-diagonal of the cell — anything farther wouldn't be
  // visually inside the cell from any rendering angle.
  final double radius =
      cellSizeMeters * math.sqrt(2.0) / 2.0;
  return lookup
      .nearest(lat: centreLat, lon: centreLon, radiusMeters: radius)
      ?.name;
}
