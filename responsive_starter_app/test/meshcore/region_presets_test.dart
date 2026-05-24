// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/region_presets.dart';

void main() {
  group('canonical preset values (community-curated tuples)', () {
    test('USA / Canada is 910.525 MHz / 62.5 kHz / SF7 / CR4-5 / 22 dBm',
        () {
      final RegionPreset p = presetById('us_canada')!;
      expect(p.frequencyMhz, 910.525);
      expect(p.bandwidthKhz, 62.5);
      expect(p.spreadingFactor, 7);
      expect(p.codingRate, 5);
      expect(p.txPowerDbm, 22);
    });

    test('Japan (ARIB STD-T108) is 923.2 MHz / 125 kHz / SF10 / CR4-5 / '
        '13 dBm', () {
      final RegionPreset p = presetById('jp_arib_t108')!;
      expect(p.frequencyMhz, 923.2);
      expect(p.bandwidthKhz, 125);
      expect(p.spreadingFactor, 10);
      expect(p.codingRate, 5);
      expect(p.txPowerDbm, 13);
      expect(p.note, contains('LBT'),
          reason: 'JP note must call out the listen-before-talk '
              'requirement so users do not assume the app enforces it');
    });

    test('every preset has a unique id', () {
      final Set<String> ids = <String>{};
      for (final RegionPreset p in kRegionPresets) {
        expect(ids.add(p.id), isTrue, reason: 'duplicate id ${p.id}');
      }
    });
  });

  group('matchPresetByRadioParams', () {
    test('exact match returns the preset', () {
      final RegionPreset? p = matchPresetByRadioParams(
        frequencyMhz: 910.525,
        bandwidthKhz: 62.5,
        spreadingFactor: 7,
        codingRate: 5,
      );
      expect(p?.id, 'us_canada');
    });

    test('1 kHz frequency wobble still matches (absorbs wire-format '
        'float rounding from uint32 ÷ 1000)', () {
      final RegionPreset? p = matchPresetByRadioParams(
        frequencyMhz: 910.5249,
        bandwidthKhz: 62.5,
        spreadingFactor: 7,
        codingRate: 5,
      );
      expect(p?.id, 'us_canada');
    });

    test('mismatched SF returns null (Custom)', () {
      final RegionPreset? p = matchPresetByRadioParams(
        frequencyMhz: 910.525,
        bandwidthKhz: 62.5,
        spreadingFactor: 10, // wrong
        codingRate: 5,
      );
      expect(p, isNull);
    });
  });

  group('suggestPresetForLatLon (country bounding boxes)', () {
    test('Portland, OR → USA / Canada', () {
      expect(suggestPresetForLatLon(45.523, -122.676)?.id, 'us_canada');
    });

    test('Phoenix, AZ → USA Arizona (narrower box wins over the '
        'continental box)', () {
      expect(suggestPresetForLatLon(33.448, -112.074)?.id,
          'us_arizona');
    });

    test('Toronto, ON → USA / Canada (Canada shares the 902-928 ISM)',
        () {
      expect(suggestPresetForLatLon(43.65, -79.38)?.id, 'us_canada');
    });

    test('Tokyo → Japan ARIB T108', () {
      expect(suggestPresetForLatLon(35.681, 139.767)?.id,
          'jp_arib_t108');
    });

    test('Okinawa → Japan (south end of the box)', () {
      expect(
          suggestPresetForLatLon(26.21, 127.69)?.id, 'jp_arib_t108');
    });

    test('Lisbon → Portugal 869 (narrower box wins over EU/UK)', () {
      expect(suggestPresetForLatLon(38.72, -9.14)?.id, 'pt_869');
    });

    test('Zürich → Switzerland (narrower box wins over EU/UK)', () {
      expect(suggestPresetForLatLon(47.37, 8.55)?.id, 'ch');
    });

    test('Berlin → EU / UK (broad)', () {
      expect(suggestPresetForLatLon(52.52, 13.40)?.id, 'eu_uk_long');
    });

    test('Sydney → Australia', () {
      expect(suggestPresetForLatLon(-33.87, 151.21)?.id, 'au_default');
    });

    test('Auckland → New Zealand', () {
      expect(suggestPresetForLatLon(-36.85, 174.76)?.id, 'nz_default');
    });

    test('mid-Atlantic → null (no shipped preset)', () {
      expect(suggestPresetForLatLon(30.0, -40.0), isNull);
    });
  });
}
