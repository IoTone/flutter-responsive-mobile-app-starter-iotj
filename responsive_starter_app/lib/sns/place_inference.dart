// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

/// R54 sub-task (a) — the **ballpark placement engine**.
///
/// Scans a chat message for references to real places and resolves each
/// to an approximate point for the SNS grid. This is an *informational*
/// representation, not survey geography: a sub-city reference like
/// "West Seattle" anchors on the city centre we *do* have (Seattle, from
/// the gazetteer) and is pushed a ballpark offset in the named direction
/// ("west"). The whole thing is pure Dart with an injected
/// [PlaceGazetteer], so it unit-tests against a fake without Flutter or
/// the bundled asset.
///
/// Design notes live in spec R54. Key behaviours:
/// - region-scoped: a candidate only places if its anchor is within
///   [regionRadiusMeters] of the user's known location (this is also the
///   disambiguator between same-named places);
/// - direction-aware: "West Seattle" / "west of Seattle" / "north end of
///   Tacoma" → anchor + bearing offset;
/// - confidence-gated: only matches at ≥ [minConfidence] are returned;
/// - "X to Y" yields a *pair* (both endpoints, since the sender's own
///   end is unknowable);
/// - explicit coordinates (decimal lat/lon, Maidenhead grid) resolve
///   directly at high confidence with no gazetteer.

/// A place returned by a forward gazetteer lookup.
class GazPlace {
  const GazPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.population = 0,
  });
  final String name;
  final double latitude;
  final double longitude;
  final int population;
}

/// Forward, name→places gazetteer. Implementations return *all*
/// same-named candidates (any region); the engine picks the one nearest
/// the user and within the region. Matching should be case-insensitive.
abstract class PlaceGazetteer {
  List<GazPlace> lookup(String name);
}

/// How a place reference was detected — drives the base confidence and
/// the UI's explanation of why a marker is on the map.
enum PlaceCueKind {
  coordinate,
  gridLocator,
  fromHere, // "hello from X", "QTH X", "based in X"
  motion, //   "heading to X", "10 hops to X"
  proximity, // "near X", "north of X"
  pairEndpoint, // one side of "X to Y"
  bareName, //  a standalone proper name
}

/// One inferred place ready to plot on the SNS grid.
class InferredPlace {
  const InferredPlace({
    required this.displayName,
    required this.anchorName,
    required this.latitude,
    required this.longitude,
    required this.confidence,
    required this.cue,
    required this.sourceSpan,
    this.bearingDegrees,
    this.offsetMeters = 0,
    this.viaDirection = false,
    this.pairId,
  });

  /// What the user wrote ("West Seattle").
  final String displayName;

  /// The gazetteer place we anchored on ("Seattle").
  final String anchorName;

  /// Ballpark placed point (anchor + directional offset + jitter).
  final double latitude;
  final double longitude;

  /// 0..1; only ≥ engine.minConfidence are returned.
  final double confidence;

  final PlaceCueKind cue;

  /// The matched text fragment, for the marker's "why" tooltip.
  final String sourceSpan;

  /// Direction offset applied from the anchor (null = placed at centre).
  final double? bearingDegrees;
  final double offsetMeters;

  /// True when we resolved via the `<dir> <City>` split (anchor is a
  /// stripped city, not the literal phrase).
  final bool viaDirection;

  /// Links the two endpoints of an "X to Y" reference (same id).
  final int? pairId;
}

class PlaceInferenceEngine {
  PlaceInferenceEngine({
    required this.gazetteer,
    this.minConfidence = 0.80,
    this.regionRadiusMeters = 300000,
    this.directionBaseMeters = 6000,
    this.jitterMeters = 1200,
    this.jitter = true,
  });

  final PlaceGazetteer gazetteer;
  final double minConfidence;
  final double regionRadiusMeters;
  final double directionBaseMeters;
  final double jitterMeters;

  /// Deterministic de-stacking jitter. Off in tests that assert exact
  /// coordinates.
  final bool jitter;

  /// Infer places from [message], scored relative to the user at
  /// ([originLat], [originLon]). Returns matches at ≥ [minConfidence],
  /// strongest first.
  List<InferredPlace> infer(
    String message, {
    required double originLat,
    required double originLon,
  }) {
    final List<InferredPlace> out = <InferredPlace>[];

    // 1. Explicit coordinates / grid locators — highest confidence, no
    //    gazetteer needed.
    out.addAll(_coordinates(message));

    // 2. "X to Y" pairs first, so their spans aren't re-read as singles.
    int pairCounter = 0;
    final List<_Match> consumed = <_Match>[];
    for (final RegExpMatch m in _pairRe.allMatches(message)) {
      final String a = m.group(1)!;
      final String b = m.group(2)!;
      final int id = pairCounter++;
      final InferredPlace? pa = _resolvePhrase(a, PlaceCueKind.pairEndpoint,
          m.group(0)!, originLat, originLon,
          pairId: id);
      final InferredPlace? pb = _resolvePhrase(b, PlaceCueKind.pairEndpoint,
          m.group(0)!, originLat, originLon,
          pairId: id);
      if (pa != null) out.add(pa);
      if (pb != null) out.add(pb);
      consumed.add(_Match(m.start, m.end));
    }

    // 3. Cue-triggered single places.
    for (final _Cue cue in _cues) {
      for (final RegExpMatch m in cue.re.allMatches(message)) {
        if (_overlaps(m.start, m.end, consumed)) continue;
        final InferredPlace? p = _resolvePhrase(
            m.group(1)!, cue.kind, m.group(0)!, originLat, originLon,
            allowLowercase: true);
        if (p != null) {
          out.add(p);
          consumed.add(_Match(m.start, m.end));
        }
      }
    }

    // 4. Bare proper-name runs not already consumed.
    for (final RegExpMatch m in _properRe.allMatches(message)) {
      if (_overlaps(m.start, m.end, consumed)) continue;
      final InferredPlace? p = _resolvePhrase(
          m.group(0)!, PlaceCueKind.bareName, m.group(0)!,
          originLat, originLon);
      if (p != null) out.add(p);
    }

    // Dedup by (anchor, ~location): keep the highest-confidence hit for
    // the same place, except keep both ends of a pair.
    final Map<String, InferredPlace> best = <String, InferredPlace>{};
    final List<InferredPlace> kept = <InferredPlace>[];
    for (final InferredPlace p in out) {
      if (p.pairId != null) {
        kept.add(p);
        continue;
      }
      final String key = '${p.anchorName.toLowerCase()}'
          '@${p.bearingDegrees?.round()}';
      final InferredPlace? prev = best[key];
      if (prev == null || p.confidence > prev.confidence) best[key] = p;
    }
    kept.addAll(best.values);
    kept.sort((InferredPlace a, InferredPlace b) =>
        b.confidence.compareTo(a.confidence));
    return kept;
  }

  // --- Resolution -----------------------------------------------------

  InferredPlace? _resolvePhrase(
    String phrase,
    PlaceCueKind kind,
    String span,
    double originLat,
    double originLon, {
    bool allowLowercase = false,
    int? pairId,
  }) {
    final _Parsed? parsed = _parsePhrase(phrase, allowLowercase: allowLowercase);
    if (parsed == null) return null;

    // Try the literal compound first ("West Bend"), then the stripped
    // anchor with a directional offset ("Seattle" + west).
    GazPlace? hit;
    bool viaDir = false;
    double? bearing = parsed.bearing;

    if (parsed.surface != null) {
      final GazPlace? a = _pickInRegion(
          gazetteer.lookup(parsed.surface!), originLat, originLon);
      if (a != null) {
        hit = a;
        // Bearing applies only if the matched name isn't itself the
        // directional compound (e.g. "Seattle" from "west of Seattle").
        if (_startsWithDirection(parsed.surface!)) bearing = null;
      }
    }
    if (hit == null && parsed.stripped != null) {
      final GazPlace? b = _pickInRegion(
          gazetteer.lookup(parsed.stripped!), originLat, originLon);
      if (b != null) {
        hit = b;
        viaDir = parsed.bearing != null;
      }
    }
    if (hit == null) return null;

    final double offset =
        bearing == null ? 0 : directionBaseMeters * parsed.magnitude;
    double lat = hit.latitude;
    double lon = hit.longitude;
    if (offset > 0) {
      final _LatLon p = _destination(lat, lon, bearing!, offset);
      lat = p.lat;
      lon = p.lon;
    }
    if (jitter) {
      final _LatLon j = _deterministicJitter(lat, lon, '$span|${hit.name}');
      lat = j.lat;
      lon = j.lon;
    }

    final double conf = _score(
      kind: kind,
      exact: !viaDir,
      viaDirection: viaDir,
      place: hit,
      origin: _LatLon(originLat, originLon),
      uniqueInRegion: _countInRegion(
              gazetteer.lookup(viaDir ? parsed.stripped! : parsed.surface ?? parsed.stripped!),
              originLat,
              originLon) ==
          1,
    );
    if (conf < minConfidence) return null;

    return InferredPlace(
      displayName: parsed.display,
      anchorName: hit.name,
      latitude: lat,
      longitude: lon,
      confidence: conf,
      cue: kind,
      sourceSpan: span.trim(),
      bearingDegrees: bearing,
      offsetMeters: offset,
      viaDirection: viaDir,
      pairId: pairId,
    );
  }

  double _score({
    required PlaceCueKind kind,
    required bool exact,
    required bool viaDirection,
    required GazPlace place,
    required _LatLon origin,
    required bool uniqueInRegion,
  }) {
    double c = switch (kind) {
      PlaceCueKind.coordinate => 0.95,
      PlaceCueKind.gridLocator => 0.9,
      PlaceCueKind.fromHere => 0.65,
      PlaceCueKind.motion => 0.55,
      PlaceCueKind.pairEndpoint => 0.55,
      PlaceCueKind.proximity => 0.5,
      PlaceCueKind.bareName => 0.45,
    };
    if (exact) {
      c += 0.20;
    } else if (viaDirection) {
      c += 0.15;
    }
    c += 0.10; // in-region (guaranteed by _pickInRegion)
    if (place.population >= 100000) c += 0.05;
    if (uniqueInRegion) c += 0.05;
    return c.clamp(0.0, 1.0);
  }

  List<InferredPlace> _coordinates(String message) {
    final List<InferredPlace> out = <InferredPlace>[];
    for (final RegExpMatch m in _decimalRe.allMatches(message)) {
      final double? lat = double.tryParse(m.group(1)!);
      final double? lon = double.tryParse(m.group(2)!);
      if (lat == null || lon == null) continue;
      if (lat.abs() > 90 || lon.abs() > 180) continue;
      out.add(InferredPlace(
        displayName: '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
        anchorName: 'coordinate',
        latitude: lat,
        longitude: lon,
        confidence: 0.95,
        cue: PlaceCueKind.coordinate,
        sourceSpan: m.group(0)!.trim(),
      ));
    }
    for (final RegExpMatch m in _gridRe.allMatches(message)) {
      final _LatLon? p = _maidenheadToLatLon(m.group(0)!);
      if (p == null) continue;
      out.add(InferredPlace(
        displayName: m.group(0)!.toUpperCase(),
        anchorName: 'grid ${m.group(0)!.toUpperCase()}',
        latitude: p.lat,
        longitude: p.lon,
        confidence: 0.9,
        cue: PlaceCueKind.gridLocator,
        sourceSpan: m.group(0)!.trim(),
      ));
    }
    return out;
  }

  GazPlace? _pickInRegion(
      List<GazPlace> cands, double originLat, double originLon) {
    GazPlace? best;
    double bestD = double.infinity;
    for (final GazPlace c in cands) {
      final double d =
          _haversine(originLat, originLon, c.latitude, c.longitude);
      if (d > regionRadiusMeters) continue;
      if (d < bestD) {
        best = c;
        bestD = d;
      }
    }
    return best;
  }

  int _countInRegion(
      List<GazPlace> cands, double originLat, double originLon) {
    int n = 0;
    for (final GazPlace c in cands) {
      if (_haversine(originLat, originLon, c.latitude, c.longitude) <=
          regionRadiusMeters) {
        n++;
      }
    }
    return n;
  }

  // --- Phrase parsing -------------------------------------------------

  /// Parse a captured phrase into a directional modifier + anchor name.
  /// Returns null if there's no plausible place token.
  _Parsed? _parsePhrase(String phrase, {required bool allowLowercase}) {
    final List<String> words = phrase
        .split(RegExp(r"[^\w'’.\-]+"))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;

    // Surface compound: leading run of capitalised tokens (+ interior
    // connectors) from word 0, regardless of modifier meaning.
    final String? surface = _properRun(words, 0, requireCapital: true);

    // Modifiers: consume leading direction / central / outer / connector
    // words, accumulating a bearing.
    final List<double> dirs = <double>[];
    double magnitude = 1.0;
    int i = 0;
    while (i < words.length) {
      final String lw = words[i].toLowerCase();
      if (_directions.containsKey(lw)) {
        dirs.add(_directions[lw]!);
        i++;
      } else if (_centralWords.contains(lw)) {
        magnitude = 0.0;
        i++;
      } else if (_outerWords.contains(lw)) {
        magnitude = 2.0;
        i++;
      } else if (_connectors.contains(lw) && (dirs.isNotEmpty || i > 0)) {
        i++;
      } else {
        break;
      }
    }
    final String? stripped =
        _properRun(words, i, requireCapital: !allowLowercase);

    if (surface == null && stripped == null) return null;
    final double? bearing = dirs.isEmpty ? null : _averageBearing(dirs);
    final String display = surface ?? stripped ?? phrase.trim();
    return _Parsed(
      surface: surface,
      stripped: (stripped != null && stripped != surface) ? stripped : null,
      bearing: bearing,
      magnitude: magnitude,
      display: display,
    );
  }

  /// Extract a place-name run starting at [start]: a contiguous run of
  /// capitalised words (with interior connectors), up to 3 words. With
  /// [requireCapital] false, a single leading lowercase token is allowed
  /// (cue context already signals a place).
  String? _properRun(List<String> words, int start,
      {required bool requireCapital}) {
    final List<String> run = <String>[];
    for (int j = start; j < words.length && run.length < 3; j++) {
      final String w = words[j];
      final bool cap = w.isNotEmpty && _isUpper(w[0]);
      if (run.isEmpty) {
        // First token: must be capitalised unless the caller allows a
        // lowercase lead (cue context already signals a place).
        if (!cap && requireCapital) break;
        run.add(w);
      } else {
        if (cap) {
          run.add(w);
        } else if (_connectors.contains(w.toLowerCase()) &&
            j + 1 < words.length &&
            words[j + 1].isNotEmpty &&
            _isUpper(words[j + 1][0])) {
          run.add(w);
        } else {
          break;
        }
      }
    }
    if (run.isEmpty) return null;
    return run.join(' ');
  }

  bool _startsWithDirection(String name) {
    final int sp = name.indexOf(' ');
    final String first = (sp < 0 ? name : name.substring(0, sp)).toLowerCase();
    return _directions.containsKey(first);
  }

  // --- Geo ------------------------------------------------------------

  _LatLon _destination(double lat, double lon, double bearingDeg, double m) {
    const double r = 6371000.0;
    final double br = bearingDeg * math.pi / 180.0;
    final double la1 = lat * math.pi / 180.0;
    final double lo1 = lon * math.pi / 180.0;
    final double dr = m / r;
    final double la2 = math.asin(math.sin(la1) * math.cos(dr) +
        math.cos(la1) * math.sin(dr) * math.cos(br));
    final double lo2 = lo1 +
        math.atan2(math.sin(br) * math.sin(dr) * math.cos(la1),
            math.cos(dr) - math.sin(la1) * math.sin(la2));
    return _LatLon(la2 * 180.0 / math.pi, lo2 * 180.0 / math.pi);
  }

  _LatLon _deterministicJitter(double lat, double lon, String seed) {
    int h = 2166136261;
    for (final int code in seed.codeUnits) {
      h = (h ^ code) * 16777619 & 0xFFFFFFFF;
    }
    final double bearing = (h % 360).toDouble();
    final double dist = jitterMeters * ((h >> 9) % 1000) / 1000.0;
    if (dist <= 0) return _LatLon(lat, lon);
    return _destination(lat, lon, bearing, dist);
  }

  double _averageBearing(List<double> degs) {
    double x = 0, y = 0;
    for (final double d in degs) {
      final double r = d * math.pi / 180.0;
      x += math.cos(r);
      y += math.sin(r);
    }
    double deg = math.atan2(y, x) * 180.0 / math.pi;
    if (deg < 0) deg += 360;
    return deg;
  }

  static double _haversine(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000.0;
    final double dLat = (lat2 - lat1) * math.pi / 180.0;
    final double dLon = (lon2 - lon1) * math.pi / 180.0;
    final double a = math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.pow(math.sin(dLon / 2), 2).toDouble();
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static _LatLon? _maidenheadToLatLon(String grid) {
    final String g = grid.toUpperCase();
    if (g.length != 4 && g.length != 6) return null;
    final int a0 = g.codeUnitAt(0) - 65; // A
    final int a1 = g.codeUnitAt(1) - 65;
    if (a0 < 0 || a0 > 17 || a1 < 0 || a1 > 17) return null;
    final int d0 = g.codeUnitAt(2) - 48; // 0
    final int d1 = g.codeUnitAt(3) - 48;
    if (d0 < 0 || d0 > 9 || d1 < 0 || d1 > 9) return null;
    double lon = a0 * 20.0 - 180.0 + d0 * 2.0;
    double lat = a1 * 10.0 - 90.0 + d1 * 1.0;
    if (g.length == 6) {
      final int s0 = g.codeUnitAt(4) - 65; // A..X
      final int s1 = g.codeUnitAt(5) - 65;
      if (s0 < 0 || s0 > 23 || s1 < 0 || s1 > 23) return null;
      lon += s0 * (2.0 / 24.0) + (1.0 / 24.0);
      lat += s1 * (1.0 / 24.0) + (0.5 / 24.0);
    } else {
      lon += 1.0; // centre of the 2°-wide square
      lat += 0.5; // centre of the 1°-tall square
    }
    return _LatLon(lat, lon);
  }

  static bool _isUpper(String ch) {
    final int c = ch.codeUnitAt(0);
    return c >= 65 && c <= 90;
  }

  static bool _overlaps(int start, int end, List<_Match> spans) {
    for (final _Match s in spans) {
      if (start < s.end && end > s.start) return true;
    }
    return false;
  }
}

// --- Internal helpers -------------------------------------------------

class _LatLon {
  const _LatLon(this.lat, this.lon);
  final double lat;
  final double lon;
}

class _Match {
  const _Match(this.start, this.end);
  final int start;
  final int end;
}

class _Parsed {
  const _Parsed({
    required this.surface,
    required this.stripped,
    required this.bearing,
    required this.magnitude,
    required this.display,
  });
  final String? surface;
  final String? stripped;
  final double? bearing;
  final double magnitude;
  final String display;
}

class _Cue {
  const _Cue(this.re, this.kind);
  final RegExp re;
  final PlaceCueKind kind;
}

const Map<String, double> _directions = <String, double>{
  'north': 0,
  'n': 0,
  'northeast': 45,
  'ne': 45,
  'east': 90,
  'e': 90,
  'southeast': 135,
  'se': 135,
  'south': 180,
  's': 180,
  'southwest': 225,
  'sw': 225,
  'west': 270,
  'w': 270,
  'northwest': 315,
  'nw': 315,
};
const Set<String> _centralWords = <String>{
  'downtown', 'central', 'centre', 'center', 'core', 'cbd', 'midtown',
};
const Set<String> _outerWords = <String>{
  'outskirts', 'edge', 'outer', 'suburb', 'suburbs', 'rural', 'fringe',
};
const Set<String> _connectors = <String>{
  'of', 'the', 'de', 'la', 'del', 'los', 'las', 'el', 'side', 'end', 'part',
};

// Non-capturing place phrase: up to ~4 words, stopping at sentence
// punctuation. Cues wrap this in a single capture group = the phrase
// handed to the parser.
const String _placeNC = r"[A-Za-z][A-Za-z'’.\-]*(?:\s+[A-Za-z'’.\-]+){0,3}";

final List<_Cue> _cues = <_Cue>[
  _Cue(
      RegExp(
          '\\b(?:hello\\s+from|greetings\\s+from|qth(?:\\s+is)?|'
          'coming\\s+from|here\\s+in|live\\s+in|living\\s+in|based\\s+in|'
          'reporting\\s+from|from)\\s+($_placeNC)',
          caseSensitive: false),
      PlaceCueKind.fromHere),
  _Cue(
      RegExp(
          '\\b(?:heading\\s+(?:to|for)|headed\\s+(?:to|for)|off\\s+to|'
          'on\\s+my\\s+way\\s+to|going\\s+to|en\\s+route\\s+to|'
          'driving\\s+to|\\d+\\s+hops?\\s+(?:to|from|away\\s+from))'
          '\\s+($_placeNC)',
          caseSensitive: false),
      PlaceCueKind.motion),
  _Cue(
      RegExp(
          '\\b(?:near|by|around|close\\s+to|just\\s+outside|outside|'
          'over\\s+in)\\s+($_placeNC)',
          caseSensitive: false),
      PlaceCueKind.proximity),
  // Directional: the bearing word stays *inside* the captured phrase so
  // the parser can turn it into an offset ("north of Seattle",
  // "Northwest Portland", "west end of Tacoma").
  _Cue(
      RegExp(
          '\\b((?:north|south|east|west|northeast|northwest|southeast|'
          'southwest|ne|nw|se|sw)\\s+(?:of\\s+|side\\s+of\\s+|end\\s+of\\s+)?'
          '$_placeNC)',
          caseSensitive: false),
      PlaceCueKind.proximity),
];

// "X to Y" pair — both sides 1–2 capitalised words.
final RegExp _pairRe = RegExp(
    r'\b([A-Z][A-Za-z.\-]+(?:\s+[A-Z][A-Za-z.\-]+)?)\s+(?:to|→|->|-->)\s+'
    r'([A-Z][A-Za-z.\-]+(?:\s+[A-Z][A-Za-z.\-]+)?)');

// Bare capitalised run (1–3 words).
final RegExp _properRe =
    RegExp(r'\b[A-Z][A-Za-z.\-]+(?:\s+[A-Z][A-Za-z.\-]+){0,2}\b');

// Decimal "lat, lon" — both with a fractional part to avoid matching
// plain integers.
final RegExp _decimalRe =
    RegExp(r'(-?\d{1,2}\.\d{2,}),?\s+(-?\d{1,3}\.\d{2,})');

// Maidenhead grid locator (4 or 6 char), as a standalone token.
final RegExp _gridRe =
    RegExp(r'\b[A-R]{2}[0-9]{2}(?:[A-Xa-x]{2})?\b');
