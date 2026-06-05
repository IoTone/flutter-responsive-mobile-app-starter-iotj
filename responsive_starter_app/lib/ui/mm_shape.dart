// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/mm_skin.dart';

/// A rectangle with 45° **chamfered** (cut) corners — the NERV / HUD
/// panel signature. Used via [mmShapeBorder] from the active skin.
class MmChamferBorder extends OutlinedBorder {
  const MmChamferBorder({super.side = BorderSide.none, this.cut = 12});

  final double cut;

  @override
  MmChamferBorder copyWith({BorderSide? side, double? cut}) =>
      MmChamferBorder(side: side ?? this.side, cut: cut ?? this.cut);

  @override
  ShapeBorder scale(double t) =>
      MmChamferBorder(side: side.scale(t), cut: cut * t);

  Path _path(Rect r, double c) {
    final double k = c.clamp(0.0, math.min(r.width, r.height) / 2);
    return Path()
      ..moveTo(r.left + k, r.top)
      ..lineTo(r.right - k, r.top)
      ..lineTo(r.right, r.top + k)
      ..lineTo(r.right, r.bottom - k)
      ..lineTo(r.right - k, r.bottom)
      ..lineTo(r.left + k, r.bottom)
      ..lineTo(r.left, r.bottom - k)
      ..lineTo(r.left, r.top + k)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width), cut);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect, cut);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(getOuterPath(rect), side.toPaint());
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
}

/// The [OutlinedBorder] for a skin's [MmShape] — sharp, rounded, or
/// chamfered — carrying the given [side].
OutlinedBorder mmShapeBorder(MmShape shape, {required BorderSide side}) =>
    switch (shape.corner) {
      MmCorner.sharp => RoundedRectangleBorder(side: side),
      MmCorner.rounded => RoundedRectangleBorder(
          side: side,
          borderRadius: BorderRadius.circular(shape.cornerSize)),
      MmCorner.chamfer =>
        MmChamferBorder(side: side, cut: shape.cornerSize),
    };
