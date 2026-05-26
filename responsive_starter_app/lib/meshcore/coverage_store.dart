// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// F8 — persistent mesh-coverage record.
///
/// We log a cell every time we observe **mesh activity at a known
/// location**: an inbound advert / message while our GPS is fresh
/// (= "the mesh reached us here"), or a peer's advertised lat/lon
/// (= "the mesh extends to here"). Cells are quantised into a
/// fixed-degree grid so the storage stays bounded as the user roams
/// thousands of kilometres.
///
/// Distinct from R36's auto-publish trail (where we *went*) and from
/// R25's equal-grid (where peers are *right now*). F8 is the longer-
/// view "where does my mesh actually exist" answer — patchwork with
/// holes, surveyed over multiple sessions.
class CoverageStore {
  CoverageStore._();

  /// Cell edge length in degrees. 0.002° ≈ 220 m at the equator,
  /// ~155 m at 45° latitude. Fine enough that a city street pattern
  /// becomes visible at metro zoom; coarse enough that 1000 cells
  /// covers ~50 km on a side.
  static const double cellDeg = 0.002;

  /// Cap on the number of cells we persist. Drops the oldest entry
  /// when exceeded. 2000 × ~155 m × ~155 m ≈ 50 km² of coverage at
  /// mid-latitude, which is well beyond practical LoRa reach.
  static const int maxCells = 2000;

  static const String _kKey = 'mm.coverage.v1';

  /// Integer cell-bucket coordinates derived from a lat/lon.
  static ({int latBucket, int lonBucket}) bucketFor(
      double lat, double lon) {
    return (
      latBucket: (lat / cellDeg).floor(),
      lonBucket: (lon / cellDeg).floor(),
    );
  }

  /// Geographic centre of a cell (used by the painter to project the
  /// cell rectangle into screen space).
  static ({double lat, double lon}) cellCentre(
      int latBucket, int lonBucket) {
    return (
      lat: latBucket * cellDeg + cellDeg / 2,
      lon: lonBucket * cellDeg + cellDeg / 2,
    );
  }

  /// Pack a cell key for shared_preferences. Single string of
  /// `<latBucket>,<lonBucket>` — compact, JSON-safe, easy to
  /// debug-print.
  static String cellKey(int latBucket, int lonBucket) =>
      '$latBucket,$lonBucket';

  /// Inverse of [cellKey]. Returns null on malformed input rather
  /// than throwing — corrupt persisted entries are silently dropped.
  static ({int latBucket, int lonBucket})? parseKey(String key) {
    final int comma = key.indexOf(',');
    if (comma <= 0 || comma == key.length - 1) return null;
    final int? la = int.tryParse(key.substring(0, comma));
    final int? lo = int.tryParse(key.substring(comma + 1));
    if (la == null || lo == null) return null;
    return (latBucket: la, lonBucket: lo);
  }

  static Future<Map<String, int>> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString(_kKey);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final Map<String, dynamic> doc =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, int> out = <String, int>{};
      // Cell bucket ranges: lat = round-down of degrees / cellDeg.
      // At cellDeg = 0.002, valid lat buckets are [-45000, 45000] and
      // valid lon buckets are [-90000, 90000]. Anything outside is a
      // corrupted entry (typically from a peer's malformed advert
      // that got persisted before this guard existed) and must be
      // dropped — flutter_map polygon assertions reject lat/lon
      // outside ±90 / ±180.
      final int maxLatBucket = (90.0 / cellDeg).ceil();
      final int maxLonBucket = (180.0 / cellDeg).ceil();
      doc.forEach((String k, dynamic v) {
        if (v is! num) return;
        final ({int latBucket, int lonBucket})? b = parseKey(k);
        if (b == null) return;
        if (b.latBucket.abs() > maxLatBucket ||
            b.lonBucket.abs() > maxLonBucket) {
          return;
        }
        out[k] = v.toInt();
      });
      return out;
    } catch (_) {
      return <String, int>{};
    }
  }

  static Future<void> save(Map<String, int> cells) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(_kKey, jsonEncode(cells));
  }

  static Future<void> clear() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}
