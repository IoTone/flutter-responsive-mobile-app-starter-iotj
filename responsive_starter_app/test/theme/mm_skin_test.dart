// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/theme/mm_skin.dart';
import 'package:meshmore_sns_app/theme/mm_tokens.dart';

void main() {
  test('every preset resolves to a skin carrying its colour tokens', () {
    for (final MmThemePreset p in MmThemePreset.values) {
      final MmSkin s = mmSkinFor(p);
      expect(s.preset, p);
      expect(s.color, kMmPresets[p]);
    }
  });

  test('NERV is the loud HUD concept (chamfer + full ornament)', () {
    final MmSkin s = mmSkinFor(MmThemePreset.nerv);
    expect(s.shape.corner, MmCorner.chamfer);
    expect(s.ornament.cornerBrackets, isTrue);
    expect(s.ornament.warningStripes, isTrue);
    expect(s.ornament.scanlineOpacity, greaterThan(0));
    expect(s.ornament.any, isTrue);
    expect(s.type.upperHeadings, isTrue);
    expect(s.color.accent, kMmPresets[MmThemePreset.nerv]!.accent);
  });

  test('SEELE is the calm brutalist concept (sharp, no ornament)', () {
    final MmSkin s = mmSkinFor(MmThemePreset.seele);
    expect(s.shape.corner, MmCorner.sharp);
    expect(s.ornament.any, isFalse);
    expect(s.ornament.scanlineOpacity, 0);
  });

  test('an un-elaborated concept gets a calm default skin', () {
    final MmSkin s = mmSkinFor(MmThemePreset.hyperlocal);
    expect(s.color, kMmPresets[MmThemePreset.hyperlocal]);
    expect(s.ornament.any, isFalse);
    expect(s.shape.corner, MmCorner.rounded);
  });
}
