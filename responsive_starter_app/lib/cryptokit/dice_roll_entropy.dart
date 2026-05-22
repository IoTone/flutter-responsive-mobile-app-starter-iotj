// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// R32 — accelerometer-driven PSK derivation.
///
/// We listen to the device's accelerometer, accept each sample
/// whose **delta-magnitude** from the prior sample exceeds a small
/// threshold (so the device sitting still doesn't add entropy),
/// and fold the raw float bytes of every accepted sample into a
/// running **SHA-256**. The digest at any time is a 32-byte value;
/// when enough motion has accumulated we take the first 16 bytes
/// as the AES-128 PSK.
///
/// Entropy accounting is conservative — we count each accepted
/// sample as roughly 4 bits of usable entropy (humans aren't great
/// random sources). Default target = 64 accepted samples ≈ 256
/// bits, which on a hand-shake typically completes in 3-5 seconds.
class DiceRollEntropy extends ChangeNotifier {
  DiceRollEntropy({
    Stream<AccelerometerEvent>? stream,
    this.targetBits = 256,
    this.bitsPerSample = 4,
    this.deltaThreshold = 1.6,
  }) : _stream = stream ?? accelerometerEventStream();

  final Stream<AccelerometerEvent> _stream;

  /// Stop accepting samples (and report `complete`) once this many
  /// bits of estimated entropy have been folded in.
  final int targetBits;

  /// Conservative bits-of-entropy credited to each accepted sample.
  /// 4 bits is conservative — a hand-shake delivers more, but
  /// underestimating is safer.
  final int bitsPerSample;

  /// Minimum delta-magnitude (in m/s²) between consecutive samples
  /// to count as motion. Default 1.6 ≈ a gentle wrist-flick.
  final double deltaThreshold;

  StreamSubscription<AccelerometerEvent>? _sub;
  double? _lastMag;

  /// Running digest — we re-hash the accumulated buffer each sample
  /// because `sha256` doesn't expose an incremental API in
  /// package:crypto. Cheap (a few hundred bytes max).
  final BytesBuilder _accum = BytesBuilder();
  Digest _digest = sha256.convert(<int>[]);
  int _accepted = 0;

  /// True once enough motion has been collected to derive a key.
  bool get complete => _accepted * bitsPerSample >= targetBits;

  /// 0..1 progress estimate (clamped).
  double get progress {
    final double p = (_accepted * bitsPerSample) / targetBits;
    return p.clamp(0.0, 1.0);
  }

  /// Number of motion samples accepted so far. Useful for the UI
  /// "you've shaken N / target" copy.
  int get acceptedSamples => _accepted;

  /// Current 32-byte digest. Returns a fresh defensive copy.
  List<int> get digest => List<int>.unmodifiable(_digest.bytes);

  /// First 16 bytes of the current digest — the candidate PSK.
  /// Always callable, but only meaningful once `complete`.
  List<int> get psk => List<int>.unmodifiable(_digest.bytes.sublist(0, 16));

  /// Begin listening. Idempotent.
  void start() {
    if (_sub != null) return;
    _sub = _stream.listen(_onSample);
  }

  /// Stop listening and reset all state. The digest is wiped so a
  /// fresh `start()` begins from zero entropy.
  void reset() {
    _sub?.cancel();
    _sub = null;
    _lastMag = null;
    _accepted = 0;
    _accum.clear();
    _digest = sha256.convert(<int>[]);
    notifyListeners();
  }

  /// Stop listening without wiping state. Call this to *freeze* the
  /// current key candidate (e.g. when the user taps "Use this").
  void freeze() {
    _sub?.cancel();
    _sub = null;
  }

  /// Feed a synthetic sample (test path).
  @visibleForTesting
  void inject(double x, double y, double z) =>
      _onSample(AccelerometerEvent(x, y, z, DateTime.now()));

  /// reduceMotion fallback: cross the completion threshold by
  /// folding `Random.secure` bytes through the same accumulator
  /// path, without subscribing to the accelerometer. Same surface
  /// as the motion path; the resulting digest is just as strong
  /// (arguably stronger, since `Random.secure` is OS-RNG).
  void seedFromSecureRandom() {
    final math.Random r = math.Random.secure();
    final int target = (targetBits / bitsPerSample).ceil();
    while (_accepted < target) {
      _onSample(AccelerometerEvent(
        r.nextDouble() * 20 - 10,
        r.nextDouble() * 20 - 10,
        r.nextDouble() * 20 - 10,
        DateTime.now(),
      ));
    }
  }

  void _onSample(AccelerometerEvent e) {
    final double mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final double? prev = _lastMag;
    _lastMag = mag;
    if (prev == null) return; // need a baseline to compute delta
    if ((mag - prev).abs() < deltaThreshold) return;

    // Fold the raw float bytes of the accepted sample into the
    // accumulator + re-hash. ByteData layout: [x f32][y f32][z f32].
    final ByteData bd = ByteData(12)
      ..setFloat32(0, e.x)
      ..setFloat32(4, e.y)
      ..setFloat32(8, e.z);
    _accum.add(bd.buffer.asUint8List());
    _digest = sha256.convert(_accum.takeBytes());
    // takeBytes() emptied the builder — re-seed with the digest so
    // the next round keeps building on the prior state.
    _accum.add(_digest.bytes);
    _accepted++;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
