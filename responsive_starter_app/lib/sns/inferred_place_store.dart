// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'place_inference.dart';

/// A place currently held for display on the SNS grid: the inferred
/// place plus the timestamps of the messages that mentioned it within
/// the store's window, so the marker can show a **last-hour count** and
/// a confidence that grows as independent mentions reinforce it.
class InferredMarker {
  InferredMarker(this.place, this._mentionsUnix);

  final InferredPlace place;

  /// Unix-second timestamps of mentions still inside the window
  /// (already pruned by the store), oldest-first.
  final List<int> _mentionsUnix;

  /// Stable key (anchor + bearing) — used to dismiss this marker.
  String get key => InferredPlaceStore.keyFor(place);

  /// Messages mentioning this place within the last [InferredPlaceStore.window]
  /// (default 1 hour). This is the number rendered on the diamond.
  int get recentCount => _mentionsUnix.length;

  int get lastSeenUnix => _mentionsUnix.isEmpty ? 0 : _mentionsUnix.last;
  DateTime get lastSeen =>
      DateTime.fromMillisecondsSinceEpoch(lastSeenUnix * 1000);

  /// Reinforced confidence — each repeat mention nudges it up, capped
  /// at 1.0. Drives the marker's visual weight.
  double get confidence =>
      (place.confidence + 0.04 * (recentCount - 1)).clamp(0.0, 1.0);
}

/// R54 — holds the inferred places to plot on the SNS grid. Each marker
/// keeps the timestamps of its mentions over a rolling [window] (default
/// 1 hour, matching the heat map's horizon); a marker drops out once it
/// has no mention inside the window. [now] is passed in so the store is
/// deterministically testable.
class InferredPlaceStore {
  InferredPlaceStore({
    this.window = const Duration(hours: 1),
    this.maxEntries = 120,
  });

  final Duration window;
  final int maxEntries;

  final Map<String, _Entry> _byKey = <String, _Entry>{};

  static String keyFor(InferredPlace p) =>
      '${p.anchorName.toLowerCase()}@${p.bearingDegrees?.round() ?? 'c'}';

  /// Record a mention. The first placement is kept stable (later
  /// mentions only add a timestamp), so the marker doesn't jump around.
  void add(InferredPlace p, {required DateTime now}) {
    final int t = now.millisecondsSinceEpoch ~/ 1000;
    final _Entry e = _byKey.putIfAbsent(keyFor(p), () => _Entry(p));
    e.mentionsUnix.add(t);
    _prune(now);
  }

  /// The markers currently live (≥1 mention inside the window),
  /// strongest first.
  List<InferredMarker> current({required DateTime now}) {
    _prune(now);
    final List<InferredMarker> out = <InferredMarker>[
      for (final _Entry e in _byKey.values)
        InferredMarker(e.place, List<int>.of(e.mentionsUnix)),
    ];
    out.sort((InferredMarker a, InferredMarker b) =>
        b.confidence.compareTo(a.confidence));
    return out;
  }

  /// Remove a marker (the "not a place / dismiss" action).
  void dismiss(String key) => _byKey.remove(key);

  void clear() => _byKey.clear();
  bool get isEmpty => _byKey.isEmpty;
  int get length => _byKey.length;

  void _prune(DateTime now) {
    final int cut =
        (now.millisecondsSinceEpoch ~/ 1000) - window.inSeconds;
    final List<String> dead = <String>[];
    _byKey.forEach((String k, _Entry e) {
      e.mentionsUnix.removeWhere((int t) => t < cut);
      if (e.mentionsUnix.isEmpty) dead.add(k);
    });
    for (final String k in dead) {
      _byKey.remove(k);
    }
    if (_byKey.length <= maxEntries) return;
    // Over cap: drop the stalest (oldest last-mention) entries.
    final List<MapEntry<String, _Entry>> sorted = _byKey.entries.toList()
      ..sort((MapEntry<String, _Entry> a, MapEntry<String, _Entry> b) =>
          a.value.mentionsUnix.last.compareTo(b.value.mentionsUnix.last));
    for (int i = 0; i < sorted.length - maxEntries; i++) {
      _byKey.remove(sorted[i].key);
    }
  }
}

class _Entry {
  _Entry(this.place);
  final InferredPlace place;
  final List<int> mentionsUnix = <int>[];
}
