// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'place_inference.dart';

/// A place currently held for display on the SNS grid: the inferred
/// place plus how often it's been mentioned and when, with a confidence
/// that grows as independent mentions reinforce it.
class InferredMarker {
  InferredMarker(this.place, this.firstSeen, this.lastSeen, this.mentions);

  final InferredPlace place;
  final DateTime firstSeen;
  DateTime lastSeen;
  int mentions;

  /// Reinforced confidence — each repeat mention nudges it up, capped
  /// at 1.0. Drives the marker's visual weight on the grid.
  double get confidence =>
      (place.confidence + 0.04 * (mentions - 1)).clamp(0.0, 1.0);
}

/// R54 — holds the inferred places to plot on the SNS grid. Markers are
/// **ephemeral** (expire after [ttl] of no new mentions) and
/// **reinforced** (a repeat mention of the same place refreshes it and
/// raises its confidence). [now] is passed in so the store is
/// deterministically testable.
class InferredPlaceStore {
  InferredPlaceStore({
    this.ttl = const Duration(minutes: 45),
    this.maxEntries = 120,
  });

  final Duration ttl;
  final int maxEntries;

  final Map<String, InferredMarker> _byKey = <String, InferredMarker>{};

  static String _key(InferredPlace p) =>
      '${p.anchorName.toLowerCase()}@${p.bearingDegrees?.round() ?? 'c'}';

  /// Add (or reinforce) an inferred place. A repeat of the same anchor +
  /// bearing refreshes its TTL and bumps its mention count.
  void add(InferredPlace p, {required DateTime now}) {
    final String k = _key(p);
    final InferredMarker? existing = _byKey[k];
    if (existing != null) {
      existing.lastSeen = now;
      existing.mentions += 1;
    } else {
      _byKey[k] = InferredMarker(p, now, now, 1);
    }
    _prune(now);
  }

  /// The markers currently live (not expired), strongest first.
  List<InferredMarker> current({required DateTime now}) {
    _prune(now);
    final List<InferredMarker> out = _byKey.values.toList();
    out.sort((InferredMarker a, InferredMarker b) =>
        b.confidence.compareTo(a.confidence));
    return out;
  }

  void clear() => _byKey.clear();

  bool get isEmpty => _byKey.isEmpty;
  int get length => _byKey.length;

  void _prune(DateTime now) {
    _byKey.removeWhere((String _, InferredMarker m) =>
        now.difference(m.lastSeen) > ttl);
    if (_byKey.length <= maxEntries) return;
    // Over cap: drop the stalest entries.
    final List<MapEntry<String, InferredMarker>> sorted = _byKey.entries
        .toList()
      ..sort((MapEntry<String, InferredMarker> a,
              MapEntry<String, InferredMarker> b) =>
          a.value.lastSeen.compareTo(b.value.lastSeen));
    for (int i = 0; i < sorted.length - maxEntries; i++) {
      _byKey.remove(sorted[i].key);
    }
  }
}
