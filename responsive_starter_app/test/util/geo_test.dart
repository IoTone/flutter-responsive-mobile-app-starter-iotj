import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/util/geo.dart';

void main() {
  test('haversine NYC ↔ LA ≈ 3935 km (within 0.5%)', () {
    // NYC = (40.7128, -74.0060), LA = (34.0522, -118.2437)
    final double m =
        haversineMeters(40.7128, -74.0060, 34.0522, -118.2437);
    final double km = m / 1000.0;
    expect(km, inInclusiveRange(3915, 3955));
  });

  test('haversine zero distance is exactly 0', () {
    expect(haversineMeters(37.0, -122.0, 37.0, -122.0), 0);
  });

  test('formatDistance picks meters then km', () {
    expect(formatDistance(0), '≈ 0 m');
    expect(formatDistance(124), '≈ 120 m');
    expect(formatDistance(999), '≈ 1000 m');
    expect(formatDistance(1000), '≈ 1.0 km');
    expect(formatDistance(2530), '≈ 2.5 km');
    expect(formatDistance(15600), '≈ 16 km');
    expect(formatDistance(null), isNull);
    expect(formatDistance(double.nan), isNull);
  });

  test('bearing north → 0, east → π/2 (approx)', () {
    // 1° north of origin.
    final double bN = bearingRadians(0, 0, 1, 0);
    expect(bN, closeTo(0.0, 1e-6));
    // 1° east of origin (slightly off π/2 at the equator due to
    // initial-bearing definition, but very close).
    final double bE = bearingRadians(0, 0, 0, 1);
    expect(bE, closeTo(1.5707963, 1e-4));
  });
}
