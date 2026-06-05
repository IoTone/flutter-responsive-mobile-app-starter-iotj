// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/painting.dart';

import 'mm_skin.dart';

/// R55 — semantic colours for the **visualisation painters** (radar,
/// heat map, maps, charts), derived from the active [MmSkin] so the
/// grid/map views follow the theme instead of baking in literal hex.
///
/// The painters take these roles instead of `const Color(0x…)`, so a
/// theme switch reskins them along with the rest of the UI. Map the
/// viz-semantic roles onto the nine skin colour tokens:
///   hot      → alert (heat peak)
///   cool     → fg    (heat floor — tints with the theme ground)
///   node     → fgMuted
///   self     → accent
///   inferred → accent (distinguished from self/nodes by *shape*)
///   grid     → line
class VizPalette {
  const VizPalette({
    required this.hot,
    required this.cool,
    required this.node,
    required this.self,
    required this.inferred,
    required this.accent,
    required this.grid,
  });

  final Color hot;
  final Color cool;
  final Color node;
  final Color self;
  final Color inferred;
  final Color accent;
  final Color grid;

  factory VizPalette.of(MmSkin skin) => VizPalette(
        hot: skin.color.alert,
        cool: skin.color.fg,
        node: skin.color.fgMuted,
        self: skin.color.accent,
        inferred: skin.color.accent,
        accent: skin.color.accent,
        grid: skin.color.line,
      );
}
