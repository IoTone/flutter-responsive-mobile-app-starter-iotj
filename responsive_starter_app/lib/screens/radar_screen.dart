// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../scanner/scanner_controller.dart';

/// Radar scope — a signal-strength radial view of nearby devices.
/// The polished radial painter is ported in the next phase; this is
/// the wired-up shell that the painter drops into.
class RadarScreen extends StatelessWidget {
  const RadarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScannerController sc = context.watch<ScannerController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    if (sc.bleCount == 0 && sc.wifiCount == 0) {
      return Center(
        child: Text(l.radarEmpty,
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return Center(
      child: Text('${sc.bleCount + sc.wifiCount}',
          style: TextStyle(
              color: cs.primary, fontSize: 48, fontWeight: FontWeight.w300)),
    );
  }
}
