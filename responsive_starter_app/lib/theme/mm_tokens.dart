import 'package:flutter/material.dart';

/// The six design-concept themes (UX brief A–F). **D "SEELE Monolith"
/// = [MmThemePreset.seele] is the default** (also the high-contrast /
/// sunlight accessibility benchmark). Screens are built against the
/// semantic [MmTokens] names only — never hard-coded colours — so
/// every preset works (R14).
enum MmThemePreset { nerv, agHud, hyperlocal, seele, drPop, recon }

extension MmThemePresetX on MmThemePreset {
  String get label => switch (this) {
        MmThemePreset.nerv => 'NERV Terminal',
        MmThemePreset.agHud => 'AG-HUD',
        MmThemePreset.hyperlocal => 'Hyperlocal',
        MmThemePreset.seele => 'SEELE Monolith — default · high-contrast',
        MmThemePreset.drPop => 'DR Pop',
        MmThemePreset.recon => 'Recon Night',
      };
}

/// Preset-independent semantic colour contract. Every preset supplies
/// all nine; screens reference only these.
@immutable
class MmTokens {
  const MmTokens({
    required this.base,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.fg,
    required this.fgMuted,
    required this.accent,
    required this.alert,
    required this.ok,
  });

  final Color base;
  final Color surface;
  final Color surfaceAlt;
  final Color line;
  final Color fg;
  final Color fgMuted;
  final Color accent;
  final Color alert;
  final Color ok;
}

/// Catalogued from `meshmore-sns-UX-brief.md` (per-concept palettes).
const Map<MmThemePreset, MmTokens> kMmPresets = <MmThemePreset, MmTokens>{
  // D — default.
  MmThemePreset.seele: MmTokens(
    base: Color(0xFF000000),
    surface: Color(0xFF0E0E0C),
    surfaceAlt: Color(0xFF15140F),
    line: Color(0xFF2A2A26),
    fg: Color(0xFFEDE6D6),
    fgMuted: Color(0xFF9A958A),
    accent: Color(0xFFEDE6D6),
    alert: Color(0xFFC8102E),
    ok: Color(0xFF9A958A),
  ),
  MmThemePreset.nerv: MmTokens(
    base: Color(0xFF0A0E1A),
    surface: Color(0xFF121826),
    surfaceAlt: Color(0xFF1B2436),
    line: Color(0xFF243049),
    fg: Color(0xFFE6ECF5),
    fgMuted: Color(0xFF7C8AA3),
    accent: Color(0xFFFF7A00),
    alert: Color(0xFFE6005C),
    ok: Color(0xFF9CFF00),
  ),
  MmThemePreset.agHud: MmTokens(
    base: Color(0xFF05060B),
    surface: Color(0xFF10131F),
    surfaceAlt: Color(0xFF161B2A),
    line: Color(0xFF20283B),
    fg: Color(0xFFDDF6FF),
    fgMuted: Color(0xFF6F8196),
    accent: Color(0xFF22D3EE),
    alert: Color(0xFFFF2D78),
    ok: Color(0xFF22D3EE),
  ),
  MmThemePreset.hyperlocal: MmTokens(
    base: Color(0xFF0B0F17),
    surface: Color(0xFF161B26),
    surfaceAlt: Color(0xFF1E2533),
    line: Color(0xFF263041),
    fg: Color(0xFFDDE7EF),
    fgMuted: Color(0xFF7C8AA3),
    accent: Color(0xFF35E0F0),
    alert: Color(0xFFFF3B6B),
    ok: Color(0xFF7CFF6B),
  ),
  MmThemePreset.drPop: MmTokens(
    base: Color(0xFF101014),
    surface: Color(0xFF1C1C24),
    surfaceAlt: Color(0xFF24242E),
    line: Color(0xFF33333F),
    fg: Color(0xFFF2F0E6),
    fgMuted: Color(0xFF8A8A9A),
    accent: Color(0xFFFF2E88),
    alert: Color(0xFFFF2E88),
    ok: Color(0xFFD7FF00),
  ),
  MmThemePreset.recon: MmTokens(
    base: Color(0xFF000000),
    surface: Color(0xFF0A0A07),
    surfaceAlt: Color(0xFF141414),
    line: Color(0xFF6E4E00),
    fg: Color(0xFFFFB000),
    fgMuted: Color(0xFF6E4E00),
    accent: Color(0xFFFFB000),
    alert: Color(0xFFB3231F),
    ok: Color(0xFFFFB000),
  ),
};

MmThemePreset presetFromId(String? id) => MmThemePreset.values.firstWhere(
      (MmThemePreset p) => p.name == id,
      orElse: () => MmThemePreset.seele,
    );

/// Build a Material 3 dark [ThemeData] from a token set.
ThemeData buildMmTheme(MmTokens t) {
  final ColorScheme scheme = ColorScheme.dark(
    surface: t.base,
    onSurface: t.fg,
    primary: t.accent,
    onPrimary: t.base,
    secondary: t.accent,
    error: t.alert,
    onError: t.fg,
    outline: t.line,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.base,
    canvasColor: t.base,
    dividerColor: t.line,
    cardColor: t.surface,
    cardTheme: CardThemeData(
      color: t.surface,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.base,
      foregroundColor: t.fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: t.fgMuted,
      textColor: t.fg,
    ),
    dividerTheme: DividerThemeData(color: t.line, space: 1),
  );
}
