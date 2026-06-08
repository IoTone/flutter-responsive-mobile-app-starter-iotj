// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted last-used preferences for the hyperlocal grid screen, so the
/// chosen view, scale, orientation, and refresh cadence survive leaving
/// and re-opening the grid (the screen is recreated on each navigation)
/// and app restarts.
class GridPrefs {
  const GridPrefs({
    this.modeIndex = 0,
    this.scaleIndex = -1, // -1 = use the screen's default
    this.northUp = true,
    this.live = false,
    this.intervalSec = 15,
  });

  final int modeIndex; // _GridViewMode.index
  final int scaleIndex;
  final bool northUp;
  final bool live;
  final int intervalSec;

  Map<String, Object?> toJson() => <String, Object?>{
        'mode': modeIndex,
        'scale': scaleIndex,
        'north': northUp,
        'live': live,
        'iv': intervalSec,
      };

  static GridPrefs fromJson(Map<String, dynamic> j) => GridPrefs(
        modeIndex: (j['mode'] as num?)?.toInt() ?? 0,
        scaleIndex: (j['scale'] as num?)?.toInt() ?? -1,
        northUp: j['north'] as bool? ?? true,
        live: j['live'] as bool? ?? false,
        intervalSec: (j['iv'] as num?)?.toInt() ?? 15,
      );
}

abstract final class GridPrefsStore {
  static const String _kKey = 'mm.gridPrefs.v1';

  static Future<GridPrefs?> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final String? raw = p.getString(_kKey);
    if (raw == null) return null;
    try {
      return GridPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(GridPrefs prefs) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(_kKey, jsonEncode(prefs.toJson()));
  }
}
