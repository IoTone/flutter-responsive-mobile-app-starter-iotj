import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/theme/mm_tokens.dart';
import 'package:meshmore_sns_app/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('all six presets defined, distinct, non-degenerate', () {
    expect(MmThemePreset.values, hasLength(6));
    expect(kMmPresets.length, 6);
    final Set<int> bases = <int>{
      for (final MmThemePreset p in MmThemePreset.values)
        // ignore: deprecated_member_use
        kMmPresets[p]!.base.value,
    };
    expect(bases.length, greaterThanOrEqualTo(4),
        reason: 'preset backgrounds should not all be identical');
  });

  test('default preset is D / SEELE with no stored prefs', () async {
    final ThemeController c = ThemeController();
    expect(c.preset, MmThemePreset.seele);
    await c.load();
    expect(c.preset, MmThemePreset.seele);
    expect(c.audioMaster, isFalse, reason: 'audio off by default (R12/R5)');
  });

  test('setPreset notifies and persists across reload', () async {
    final ThemeController c = ThemeController();
    int notified = 0;
    c.addListener(() => notified++);
    await c.setPreset(MmThemePreset.recon);
    expect(c.preset, MmThemePreset.recon);
    expect(notified, greaterThan(0));

    final ThemeController c2 = ThemeController();
    await c2.load();
    expect(c2.preset, MmThemePreset.recon);
  });

  test('font scale clamps to [0.8, 1.6] and persists', () async {
    final ThemeController c = ThemeController();
    await c.setFontScale(9.0);
    expect(c.fontScale, 1.6);
    await c.setFontScale(0.1);
    expect(c.fontScale, 0.8);

    final ThemeController c2 = ThemeController();
    await c2.load();
    expect(c2.fontScale, 0.8);
  });

  test('high contrast forces the SEELE token set regardless of preset',
      () async {
    final ThemeController c = ThemeController();
    await c.setPreset(MmThemePreset.recon);
    await c.setHighContrast(true);
    final ThemeData t = c.theme;
    expect(t.scaffoldBackgroundColor,
        kMmPresets[MmThemePreset.seele]!.base);
  });

  test('visual+haptic-only forces audio off', () async {
    final ThemeController c = ThemeController();
    await c.setAudioMaster(true);
    expect(c.audioMaster, isTrue);
    await c.setVisualHapticOnly(true);
    expect(c.visualHapticOnly, isTrue);
    expect(c.audioMaster, isFalse);

    final ThemeController c2 = ThemeController();
    await c2.load();
    expect(c2.audioMaster, isFalse);
    expect(c2.visualHapticOnly, isTrue);
  });

  test('buildMmTheme maps tokens to the colour scheme', () {
    final MmTokens t = kMmPresets[MmThemePreset.seele]!;
    final ThemeData td = buildMmTheme(t);
    expect(td.scaffoldBackgroundColor, t.base);
    expect(td.colorScheme.error, t.alert);
    expect(td.colorScheme.primary, t.accent);
    expect(td.brightness, Brightness.dark);
  });
}
