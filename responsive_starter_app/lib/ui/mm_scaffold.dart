// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/mm_skin.dart';
import '../theme/theme_controller.dart';

/// Per-screen chrome wrapper. Paints the skin's base ground and overlays
/// its retro-futuristic ornament (CRT scanlines + corner brackets) once,
/// so every screen built on it inherits the look. Ornament is suppressed
/// under **reduce-motion** (UX-brief R13 parity rule).
class MmScaffold extends StatelessWidget {
  const MmScaffold({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final MmSkin skin = context.skin;
    bool reduceMotion = false;
    try {
      reduceMotion = context.watch<ThemeController>().reduceMotion;
    } on ProviderNotFoundException {
      // No ThemeController above us (isolated test) — assume motion ok.
    }
    final Widget body = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    final bool ornament = skin.ornament.any && !reduceMotion;
    return ColoredBox(
      color: skin.color.base,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: body),
          if (ornament)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SkinChromePainter(
                    scanlineOpacity: skin.ornament.scanlineOpacity,
                    brackets: skin.ornament.cornerBrackets,
                    accent: skin.color.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Draws CRT scanlines (faint dark horizontal rules) and NERV-style L
/// corner brackets. Static (no per-frame animation) so it never forces
/// a repaint.
class SkinChromePainter extends CustomPainter {
  const SkinChromePainter({
    required this.scanlineOpacity,
    required this.brackets,
    required this.accent,
  });

  final double scanlineOpacity;
  final bool brackets;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (scanlineOpacity > 0) {
      final Paint p = Paint()
        ..color = const Color(0xFF000000).withValues(alpha: scanlineOpacity)
        ..strokeWidth = 1;
      for (double y = 0; y < size.height; y += 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    }
    if (brackets) {
      const double len = 18, m = 6;
      final Paint p = Paint()
        ..color = accent.withValues(alpha: .8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final double w = size.width, h = size.height;
      canvas.drawPath(
          Path()
            ..moveTo(m, m + len)
            ..lineTo(m, m)
            ..lineTo(m + len, m),
          p);
      canvas.drawPath(
          Path()
            ..moveTo(w - m - len, m)
            ..lineTo(w - m, m)
            ..lineTo(w - m, m + len),
          p);
      canvas.drawPath(
          Path()
            ..moveTo(m, h - m - len)
            ..lineTo(m, h - m)
            ..lineTo(m + len, h - m),
          p);
      canvas.drawPath(
          Path()
            ..moveTo(w - m - len, h - m)
            ..lineTo(w - m, h - m)
            ..lineTo(w - m, h - m - len),
          p);
    }
  }

  @override
  bool shouldRepaint(SkinChromePainter old) =>
      old.scanlineOpacity != scanlineOpacity ||
      old.brackets != brackets ||
      old.accent != accent;
}
