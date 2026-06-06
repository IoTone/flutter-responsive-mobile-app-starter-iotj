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

/// One weather mention parsed from one message.
class WxObservation {
  const WxObservation({
    required this.conditions,
    required this.temperatureC,
    required this.confidence,
    required this.at,
    this.sourceMsgId,
    this.sourceSpan = '',
  });

  final Set<WxCondition> conditions;

  /// Normalised to °C; null when the message named a condition but no temp.
  final double? temperatureC;

  /// Lexicon-match strength, 0..1.
  final double confidence;
  final DateTime at;
  final String? sourceMsgId;
  final String sourceSpan;
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
