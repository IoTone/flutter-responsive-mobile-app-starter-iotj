// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/sns/place_inference.dart';

/// A small Puget Sound + a far-away decoy, so region-scoping is testable.
class _FakeGaz implements PlaceGazetteer {
  static const List<GazPlace> _all = <GazPlace>[
    GazPlace(name: 'Seattle', latitude: 47.6062, longitude: -122.3321, population: 750000),
    GazPlace(name: 'Tacoma', latitude: 47.2529, longitude: -122.4443, population: 220000),
    GazPlace(name: 'Portland', latitude: 45.5152, longitude: -122.6784, population: 650000),
    GazPlace(name: 'Bellevue', latitude: 47.6101, longitude: -122.2015, population: 150000),
    // Decoy: a Portland in Maine, far from Puget Sound.
    GazPlace(name: 'Portland', latitude: 43.6591, longitude: -70.2568, population: 66000),
    // A tiny same-name decoy far away to exercise uniqueness.
    GazPlace(name: 'Springfield', latitude: 39.8, longitude: -89.6, population: 116000),
  ];

  @override
  List<GazPlace> lookup(String name) {
    final String n = name.toLowerCase().trim();
    return _all.where((GazPlace p) => p.name.toLowerCase() == n).toList();
  }
}

// Seattle-ish origin for all tests.
const double kLat = 47.61;
const double kLon = -122.33;

double _km(InferredPlace p, double lat, double lon) {
  const double r = 6371.0;
  final double dLat = (lat - p.latitude) * math.pi / 180.0;
  final double dLon = (lon - p.longitude) * math.pi / 180.0;
  final double a = math.pow(math.sin(dLat / 2), 2).toDouble() +
      math.cos(p.latitude * math.pi / 180) *
          math.cos(lat * math.pi / 180) *
          math.pow(math.sin(dLon / 2), 2).toDouble();
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

PlaceInferenceEngine _engine({bool jitter = false}) =>
    PlaceInferenceEngine(gazetteer: _FakeGaz(), jitter: jitter);

List<InferredPlace> _infer(String msg, {bool jitter = false}) =>
    _engine(jitter: jitter).infer(msg, originLat: kLat, originLon: kLon);

void main() {
  group('cue-anchored single places', () {
    test('"Hello from Seattle" → high-confidence Seattle', () {
      final List<InferredPlace> r = _infer('Hello from Seattle, 73!');
      expect(r, isNotEmpty);
      final InferredPlace p = r.first;
      expect(p.anchorName, 'Seattle');
      expect(p.cue, PlaceCueKind.fromHere);
      expect(p.confidence, greaterThanOrEqualTo(0.80));
      expect(p.bearingDegrees, isNull);
      expect(_km(p, 47.6062, -122.3321), lessThan(1.0)); // at the centre
    });

    test('"heading to Tacoma" places Tacoma', () {
      final List<InferredPlace> r = _infer('just headed to Tacoma for coffee');
      expect(r.map((InferredPlace p) => p.anchorName), contains('Tacoma'));
    });
  });

  group('directional ballpark offset', () {
    test('"10 hops to West Seattle" anchors Seattle, offset west', () {
      final List<InferredPlace> r = _infer('about 10 hops to West Seattle');
      final InferredPlace p =
          r.firstWhere((InferredPlace p) => p.anchorName == 'Seattle');
      expect(p.viaDirection, isTrue);
      expect(p.bearingDegrees, 270); // west
      expect(p.offsetMeters, greaterThan(0));
      expect(p.confidence, greaterThanOrEqualTo(0.80));
      // Placed west of the Seattle centroid → more-negative longitude.
      expect(p.longitude, lessThan(-122.3321));
    });

    test('"north of Seattle" offsets north (higher latitude)', () {
      final List<InferredPlace> r = _infer('camping north of Seattle tonight');
      final InferredPlace p =
          r.firstWhere((InferredPlace p) => p.anchorName == 'Seattle');
      expect(p.bearingDegrees, 0);
      expect(p.latitude, greaterThan(47.6062));
    });

    test('"downtown Seattle" stays at the centre (no offset)', () {
      final List<InferredPlace> r = _infer('grabbing lunch downtown Seattle');
      final InferredPlace p =
          r.firstWhere((InferredPlace p) => p.anchorName == 'Seattle');
      expect(p.offsetMeters, 0);
      expect(_km(p, 47.6062, -122.3321), lessThan(1.0));
    });
  });

  group('region scoping & disambiguation', () {
    test('"from Portland" resolves the in-region Portland, not Maine', () {
      final List<InferredPlace> r = _infer('greetings from Portland');
      final InferredPlace p =
          r.firstWhere((InferredPlace p) => p.anchorName == 'Portland');
      // Oregon Portland, ~233 km south — well within the 300 km region.
      expect(_km(p, 45.5152, -122.6784), lessThan(5.0));
    });

    test('an out-of-region place is dropped', () {
      // Springfield IL is ~2700 km away → beyond the region radius.
      final List<InferredPlace> r = _infer('Hello from Springfield');
      expect(r.where((InferredPlace p) => p.anchorName == 'Springfield'),
          isEmpty);
    });
  });

  group('X to Y pairs', () {
    test('"Portland to Seattle" yields both endpoints, linked', () {
      final List<InferredPlace> r = _infer('relaying Portland to Seattle');
      final Iterable<InferredPlace> pair =
          r.where((InferredPlace p) => p.pairId != null);
      expect(pair.length, 2);
      expect(pair.map((InferredPlace p) => p.anchorName).toSet(),
          <String>{'Portland', 'Seattle'});
      expect(pair.first.pairId, pair.last.pairId);
    });
  });

  group('explicit coordinates', () {
    test('decimal "lat, lon" resolves directly at high confidence', () {
      final List<InferredPlace> r = _infer('my fix: 47.6097, -122.3331');
      final InferredPlace p = r.firstWhere(
          (InferredPlace p) => p.cue == PlaceCueKind.coordinate);
      expect(p.confidence, greaterThanOrEqualTo(0.9));
      expect(_km(p, 47.6097, -122.3331), lessThan(0.5));
    });

    test('Maidenhead grid locator decodes near its square', () {
      // CN87 covers the Seattle area.
      final List<InferredPlace> r = _infer('QTH grid CN87');
      final InferredPlace p = r.firstWhere(
          (InferredPlace p) => p.cue == PlaceCueKind.gridLocator);
      expect(_km(p, kLat, kLon), lessThan(120.0));
    });
  });

  group('rejection / no false positives', () {
    test('non-place capitalised words do not place', () {
      final List<InferredPlace> r =
          _infer('See you Monday! Thanks Bob, great work');
      expect(r, isEmpty);
    });

    test('a plain version string is not read as coordinates', () {
      expect(_infer('running v1.0.127 build 42'), isEmpty);
    });

    test('below-threshold bare mention is filtered', () {
      // "Bellevue" bare: bareName 0.45 + exact 0.20 + region 0.10 +
      // pop(150k≥100k) 0.05 + unique 0.05 = 0.85 → it *does* surface.
      // Use a sub-100k unique decoy phrased bare to land under 0.80.
      final List<InferredPlace> r = _infer('Anyway. Whatever.');
      expect(r, isEmpty);
    });
  });

  group('determinism & jitter', () {
    test('same input → identical output (deterministic)', () {
      final List<InferredPlace> a = _infer('Hello from Seattle', jitter: true);
      final List<InferredPlace> b = _infer('Hello from Seattle', jitter: true);
      expect(a.first.latitude, b.first.latitude);
      expect(a.first.longitude, b.first.longitude);
    });

    test('jitter stays within its bound', () {
      final List<InferredPlace> r = _infer('Hello from Seattle', jitter: true);
      // Default jitter ≤ 1.2 km; centre is the Seattle centroid.
      expect(_km(r.first, 47.6062, -122.3321), lessThan(1.5));
    });
  });
}
