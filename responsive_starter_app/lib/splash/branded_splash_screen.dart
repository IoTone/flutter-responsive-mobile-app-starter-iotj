// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
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
              RotationTransition(
                turns: _spin,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/icon-192.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
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
                      fontFamily: 'monospace',
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
