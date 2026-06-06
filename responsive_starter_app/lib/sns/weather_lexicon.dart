// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT

/// Microclimate / "wx" — weather conditions recognised in chat (P1).
///
/// The device's environment telemetry is shelved (most field firmware
/// reports none), so we mine weather from what people *say* on channel.
/// This file is the pure, offline, per-language lexicon + temperature
/// parser the [WeatherInferenceEngine] runs over message text. No UI
/// strings here — these are matcher inputs (see `weather_inference.dart`).
library;

enum WxCondition { clear, clouds, fog, rain, snow, wind, storm, heat, cold }

/// A glanceable glyph per condition (locale-independent).
String wxGlyph(WxCondition c) => switch (c) {
      WxCondition.clear => '☀',
      WxCondition.clouds => '☁',
      WxCondition.fog => '🌫',
      WxCondition.rain => '🌧',
      WxCondition.snow => '❄',
      WxCondition.wind => '🌬',
      WxCondition.storm => '⛈',
      WxCondition.heat => '🔥',
      WxCondition.cold => '🧊',
    };

/// Per-language surface terms + negators. EN matches on word boundaries
/// (so "sun" ≠ "sunday"); JA matches on substring (no word spacing).
class WxLexicon {
  const WxLexicon({
    required this.terms,
    this.negatorsBefore = const <String>[],
    this.negatorsAfter = const <String>[],
  });

  /// condition → lowercased surface terms.
  final Map<WxCondition, List<String>> terms;

  /// Tokens that negate a match when they sit just *before* it (EN).
  final List<String> negatorsBefore;

  /// Tokens that negate a match when they sit just *after* it (JA).
  final List<String> negatorsAfter;
}

/// Emoji → condition, matched regardless of locale.
const Map<String, WxCondition> kWxEmoji = <String, WxCondition>{
  '☀': WxCondition.clear,
  '🌞': WxCondition.clear,
  '🌤': WxCondition.clear,
  '☁': WxCondition.clouds,
  '⛅': WxCondition.clouds,
  '🌥': WxCondition.clouds,
  '🌫': WxCondition.fog,
  '🌧': WxCondition.rain,
  '🌦': WxCondition.rain,
  '☔': WxCondition.rain,
  '❄': WxCondition.snow,
  '🌨': WxCondition.snow,
  '☃': WxCondition.snow,
  '💨': WxCondition.wind,
  '🌬': WxCondition.wind,
  '⛈': WxCondition.storm,
  '🌩': WxCondition.storm,
  '🌪': WxCondition.storm,
};

const WxLexicon _enLexicon = WxLexicon(
  terms: <WxCondition, List<String>>{
    WxCondition.clear: <String>['sun', 'sunny', 'sunshine', 'clear', 'blue sky', 'bluebird'],
    WxCondition.clouds: <String>['cloud', 'clouds', 'cloudy', 'overcast', 'grey sky', 'gray sky'],
    WxCondition.fog: <String>['fog', 'foggy', 'mist', 'misty', 'haze', 'hazy'],
    WxCondition.rain: <String>['rain', 'raining', 'rainy', 'drizzle', 'downpour', 'shower', 'showers', 'wet'],
    WxCondition.snow: <String>['snow', 'snowing', 'snowy', 'sleet', 'hail', 'flurries', 'blizzard'],
    WxCondition.wind: <String>['wind', 'windy', 'gusty', 'breezy', 'gale', 'blustery'],
    WxCondition.storm: <String>['storm', 'stormy', 'thunder', 'thunderstorm', 'lightning', 'typhoon', 'hurricane', 'cyclone'],
    WxCondition.heat: <String>['hot', 'scorching', 'sweltering', 'muggy', 'humid', 'heatwave', 'baking'],
    WxCondition.cold: <String>['cold', 'freezing', 'frigid', 'chilly', 'frosty', 'frost', 'icy'],
  },
  negatorsBefore: <String>['no', 'not', 'without', "n't", 'never', 'hardly'],
);

const WxLexicon _jaLexicon = WxLexicon(
  terms: <WxCondition, List<String>>{
    WxCondition.clear: <String>['晴れ', '快晴', '日差し', '青空', 'はれ'],
    WxCondition.clouds: <String>['曇り', 'くもり', '雲', '曇'],
    WxCondition.fog: <String>['霧', 'もや', 'かすみ', 'きり'],
    WxCondition.rain: <String>['雨', '小雨', '大雨', 'にわか雨', '土砂降り', 'あめ'],
    WxCondition.snow: <String>['雪', 'みぞれ', 'あられ', 'ゆき', '吹雪'],
    WxCondition.wind: <String>['風', '強風', '突風', 'かぜ'],
    WxCondition.storm: <String>['嵐', '雷', '台風', 'かみなり'],
    WxCondition.heat: <String>['暑い', '蒸し暑い', '猛暑', 'あつい', '暑'],
    WxCondition.cold: <String>['寒い', '冷える', '凍える', 'さむい', '寒'],
  },
  negatorsAfter: <String>['ない', 'ません', 'じゃない', 'ではない'],
);

/// Active lexicon for [languageCode] (falls back to English).
WxLexicon wxLexiconFor(String languageCode) =>
    languageCode == 'ja' ? _jaLexicon : _enLexicon;

// ---------------------------------------------------------------- temps

/// Number(s) with a degree/unit marker — the marker is REQUIRED so bare
/// integers ("see you at 28") aren't read as temperatures. Captures an
/// optional range second number ("18–22°C").
final RegExp _tempRe = RegExp(
  r'(-?\d{1,3})\s*(?:[-–~]\s*(-?\d{1,3}))?\s*'
  r'(°c|℃|°f|℉|degrees?\s*fahrenheit|degrees?\s*celsius|degrees?\s*f\b|degrees?\s*c\b|degrees?|celsius|fahrenheit|°|度)',
  caseSensitive: false,
);

/// Parse all temperatures in [text], normalised to °C. A marker
/// containing 'f' (°f / ℉ / fahrenheit) is treated as Fahrenheit and
/// converted; everything else (°, ℃, 度, degrees, celsius) is Celsius.
List<double> parseTemperaturesC(String text) {
  final List<double> out = <double>[];
  for (final RegExpMatch m in _tempRe.allMatches(text)) {
    final String unit = (m.group(3) ?? '').toLowerCase();
    final bool isF = unit.contains('f') || unit.contains('℉');
    for (final String? g in <String?>[m.group(1), m.group(2)]) {
      if (g == null) continue;
      final double? v = double.tryParse(g);
      if (v == null) continue;
      out.add(isF ? (v - 32) * 5 / 9 : v);
    }
  }
  return out;
}
