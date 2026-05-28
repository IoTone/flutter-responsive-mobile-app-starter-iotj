// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';

/// Per-device power reference used by the battery-life estimator.
///
/// Mirrors the offline-first philosophy of the LoRa region presets:
/// the data is checked in (assets/data/device_power_specs.json) and
/// baked into the binary rather than fetched, because it changes
/// rarely and the app is mesh-first. The companion protocol exposes
/// only a free-form `DeviceInfo.manufacturer` string (+ firmware
/// version) as a hardware signal, so a spec is matched by
/// case-insensitive substring against those.
///
/// Parsing is pure (no Flutter / asset deps) so the model is unit
/// testable; the controller does the actual `rootBundle` load and
/// passes the decoded string here.
class DevicePowerSpec {
  const DevicePowerSpec({
    required this.id,
    required this.label,
    required this.chemistry,
    required this.cellCount,
    required this.fullVolts,
    required this.emptyVolts,
    required this.capacityMah,
    required this.ocvCurve,
    required this.currentMa,
    this.manufacturerMatch = const <String>[],
    this.firmwareMatch = const <String>[],
    this.notes,
    this.isGeneric = false,
  });

  /// Stable identifier (snake_case, never translated).
  final String id;

  /// Human-readable hardware name. Not translated (proper nouns).
  final String label;

  /// Cell chemistry tag — "liion", "lipo", … Informational; the OCV
  /// curve is what actually drives the SoC math.
  final String chemistry;

  final int cellCount;

  /// Pack-level full / empty voltages (already multiplied by
  /// [cellCount] semantics are out of scope — every shipped entry is
  /// 1S today, so these are per-cell == per-pack).
  final double fullVolts;
  final double emptyVolts;

  /// Typical pack capacity in mAh. 0 == unknown (board takes a
  /// user-supplied cell) — the estimator then skips the rated
  /// cross-check and relies on observed drain alone.
  final int capacityMah;

  /// Open-circuit-voltage → state-of-charge breakpoints, ascending by
  /// voltage: each entry is (volts, socPercent). Interpolated linearly
  /// between points and clamped at the ends. Always non-empty (the
  /// generic curve is inherited when a board omits its own).
  final List<({double volts, double soc})> ocvCurve;

  /// Approximate continuous current draw (mA) per workload, keyed by
  /// "idle" / "rx" / "tx". May be empty (unknown). The estimator uses
  /// the RX figure as the continuous baseline (MeshCore keeps the
  /// radio receiving), falling back to idle.
  final Map<String, double> currentMa;

  final List<String> manufacturerMatch;
  final List<String> firmwareMatch;
  final String? notes;

  /// True for the built-in fallback (no hardware matched).
  final bool isGeneric;

  /// Continuous baseline draw used for the rated estimate: prefer RX
  /// (radio always listening), else idle. Null when neither is known.
  double? get baselineCurrentMa => currentMa['rx'] ?? currentMa['idle'];

  /// True when a rated capacity-÷-current estimate is possible.
  bool get hasRating => capacityMah > 0 && (baselineCurrentMa ?? 0) > 0;

  /// Interpolate state-of-charge (0..100) for a resting voltage using
  /// the OCV curve. Clamps below the first / above the last point.
  double socForVolts(double volts) {
    final List<({double volts, double soc})> c = ocvCurve;
    if (c.isEmpty) return double.nan;
    if (volts <= c.first.volts) return c.first.soc;
    if (volts >= c.last.volts) return c.last.soc;
    for (int i = 0; i < c.length - 1; i++) {
      final ({double volts, double soc}) a = c[i];
      final ({double volts, double soc}) b = c[i + 1];
      if (volts >= a.volts && volts <= b.volts) {
        final double span = b.volts - a.volts;
        if (span <= 0) return a.soc;
        final double t = (volts - a.volts) / span;
        return a.soc + (b.soc - a.soc) * t;
      }
    }
    return c.last.soc;
  }

  /// Built-in last-resort fallback so the estimator always has a
  /// curve even if the JSON asset fails to load (e.g. in a plain unit
  /// test with no asset bundle). Mirrors the asset's "default" block.
  static const DevicePowerSpec genericLiion = DevicePowerSpec(
    id: 'generic_liion_1s',
    label: 'Generic single-cell Li-ion',
    chemistry: 'liion',
    cellCount: 1,
    fullVolts: 4.20,
    emptyVolts: 3.30,
    capacityMah: 0,
    isGeneric: true,
    currentMa: <String, double>{},
    ocvCurve: <({double volts, double soc})>[
      (volts: 3.30, soc: 0),
      (volts: 3.50, soc: 5),
      (volts: 3.68, soc: 10),
      (volts: 3.74, soc: 20),
      (volts: 3.77, soc: 30),
      (volts: 3.79, soc: 40),
      (volts: 3.82, soc: 50),
      (volts: 3.87, soc: 60),
      (volts: 3.92, soc: 70),
      (volts: 3.98, soc: 80),
      (volts: 4.08, soc: 90),
      (volts: 4.20, soc: 100),
    ],
  );
}

/// Parsed spec table: a default (fallback) spec + the matchable
/// device entries.
class DevicePowerSpecs {
  const DevicePowerSpecs({required this.fallback, required this.entries});

  final DevicePowerSpec fallback;
  final List<DevicePowerSpec> entries;

  /// The always-available built-in table (generic fallback, no
  /// device entries). Used before/if the asset loads.
  static const DevicePowerSpecs builtin = DevicePowerSpecs(
    fallback: DevicePowerSpec.genericLiion,
    entries: <DevicePowerSpec>[],
  );

  /// Resolve the best spec for a connected device. Matching is
  /// case-insensitive substring on the manufacturer (primary) and
  /// firmware version (secondary) strings. First match wins; the
  /// generic fallback is returned when nothing matches (or both
  /// inputs are null/empty).
  DevicePowerSpec resolve({String? manufacturer, String? firmware}) {
    final String mfr = (manufacturer ?? '').toLowerCase();
    final String fw = (firmware ?? '').toLowerCase();
    for (final DevicePowerSpec s in entries) {
      final bool mfrHit = s.manufacturerMatch
          .any((String m) => mfr.isNotEmpty && mfr.contains(m));
      final bool fwHit = s.firmwareMatch
          .any((String m) => fw.isNotEmpty && fw.contains(m));
      if (mfrHit || fwHit) return s;
    }
    return fallback;
  }

  /// Parse the checked-in JSON asset. Returns [builtin] on any error
  /// (malformed JSON, missing default) so the caller never has to
  /// null-check — there is always at least the generic fallback.
  static DevicePowerSpecs parse(String jsonString) {
    try {
      final Map<String, dynamic> doc =
          jsonDecode(jsonString) as Map<String, dynamic>;
      final DevicePowerSpec fallback = _specFromJson(
        doc['default'] as Map<String, dynamic>,
        defaultCurve: DevicePowerSpec.genericLiion.ocvCurve,
        isGeneric: true,
      );
      final List<DevicePowerSpec> entries = <DevicePowerSpec>[];
      final dynamic raw = doc['specs'];
      if (raw is List) {
        for (final dynamic e in raw) {
          if (e is Map<String, dynamic>) {
            entries.add(_specFromJson(e, defaultCurve: fallback.ocvCurve));
          }
        }
      }
      return DevicePowerSpecs(fallback: fallback, entries: entries);
    } catch (_) {
      return builtin;
    }
  }

  static DevicePowerSpec _specFromJson(
    Map<String, dynamic> j, {
    required List<({double volts, double soc})> defaultCurve,
    bool isGeneric = false,
  }) {
    List<({double volts, double soc})> curve = defaultCurve;
    final dynamic rawCurve = j['ocvCurve'];
    if (rawCurve is List && rawCurve.isNotEmpty) {
      final List<({double volts, double soc})> parsed =
          <({double volts, double soc})>[];
      for (final dynamic pt in rawCurve) {
        if (pt is List && pt.length >= 2) {
          parsed.add((
            volts: (pt[0] as num).toDouble(),
            soc: (pt[1] as num).toDouble(),
          ));
        }
      }
      if (parsed.isNotEmpty) {
        parsed.sort((a, b) => a.volts.compareTo(b.volts));
        curve = parsed;
      }
    }

    final Map<String, double> current = <String, double>{};
    final dynamic rawCurrent = j['currentMa'];
    if (rawCurrent is Map) {
      rawCurrent.forEach((dynamic k, dynamic v) {
        if (v is num) current[k.toString()] = v.toDouble();
      });
    }

    final dynamic match = j['match'];
    List<String> mfrMatch = const <String>[];
    List<String> fwMatch = const <String>[];
    if (match is Map) {
      mfrMatch = _lowerStrings(match['manufacturerContains']);
      fwMatch = _lowerStrings(match['firmwareContains']);
    }

    return DevicePowerSpec(
      id: (j['id'] ?? 'unknown').toString(),
      label: (j['label'] ?? 'Unknown device').toString(),
      chemistry: (j['chemistry'] ?? 'liion').toString(),
      cellCount: (j['cellCount'] as num?)?.toInt() ?? 1,
      fullVolts: (j['fullVolts'] as num?)?.toDouble() ?? 4.20,
      emptyVolts: (j['emptyVolts'] as num?)?.toDouble() ?? 3.30,
      capacityMah: (j['capacityMah'] as num?)?.toInt() ?? 0,
      ocvCurve: curve,
      currentMa: current,
      manufacturerMatch: mfrMatch,
      firmwareMatch: fwMatch,
      notes: j['notes']?.toString(),
      isGeneric: isGeneric,
    );
  }

  static List<String> _lowerStrings(dynamic v) {
    if (v is! List) return const <String>[];
    return <String>[
      for (final dynamic e in v)
        if (e != null && e.toString().trim().isNotEmpty)
          e.toString().toLowerCase(),
    ];
  }
}
