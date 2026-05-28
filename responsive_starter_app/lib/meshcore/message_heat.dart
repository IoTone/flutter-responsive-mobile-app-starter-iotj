// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'coverage_store.dart';

/// R51 — one social "ping": a message we observed, with enough
/// context for the sns-cells view to flash a toast and (when the
/// sender is located + known) highlight a node.
class HeatPing {
  const HeatPing({
    required this.seq,
    required this.text,
    required this.atUnix,
    this.pubKeyHex,
    this.latitude,
    this.longitude,
    this.isChannel = false,
  });

  /// Monotonic counter so a view can tell "this is a new ping" from
  /// "same ping, rebuilt" without comparing contents.
  final int seq;
  final String text;
  final int atUnix;

  /// Sender node's full pubkey hex when resolvable (DMs only —
  /// channel messages are anonymous in MeshCore, so this is null
  /// for them).
  final String? pubKeyHex;

  /// Where the heat was deposited. For a located DM sender this is
  /// the sender's position; for channel messages (anonymous) it's
  /// our own position — the message reached us *here*.
  final double? latitude;
  final double? longitude;

  /// True for channel-broadcast messages (anonymous), false for DMs.
  final bool isChannel;
}

/// R51 — social-activity heat tracker. Buckets observed messages
/// into geographic cells (reusing [CoverageStore]'s 0.002° grid)
/// and scores each cell by a time-decayed message density.
///
/// Heat model (continuous exponential decay, tuned to the spec):
///   score(cell) = Σ_msgs exp(-age_seconds / τ)
///   hotness     = (score / hotReference).clamp(0, 1)
/// with τ = 15 min and hotReference = 5. That gives the intended
/// feel — ~5 fresh messages in a cell reads as fully hot (bright
/// red); a cell idle for ~1 h decays to ~0 (coolest). Only the
/// last [horizon] of message times are retained; older entries are
/// pruned on every [scores] call.
class MessageHeatTracker {
  MessageHeatTracker({
    this.tau = const Duration(minutes: 15),
    this.horizon = const Duration(hours: 1),
    this.hotReference = 5.0,
  });

  final Duration tau;
  final Duration horizon;
  final double hotReference;

  /// cellKey → unix-second timestamps of messages placed in it.
  final Map<String, List<int>> _cells = <String, List<int>>{};
  int _seq = 0;

  /// The most recently recorded ping (drives the toast). Null until
  /// the first message is observed.
  HeatPing? lastPing;

  /// Record an observed message. [lat]/[lon] place it on the grid;
  /// when null the message contributes no heat (we can't place it)
  /// but still produces a [lastPing] so the view can toast it.
  HeatPing record({
    required String text,
    required int atUnix,
    double? lat,
    double? lon,
    String? pubKeyHex,
    bool isChannel = false,
  }) {
    if (lat != null &&
        lon != null &&
        lat.abs() <= 90.0 &&
        lon.abs() <= 180.0 &&
        !(lat.abs() < 1e-9 && lon.abs() < 1e-9)) {
      final ({int latBucket, int lonBucket}) b =
          CoverageStore.bucketFor(lat, lon);
      final String key =
          CoverageStore.cellKey(b.latBucket, b.lonBucket);
      (_cells[key] ??= <int>[]).add(atUnix);
    }
    lastPing = HeatPing(
      seq: ++_seq,
      text: text,
      atUnix: atUnix,
      pubKeyHex: pubKeyHex,
      latitude: lat,
      longitude: lon,
      isChannel: isChannel,
    );
    return lastPing!;
  }

  /// cellKey → hotness in [0, 1]. Prunes entries older than
  /// [horizon] as a side effect, and drops cells that empty out.
  Map<String, double> scores({int? nowUnix}) {
    final int now =
        nowUnix ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int horizonSec = horizon.inSeconds;
    final double tauSec = tau.inSeconds.toDouble();
    final Map<String, double> out = <String, double>{};
    final List<String> dead = <String>[];
    _cells.forEach((String key, List<int> times) {
      times.removeWhere((int t) => now - t > horizonSec);
      if (times.isEmpty) {
        dead.add(key);
        return;
      }
      double score = 0;
      for (final int t in times) {
        score += math.exp(-(now - t) / tauSec);
      }
      out[key] = (score / hotReference).clamp(0.0, 1.0);
    });
    for (final String k in dead) {
      _cells.remove(k);
    }
    return out;
  }

  /// Total cells currently carrying any heat (post-prune).
  int get activeCellCount => _cells.length;

  /// Wipe all tracked heat (used by tests + a possible reset button).
  void clear() {
    _cells.clear();
    lastPing = null;
  }
}
