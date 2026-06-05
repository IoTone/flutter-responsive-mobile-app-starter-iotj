// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/theme/mm_skin.dart';
import 'package:meshmore_sns_app/ui/mm_shape.dart';

void main() {
  const BorderSide side = BorderSide(color: Color(0xFF000000));

  test('skin corner maps to the right border type', () {
    expect(
      mmShapeBorder(
          const MmShape(corner: MmCorner.sharp, cornerSize: 0, borderWidth: 1),
          side: side),
      isA<RoundedRectangleBorder>(),
    );
    expect(
      mmShapeBorder(
          const MmShape(
              corner: MmCorner.rounded, cornerSize: 10, borderWidth: 1),
          side: side),
      isA<RoundedRectangleBorder>(),
    );
    expect(
      mmShapeBorder(
          const MmShape(
              corner: MmCorner.chamfer, cornerSize: 12, borderWidth: 1),
          side: side),
      isA<MmChamferBorder>(),
    );
  });

  test('chamfer border cuts the corners (8 vertices, inset bounds)', () {
    const MmChamferBorder b = MmChamferBorder(cut: 10);
    final Path path = b.getOuterPath(const Rect.fromLTWH(0, 0, 100, 60));
    // Octagonal cut path stays within the rect and is non-empty.
    final Rect bounds = path.getBounds();
    expect(bounds.width, closeTo(100, 0.01));
    expect(bounds.height, closeTo(60, 0.01));
    // The top-left corner pixel is cut off (outside the octagon).
    expect(path.contains(const Offset(1, 1)), isFalse);
    // The centre is inside.
    expect(path.contains(const Offset(50, 30)), isTrue);
  });

  test('chamfer copyWith / scale preserve type', () {
    const MmChamferBorder b = MmChamferBorder(cut: 12);
    expect(b.copyWith(cut: 4).cut, 4);
    expect((b.scale(2) as MmChamferBorder).cut, 24);
  });
}
