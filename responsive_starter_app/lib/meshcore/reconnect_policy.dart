// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math';

/// Exponential-backoff-with-full-jitter policy for reconnecting the
/// companion link. Pure and deterministic when given a fixed [random],
/// so it is fully unit-testable.
///
/// Attempt is 1-based. The un-jittered ceiling for attempt _n_ is
/// `min(base · 2^(n-1), max)`; the actual delay is uniformly random in
/// `[0, ceiling]` (AWS "full jitter"). [maxAttempts] of 0 means
/// "retry forever".
class ReconnectPolicy {
  ReconnectPolicy({
    this.base = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
    this.maxAttempts = 8,
    double Function()? random,
  }) : _rand = random ?? Random().nextDouble;

  final Duration base;
  final Duration max;
  final int maxAttempts;
  final double Function() _rand;

  bool shouldRetry(int attempt) =>
      maxAttempts == 0 || attempt <= maxAttempts;

  /// Backoff delay for a 1-based [attempt].
  Duration delayForAttempt(int attempt) {
    assert(attempt >= 1, 'attempt is 1-based');
    final int shift = (attempt - 1).clamp(0, 30);
    final int ceilMs =
        min(base.inMilliseconds * (1 << shift), max.inMilliseconds);
    final double r = _rand().clamp(0.0, 1.0);
    return Duration(milliseconds: (ceilMs * r).round());
  }
}
