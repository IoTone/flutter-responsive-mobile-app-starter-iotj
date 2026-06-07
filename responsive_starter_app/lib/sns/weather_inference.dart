// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'weather_lexicon.dart';

/// Microclimate / "wx" — the pure, offline weather scanner (P1).
///
/// [WeatherInferenceEngine.scan] turns one chat message into a
/// [WxObservation] (or null if it carries no weather); [aggregateAmbient]
/// folds a window of observations into a channel-wide [AmbientWx] summary.
/// No location yet (P1) — speaker placement + grid bubbles are P2.
/// Mirrors the place-inference subsystem's shape so the two stay parallel.

/// One weather mention parsed from one message. P2 adds an optional
/// location (lat/lon + place label) resolved by the controller from place
/// inference or the sender's GPS.
class WxObservation {
  const WxObservation({
    required this.conditions,
    required this.temperatureC,
    required this.confidence,
    required this.at,
    this.sourceMsgId,
    this.sourceSpan = '',
    this.lat,
    this.lon,
    this.placeName,
  });

  final Set<WxCondition> conditions;

  /// Normalised to °C; null when the message named a condition but no temp.
  final double? temperatureC;

  /// Lexicon-match strength, 0..1.
  final double confidence;
  final DateTime at;
  final String? sourceMsgId;
  final String sourceSpan;

  /// Resolved location of the speaker/place, when known (P2).
  final double? lat;
  final double? lon;
  final String? placeName;

  bool get isLocated => lat != null && lon != null;

  /// A copy anchored at a resolved location.
  WxObservation locatedAt(double lat, double lon, String? name) =>
      WxObservation(
        conditions: conditions,
        temperatureC: temperatureC,
        confidence: confidence,
        at: at,
        sourceMsgId: sourceMsgId,
        sourceSpan: sourceSpan,
        lat: lat,
        lon: lon,
        placeName: name,
      );
}

/// A per-place weather rollup — what P2 renders as a microclimate bubble.
class Microclimate {
  const Microclimate({
    required this.lat,
    required this.lon,
    required this.placeName,
    required this.dominant,
    required this.tempMinC,
    required this.tempAvgC,
    required this.tempMaxC,
    required this.mentions,
    required this.lastSeen,
  });

  final double lat;
  final double lon;
  final String? placeName;
  final WxCondition? dominant;
  final double? tempMinC;
  final double? tempAvgC;
  final double? tempMaxC;
  final int mentions;
  final DateTime lastSeen;

  bool get hasTemp => tempAvgC != null;
}

/// A channel-wide rollup over a time window — what P1 renders as the
/// "ambient" microclimate strip (no per-place bubbles yet).
class AmbientWx {
  const AmbientWx({
    required this.tally,
    required this.dominant,
    required this.tempMinC,
    required this.tempAvgC,
    required this.tempMaxC,
    required this.mentions,
    required this.lastSeen,
  });

  /// condition → number of observations mentioning it.
  final Map<WxCondition, int> tally;

  /// Most-mentioned condition, or null when only bare temperatures were seen.
  final WxCondition? dominant;
  final double? tempMinC;
  final double? tempAvgC;
  final double? tempMaxC;

  /// Number of contributing observations.
  final int mentions;
  final DateTime lastSeen;

  bool get hasTemp => tempAvgC != null;
}

class WeatherInferenceEngine {
  WeatherInferenceEngine._();

  /// Per-condition confidence: concrete nouns (rain/snow/fog/storm) read
  /// more reliably than bare qualitative adjectives (hot/cold).
  static double _weight(WxCondition c) => switch (c) {
        WxCondition.rain ||
        WxCondition.snow ||
        WxCondition.fog ||
        WxCondition.storm =>
          0.80,
        WxCondition.clear || WxCondition.clouds || WxCondition.wind => 0.70,
        WxCondition.heat || WxCondition.cold => 0.55,
      };

  /// Scan one message. Returns null when no weather content is present.
  static WxObservation? scan(
    String text, {
    required String languageCode,
    DateTime? at,
    String? sourceMsgId,
  }) {
    if (text.trim().isEmpty) return null;
    final WxLexicon lex = wxLexiconFor(languageCode);
    final String lower = text.toLowerCase();
    final Set<WxCondition> found = <WxCondition>{};
    double conf = 0;

    // Emoji — strong, locale-independent.
    for (final MapEntry<String, WxCondition> e in kWxEmoji.entries) {
      if (text.contains(e.key)) {
        found.add(e.value);
        if (0.90 > conf) conf = 0.90;
      }
    }

    // Lexicon terms.
    for (final MapEntry<WxCondition, List<String>> entry in lex.terms.entries) {
      for (final String term in entry.value) {
        final int idx = _firstMatch(lower, term, languageCode);
        if (idx < 0) continue;
        if (_negated(lower, idx, term.length, lex)) continue;
        found.add(entry.key);
        final double w = _weight(entry.key);
        if (w > conf) conf = w;
        break; // one hit per condition is enough
      }
    }

    final List<double> temps = parseTemperaturesC(text);
    if (found.isEmpty && temps.isEmpty) return null;

    double? tempC;
    if (temps.isNotEmpty) {
      tempC = temps.reduce((double a, double b) => a + b) / temps.length;
      if (0.85 > conf) conf = 0.85;
      if (found.isNotEmpty && conf < 1.0) conf = (conf + 0.10).clamp(0.0, 1.0);
    }

    return WxObservation(
      conditions: found,
      temperatureC: tempC,
      confidence: conf,
      at: at ?? DateTime.fromMillisecondsSinceEpoch(0),
      sourceMsgId: sourceMsgId,
      sourceSpan: text.length <= 80 ? text : '${text.substring(0, 79)}…',
    );
  }

  // The view rescans on every controller notify, so cache the per-term
  // boundary patterns rather than recompiling them per message.
  static final Map<String, RegExp> _reCache = <String, RegExp>{};

  /// Scan against ALL supported locales (EN + JA) and merge — channels
  /// can be mixed-language, and the controller has no BuildContext locale.
  static WxObservation? scanAny(String text,
      {DateTime? at, String? sourceMsgId}) {
    final WxObservation? en =
        scan(text, languageCode: 'en', at: at, sourceMsgId: sourceMsgId);
    final WxObservation? ja =
        scan(text, languageCode: 'ja', at: at, sourceMsgId: sourceMsgId);
    if (en == null) return ja;
    if (ja == null) return en;
    return WxObservation(
      conditions: <WxCondition>{...en.conditions, ...ja.conditions},
      temperatureC: en.temperatureC ?? ja.temperatureC,
      confidence: en.confidence > ja.confidence ? en.confidence : ja.confidence,
      at: en.at,
      sourceMsgId: en.sourceMsgId,
      sourceSpan: en.sourceSpan,
    );
  }

  /// Index of [term] in [lower] using word boundaries for non-JA (so
  /// "sun" doesn't fire on "sunday"); plain substring for JA. -1 = none.
  static int _firstMatch(String lower, String term, String lang) {
    if (lang == 'ja') return lower.indexOf(term);
    final RegExp re = _reCache.putIfAbsent(
        term,
        () =>
            RegExp(r'\b' + RegExp.escape(term) + r'\b', caseSensitive: false));
    return re.firstMatch(lower)?.start ?? -1;
  }

  static bool _negated(String lower, int idx, int len, WxLexicon lex) {
    final String before =
        lower.substring((idx - 16).clamp(0, lower.length), idx);
    for (final String n in lex.negatorsBefore) {
      if (before.contains(n)) return true;
    }
    final int end = (idx + len).clamp(0, lower.length);
    final String after = lower.substring(end, (end + 8).clamp(0, lower.length));
    for (final String n in lex.negatorsAfter) {
      if (after.contains(n)) return true;
    }
    return false;
  }
}

/// Fold a window of observations into a channel-wide summary. Returns
/// null when empty. Caller is expected to pre-filter by time + a
/// confidence floor.
AmbientWx? aggregateAmbient(Iterable<WxObservation> observations) {
  final List<WxObservation> obs = observations.toList(growable: false);
  if (obs.isEmpty) return null;

  final Map<WxCondition, int> tally = <WxCondition, int>{};
  final List<double> temps = <double>[];
  DateTime lastSeen = obs.first.at;
  for (final WxObservation o in obs) {
    for (final WxCondition c in o.conditions) {
      tally[c] = (tally[c] ?? 0) + 1;
    }
    if (o.temperatureC != null) temps.add(o.temperatureC!);
    if (o.at.isAfter(lastSeen)) lastSeen = o.at;
  }

  WxCondition? dominant;
  int best = 0;
  for (final MapEntry<WxCondition, int> e in tally.entries) {
    if (e.value > best) {
      best = e.value;
      dominant = e.key;
    }
  }

  double? minC, avgC, maxC;
  if (temps.isNotEmpty) {
    minC = temps.reduce((double a, double b) => a < b ? a : b);
    maxC = temps.reduce((double a, double b) => a > b ? a : b);
    avgC = temps.reduce((double a, double b) => a + b) / temps.length;
  }

  return AmbientWx(
    tally: tally,
    dominant: dominant,
    tempMinC: minC,
    tempAvgC: avgC,
    tempMaxC: maxC,
    mentions: obs.length,
    lastSeen: lastSeen,
  );
}

/// Group **located** observations into per-place microclimates (P2).
/// Clusters by a ~5.5 km grid cell (0.05°); each cell yields the dominant
/// condition, temp range, count, centroid, and most-common place label.
/// Strongest (most-mentioned) first.
List<Microclimate> aggregateMicroclimates(Iterable<WxObservation> located,
    {int minMentions = 1}) {
  final Map<String, List<WxObservation>> cells =
      <String, List<WxObservation>>{};
  for (final WxObservation o in located) {
    if (!o.isLocated) continue;
    final String key =
        '${(o.lat! / 0.05).round()}:${(o.lon! / 0.05).round()}';
    (cells[key] ??= <WxObservation>[]).add(o);
  }

  final List<Microclimate> out = <Microclimate>[];
  for (final List<WxObservation> group in cells.values) {
    if (group.length < minMentions) continue;
    final Map<WxCondition, int> tally = <WxCondition, int>{};
    final Map<String, int> names = <String, int>{};
    final List<double> temps = <double>[];
    double sumLat = 0, sumLon = 0;
    DateTime lastSeen = group.first.at;
    for (final WxObservation o in group) {
      for (final WxCondition c in o.conditions) {
        tally[c] = (tally[c] ?? 0) + 1;
      }
      if (o.temperatureC != null) temps.add(o.temperatureC!);
      if (o.placeName != null && o.placeName!.isNotEmpty) {
        names[o.placeName!] = (names[o.placeName!] ?? 0) + 1;
      }
      sumLat += o.lat!;
      sumLon += o.lon!;
      if (o.at.isAfter(lastSeen)) lastSeen = o.at;
    }
    WxCondition? dominant;
    int best = 0;
    for (final MapEntry<WxCondition, int> e in tally.entries) {
      if (e.value > best) {
        best = e.value;
        dominant = e.key;
      }
    }
    String? label;
    int bestName = 0;
    for (final MapEntry<String, int> e in names.entries) {
      if (e.value > bestName) {
        bestName = e.value;
        label = e.key;
      }
    }
    double? minC, avgC, maxC;
    if (temps.isNotEmpty) {
      minC = temps.reduce((double a, double b) => a < b ? a : b);
      maxC = temps.reduce((double a, double b) => a > b ? a : b);
      avgC = temps.reduce((double a, double b) => a + b) / temps.length;
    }
    out.add(Microclimate(
      lat: sumLat / group.length,
      lon: sumLon / group.length,
      placeName: label,
      dominant: dominant,
      tempMinC: minC,
      tempAvgC: avgC,
      tempMaxC: maxC,
      mentions: group.length,
      lastSeen: lastSeen,
    ));
  }
  out.sort((Microclimate a, Microclimate b) =>
      b.mentions.compareTo(a.mentions));
  return out;
}
