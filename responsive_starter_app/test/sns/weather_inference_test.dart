// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/sns/weather_inference.dart';
import 'package:meshmore_sns_app/sns/weather_lexicon.dart';

WxObservation? scanEn(String t) =>
    WeatherInferenceEngine.scan(t, languageCode: 'en');
WxObservation? scanJa(String t) =>
    WeatherInferenceEngine.scan(t, languageCode: 'ja');

void main() {
  group('temperature parsing (→ °C)', () {
    test('degree forms', () {
      expect(parseTemperaturesC('28°C here'), <double>[28]);
      expect(parseTemperaturesC('it is 28°'), <double>[28]);
      expect(parseTemperaturesC('28 degrees'), <double>[28]);
      expect(parseTemperaturesC('28度'), <double>[28]);
    });
    test('fahrenheit converts', () {
      final List<double> v = parseTemperaturesC('72°F');
      expect(v.single, closeTo(22.2, 0.1));
    });
    test('ranges capture both ends', () {
      expect(parseTemperaturesC('18–22°C'), <double>[18, 22]);
    });
    test('bare numbers are NOT temperatures', () {
      expect(parseTemperaturesC('meet at 28 by the dock'), isEmpty);
      expect(parseTemperaturesC('channel 5'), isEmpty);
    });
  });

  group('condition scanning (EN)', () {
    test('concrete conditions', () {
      expect(scanEn('raining hard out here')!.conditions,
          contains(WxCondition.rain));
      expect(scanEn('thick fog on the ridge')!.conditions,
          contains(WxCondition.fog));
      expect(scanEn('clear blue sky today')!.conditions,
          contains(WxCondition.clear));
    });
    test('word boundaries — "sunday" is not "sun"', () {
      expect(scanEn('see you sunday'), isNull);
    });
    test('negation suppresses', () {
      expect(scanEn('no rain so far'), isNull);
      expect(scanEn("it isn't raining"), isNull);
    });
    test('temperature alone is an observation', () {
      final WxObservation o = scanEn('about 31°C')!;
      expect(o.temperatureC, closeTo(31, 0.01));
      expect(o.conditions, isEmpty);
    });
    test('condition + temp reads with higher confidence', () {
      final WxObservation o = scanEn('hot, like 34°C')!;
      expect(o.conditions, contains(WxCondition.heat));
      expect(o.temperatureC, closeTo(34, 0.01));
      expect(o.confidence, greaterThan(0.8));
    });
    test('emoji counts', () {
      expect(scanEn('heading out ☀')!.conditions, contains(WxCondition.clear));
    });
    test('non-weather text yields nothing', () {
      expect(scanEn('on my way to the meetup'), isNull);
    });
  });

  group('condition scanning (JA)', () {
    test('rain / clear / hot', () {
      expect(scanJa('今日は雨です')!.conditions, contains(WxCondition.rain));
      expect(scanJa('晴れてきた')!.conditions, contains(WxCondition.clear));
      expect(scanJa('暑い')!.conditions, contains(WxCondition.heat));
    });
    test('JA negation (trailing) suppresses', () {
      expect(scanJa('雨じゃない'), isNull);
    });
    test('JA temperature', () {
      expect(scanJa('今 28度')!.temperatureC, closeTo(28, 0.01));
    });
  });

  group('aggregateAmbient', () {
    final DateTime t0 = DateTime(2026, 6, 6, 12);
    test('empty → null', () {
      expect(aggregateAmbient(const <WxObservation>[]), isNull);
    });
    test('dominant condition + temp stats', () {
      final List<WxObservation> obs = <WxObservation>[
        WeatherInferenceEngine.scan('raining', languageCode: 'en', at: t0)!,
        WeatherInferenceEngine.scan('still rain, 19°C', languageCode: 'en', at: t0)!,
        WeatherInferenceEngine.scan('sunny now 24°C', languageCode: 'en', at: t0.add(const Duration(minutes: 5)))!,
      ];
      final AmbientWx a = aggregateAmbient(obs)!;
      expect(a.dominant, WxCondition.rain); // 2 rain vs 1 clear
      expect(a.mentions, 3);
      expect(a.tempMinC, closeTo(19, 0.01));
      expect(a.tempMaxC, closeTo(24, 0.01));
      expect(a.lastSeen, t0.add(const Duration(minutes: 5)));
    });
    test('temperature-only observations → null dominant but temps set', () {
      final AmbientWx a = aggregateAmbient(<WxObservation>[
        WeatherInferenceEngine.scan('30°C', languageCode: 'en', at: t0)!,
      ])!;
      expect(a.dominant, isNull);
      expect(a.tempAvgC, closeTo(30, 0.01));
    });
  });

  group('scanAny (multi-locale)', () {
    test('merges EN + JA conditions in one message', () {
      final WxObservation? o = WeatherInferenceEngine.scanAny('雨 and hot');
      expect(o, isNotNull);
      expect(o!.conditions,
          containsAll(<WxCondition>[WxCondition.rain, WxCondition.heat]));
    });
    test('null when neither locale matches', () {
      expect(WeatherInferenceEngine.scanAny('see you at the dock'), isNull);
    });
  });

  group('aggregateMicroclimates (P2)', () {
    final DateTime t0 = DateTime(2026, 6, 7, 12);
    WxObservation at(double lat, double lon, Set<WxCondition> c,
            {double? temp, String? name}) =>
        WxObservation(
                conditions: c,
                temperatureC: temp,
                confidence: 0.8,
                at: t0)
            .locatedAt(lat, lon, name);

    test('clusters nearby obs into one place; dominant + temp + count', () {
      final List<Microclimate> climates = aggregateMicroclimates(
        <WxObservation>[
          at(47.60, -122.33, <WxCondition>{WxCondition.rain},
              temp: 18, name: 'Seattle'),
          at(47.61, -122.34, <WxCondition>{WxCondition.rain},
              temp: 20, name: 'Seattle'),
          at(45.52, -122.67, <WxCondition>{WxCondition.clear},
              temp: 25, name: 'Portland'),
        ],
      );
      expect(climates.length, 2);
      final Microclimate seattle =
          climates.firstWhere((Microclimate m) => m.placeName == 'Seattle');
      expect(seattle.dominant, WxCondition.rain);
      expect(seattle.mentions, 2);
      expect(seattle.tempMinC, closeTo(18, 0.01));
      expect(seattle.tempMaxC, closeTo(20, 0.01));
      expect(climates.first.mentions, 2); // strongest first
    });

    test('unlocated observations are ignored', () {
      expect(
          aggregateMicroclimates(<WxObservation>[
            WeatherInferenceEngine.scan('raining', languageCode: 'en')!,
          ]),
          isEmpty);
    });
  });
}
