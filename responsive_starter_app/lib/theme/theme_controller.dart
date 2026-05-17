import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mm_tokens.dart';

/// User-customizable appearance & accessibility (R14 / R12 / R13).
///
/// Holds the active theme preset (default **D / SEELE**), a font-size
/// scale layered on top of the OS text scale, and the accessibility /
/// audio preference flags. Persisted via `shared_preferences`; the
/// rest of the app reads only this (single source of truth).
class ThemeController extends ChangeNotifier {
  static const String _kPreset = 'mm.preset';
  static const String _kFontScale = 'mm.fontScale';
  static const String _kHighContrast = 'mm.highContrast';
  static const String _kReduceMotion = 'mm.reduceMotion';
  static const String _kAudioMaster = 'mm.audioMaster';
  static const String _kVisualHapticOnly = 'mm.visualHapticOnly';

  MmThemePreset _preset = MmThemePreset.seele; // D — default
  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;
  bool _audioMaster = false; // audio alerts off by default (R5/R12)
  bool _visualHapticOnly = false;

  MmThemePreset get preset => _preset;
  double get fontScale => _fontScale;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  bool get audioMaster => _audioMaster;
  bool get visualHapticOnly => _visualHapticOnly;

  MmTokens get tokens => kMmPresets[_preset]!;

  /// Forced to the high-contrast SEELE token set when [highContrast]
  /// is on, regardless of the chosen preset.
  ThemeData get theme => buildMmTheme(
        _highContrast ? kMmPresets[MmThemePreset.seele]! : tokens,
      );

  /// Load persisted preferences. Safe to call once at startup.
  Future<void> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    _preset = presetFromId(p.getString(_kPreset));
    _fontScale = (p.getDouble(_kFontScale) ?? 1.0).clamp(0.8, 1.6);
    _highContrast = p.getBool(_kHighContrast) ?? false;
    _reduceMotion = p.getBool(_kReduceMotion) ?? false;
    _audioMaster = p.getBool(_kAudioMaster) ?? false;
    _visualHapticOnly = p.getBool(_kVisualHapticOnly) ?? false;
    notifyListeners();
  }

  Future<void> _save(void Function(SharedPreferences p) write) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    write(p);
  }

  Future<void> setPreset(MmThemePreset v) async {
    if (v == _preset) return;
    _preset = v;
    notifyListeners();
    await _save((SharedPreferences p) => p.setString(_kPreset, v.name));
  }

  Future<void> setFontScale(double v) async {
    final double c = v.clamp(0.8, 1.6);
    if (c == _fontScale) return;
    _fontScale = c;
    notifyListeners();
    await _save((SharedPreferences p) => p.setDouble(_kFontScale, c));
  }

  Future<void> setHighContrast(bool v) async {
    _highContrast = v;
    notifyListeners();
    await _save((SharedPreferences p) => p.setBool(_kHighContrast, v));
  }

  Future<void> setReduceMotion(bool v) async {
    _reduceMotion = v;
    notifyListeners();
    await _save((SharedPreferences p) => p.setBool(_kReduceMotion, v));
  }

  Future<void> setAudioMaster(bool v) async {
    _audioMaster = v;
    notifyListeners();
    await _save((SharedPreferences p) => p.setBool(_kAudioMaster, v));
  }

  Future<void> setVisualHapticOnly(bool v) async {
    _visualHapticOnly = v;
    // Mutually reinforcing: visual+haptic-only implies audio off.
    if (v) _audioMaster = false;
    notifyListeners();
    await _save((SharedPreferences p) {
      p.setBool(_kVisualHapticOnly, v);
      if (v) p.setBool(_kAudioMaster, false);
    });
  }
}
