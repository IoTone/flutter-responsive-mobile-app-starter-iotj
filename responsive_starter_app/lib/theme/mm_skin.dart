// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'mm_tokens.dart';
import 'theme_controller.dart';

/// R54-follow-on — the **skin system**. A skin is more than a palette:
/// it bundles colour ([MmTokens]) with **typography**, **shape**, and
/// **ornament** tokens, so a preset can re-imagine a screen's *feel*
/// (chamfered HUD panels + scanlines vs. cream-on-black brutalism), not
/// just its hues. Screens read the active [MmSkin] via `context.skin`
/// and compose the branded widgets in `lib/ui/`, so reskinning is a
/// matter of defining a bundle — not editing every screen.
///
/// Today colour is fully realised across the app (the ThemeData path);
/// this layer adds the missing dimensions the UX brief specifies
/// (per-concept components, type, and ornament) for screens migrated to
/// the component library.

enum MmCorner { sharp, rounded, chamfer }

/// Typography roles. Families are font names (or null = platform
/// default); the app bundles no custom face yet, so the "futuristic"
/// concepts lean on the platform monospace + tracked uppercase (the
/// established convention) rather than a TTF.
@immutable
class MmType {
  const MmType({
    this.displayFamily,
    this.headingFamily,
    this.monoFamily = 'monospace',
    this.bodyFamily,
    this.upperHeadings = false,
    this.headingTracking = 1.0,
    this.slashedZero = false,
  });

  final String? displayFamily;
  final String? headingFamily;
  final String monoFamily;
  final String? bodyFamily;

  /// Render section labels in UPPER CASE (terminal/HUD concepts).
  final bool upperHeadings;

  /// letterSpacing applied to section labels.
  final double headingTracking;

  /// Request the font's slashed-zero feature on telemetry numerals (the
  /// Evangelion "SOUND ONLY" motif). Applied by components via
  /// `FontFeature.slashedZero()` when the face supports it.
  final bool slashedZero;
}

/// Panel/edge treatment.
@immutable
class MmShape {
  const MmShape({
    required this.corner,
    required this.cornerSize,
    required this.borderWidth,
  });

  final MmCorner corner;

  /// Radius (rounded) or cut depth (chamfer), in logical px.
  final double cornerSize;
  final double borderWidth;
}

/// Retro-futuristic chrome. All default to "off" so a calm concept
/// (SEELE) gets none; loud concepts (NERV) opt in.
@immutable
class MmOrnament {
  const MmOrnament({
    this.scanlineOpacity = 0.0,
    this.cornerBrackets = false,
    this.warningStripes = false,
  });

  /// 0 = no scanlines; ~0.04–0.08 is a subtle CRT overlay.
  final double scanlineOpacity;

  /// Draw NERV-style L brackets in the screen corners.
  final bool cornerBrackets;

  /// Section headers get a diagonal hazard-stripe bar.
  final bool warningStripes;

  bool get any => scanlineOpacity > 0 || cornerBrackets || warningStripes;
}

/// The full active skin: colour + type + shape + ornament for a preset.
@immutable
class MmSkin {
  const MmSkin({
    required this.preset,
    required this.color,
    required this.type,
    required this.shape,
    required this.ornament,
  });

  final MmThemePreset preset;
  final MmTokens color;
  final MmType type;
  final MmShape shape;
  final MmOrnament ornament;
}

// The brief's OSS type spine: Saira (Eurostile-class display) +
// JetBrains Mono (telemetry, slashed-zero). Shared default until each
// concept's faces are elaborated.
const MmType _defaultType = MmType(
  displayFamily: 'Saira',
  headingFamily: 'Saira',
  monoFamily: 'JetBrains Mono',
  headingTracking: 2.0,
  slashedZero: true,
);
const MmShape _defaultShape = MmShape(
    corner: MmCorner.rounded, cornerSize: 10, borderWidth: 1);
const MmOrnament _calmOrnament = MmOrnament();

/// Build the [MmSkin] bundle for a preset. Colour comes from the shared
/// [kMmPresets]; type/shape/ornament are spec'd per concept (NERV and
/// SEELE detailed here as the first migrated concepts; the rest take a
/// sensible default until they're elaborated).
MmSkin mmSkinFor(MmThemePreset preset) {
  final MmTokens color = kMmPresets[preset]!;
  switch (preset) {
    // A — NERV Terminal: chamfered HUD panels, hazard-stripe headers,
    // a subtle scanline, corner brackets, uppercase tracked mono.
    case MmThemePreset.nerv:
      return MmSkin(
        preset: preset,
        color: color,
        type: const MmType(
          displayFamily: 'Saira',
          headingFamily: 'Saira',
          monoFamily: 'JetBrains Mono',
          upperHeadings: true,
          headingTracking: 3.0,
          slashedZero: true,
        ),
        shape: const MmShape(
            corner: MmCorner.chamfer, cornerSize: 12, borderWidth: 1.2),
        ornament: const MmOrnament(
          scanlineOpacity: 0.06,
          cornerBrackets: true,
          warningStripes: true,
        ),
      );
    // D — SEELE Monolith: brutalist, near-zero chrome, sharp edges,
    // ruthless type hierarchy. (The home dashboard already embodies
    // this; the bundle exists for components used elsewhere.)
    case MmThemePreset.seele:
      return MmSkin(
        preset: preset,
        color: color,
        type: const MmType(
          displayFamily: 'Saira',
          monoFamily: 'JetBrains Mono',
          upperHeadings: true,
          headingTracking: 4.0,
          slashedZero: true,
        ),
        shape: const MmShape(
            corner: MmCorner.sharp, cornerSize: 0, borderWidth: 1),
        ornament: _calmOrnament,
      );
    // B — AG Systems HUD: a Wipeout anti-grav cockpit. Big angular
    // display metrics, soft *rounded* livery panels, cyan/magenta accents,
    // minimal chrome (the radial gauges carry the motion, not scanlines).
    case MmThemePreset.agHud:
      return MmSkin(
        preset: preset,
        color: color,
        type: const MmType(
          displayFamily: 'Saira',
          headingFamily: 'Saira',
          monoFamily: 'JetBrains Mono',
          upperHeadings: true,
          headingTracking: 2.5,
          slashedZero: true,
        ),
        shape: const MmShape(
            corner: MmCorner.rounded, cornerSize: 18, borderWidth: 1.4),
        ornament: _calmOrnament,
      );
    // C — Hyperlocal Field: discovery-first, calm and field-legible.
    // Lower visual noise than NERV (no scanlines/brackets/stripes — the
    // node radar is the visual interest), soft rounded panels, Saira
    // headers in mixed case (calmer than the terminal's tracked caps),
    // mono for raw telemetry. AA+ contrast comes from the token set.
    case MmThemePreset.hyperlocal:
      return MmSkin(
        preset: preset,
        color: color,
        type: const MmType(
          displayFamily: 'Saira',
          headingFamily: 'Saira',
          monoFamily: 'JetBrains Mono',
          headingTracking: 2.0,
          slashedZero: true,
        ),
        shape: const MmShape(
            corner: MmCorner.rounded, cornerSize: 14, borderWidth: 1),
        ornament: _calmOrnament,
      );
    // E — DR Pop: Designers-Republic maximalism. Flat saturated colour
    // blocks, bold numerals, katakana-as-graphics, fake per-channel
    // sub-brands. Hard rectangles (sharp), heavy tracked caps; no CRT
    // chrome — the colour blocking is the whole look.
    case MmThemePreset.drPop:
      return MmSkin(
        preset: preset,
        color: color,
        type: const MmType(
          displayFamily: 'Saira',
          headingFamily: 'Saira',
          monoFamily: 'JetBrains Mono',
          upperHeadings: true,
          headingTracking: 1.5,
          slashedZero: true,
        ),
        shape: const MmShape(
            corner: MmCorner.sharp, cornerSize: 0, borderWidth: 1),
        ornament: _calmOrnament,
      );
    default:
      return MmSkin(
        preset: preset,
        color: color,
        type: _defaultType,
        shape: _defaultShape,
        ornament: _calmOrnament,
      );
  }
}

/// `context.skin` — the active skin bundle. Watches [ThemeController]
/// so widgets rebuild when the preset (or high-contrast) changes.
/// High-contrast forces the SEELE skin (the accessibility benchmark).
///
/// Tolerant of a missing [ThemeController] (e.g. an isolated widget
/// test, or a component used before the provider tree is set up): it
/// falls back to the default SEELE skin rather than throwing, so
/// migrating a screen to the component library never forces its test
/// harness to also wire a ThemeController.
extension MmSkinContext on BuildContext {
  MmSkin get skin {
    MmThemePreset preset = MmThemePreset.seele;
    try {
      final ThemeController tc = watch<ThemeController>();
      preset = tc.highContrast ? MmThemePreset.seele : tc.preset;
    } on ProviderNotFoundException {
      // No ThemeController above us — default skin.
    }
    return mmSkinFor(preset);
  }
}
