// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Branded Flutter-side splash. The native splash (`flutter_native_splash`)
/// shows for the few hundred ms between OS app-start and the first
/// Flutter frame; this widget then takes over with theme-aware copy
/// and a continuously rotating icon until `MyApp` is ready to mount
/// the real home tree.
///
/// Pure presentation — owns its rotation animation + a version-read
/// future. The min-display gate lives in `main.dart` so this stays
/// reusable.
class BrandedSplashScreen extends StatefulWidget {
  const BrandedSplashScreen({super.key});

  @override
  State<BrandedSplashScreen> createState() => _BrandedSplashScreenState();
}

class _BrandedSplashScreenState extends State<BrandedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    final ColorScheme cs = t.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Flutter-rendered brand mark (no asset dep so it
              // always reflects the active theme + doesn't fall
              // back to a stale launcher template).
              RotationTransition(
                turns: _spin,
                child: CustomPaint(
                  size: const Size(96, 96),
                  painter: _BrandMarkPainter(
                    accent: cs.primary,
                    alt: cs.tertiary,
                    bg: cs.surface,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Meshmore SNS',
                style: t.textTheme.headlineSmall?.copyWith(
                  color: cs.onSurface,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ソーシャルロボット・ネットワークサービス',
                style: t.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<PackageInfo>(
                future: _info,
                builder: (BuildContext _, AsyncSnapshot<PackageInfo> snap) {
                  final String label = snap.hasData
                      ? 'v${snap.data!.version}+${snap.data!.buildNumber}'
                      : '';
                  return Text(
                    label,
                    style: t.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: .7),
                      fontFamily: 'JetBrains Mono',
                      letterSpacing: 2,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Programmatic brand mark — concentric ring, three radial spokes
/// with bullet caps (mesh nodes), and a centre diamond. Mirrors
/// the SVG brand icons in `meshmore-sns/brand/<theme>/icon.svg`
/// at a much smaller scale; uses the active theme's
/// `primary` + `tertiary` so it stays on-theme.
class _BrandMarkPainter extends CustomPainter {
  _BrandMarkPainter({
    required this.accent,
    required this.alt,
    required this.bg,
  });

  final Color accent;
  final Color alt;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = math.min(size.width, size.height) / 2;

    // Outer ring (subtle).
    canvas.drawCircle(
      c,
      r - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: .35),
    );
    // Inner ring (stronger).
    canvas.drawCircle(
      c,
      r - 14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: .55),
    );

    // Three radial spokes at 12, 8, 4 o'clock with bullet endcaps
    // — meant to read as "three peers on the mesh."
    final List<double> spokes = <double>[
      -math.pi / 2,
      -math.pi / 2 + 2 * math.pi / 3,
      -math.pi / 2 + 4 * math.pi / 3,
    ];
    final double spokeLen = r - 18;
    final Paint spoke = Paint()
      ..color = accent.withValues(alpha: .65)
      ..strokeWidth = 3;
    for (final double a in spokes) {
      final Offset endp =
          c + Offset(spokeLen * math.cos(a), spokeLen * math.sin(a));
      canvas.drawLine(c, endp, spoke);
      canvas.drawCircle(
        endp,
        5,
        Paint()..color = bg,
      );
      canvas.drawCircle(
        endp,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent,
      );
    }

    // Centre diamond + alt-colour dot at its centre.
    final double d = r * 0.30;
    final Path diamond = Path()
      ..moveTo(c.dx, c.dy - d)
      ..lineTo(c.dx + d, c.dy)
      ..lineTo(c.dx, c.dy + d)
      ..lineTo(c.dx - d, c.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = accent);
    canvas.drawCircle(c, d * 0.30, Paint()..color = alt);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter old) =>
      old.accent != accent || old.alt != alt || old.bg != bg;
}
