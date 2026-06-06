// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../theme/theme_controller.dart';

/// Quick mute/unmute for alert sounds, surfaced on the dashboard (R12
/// follow-on). Audible cues are ON by default; this is the one-tap way
/// to silence them without digging into Settings. Bound to
/// `ThemeController.audioMaster`; reflects *actual* audibility (the
/// "visual + haptic only" accessibility switch also silences audio, so
/// the icon honours it and re-enabling clears it).
class MmAudioToggle extends StatelessWidget {
  const MmAudioToggle({super.key, this.size = 20, this.dense = false, this.color});

  final double size;

  /// Compact form (zero padding, 28×28 hit box) for dense headers like
  /// the NERV LINK panel; matches the sibling device button there.
  final bool dense;

  /// Overrides the "audible" tint (defaults to the colour scheme primary);
  /// the muted state always uses `onSurfaceVariant`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeController theme;
    try {
      theme = context.watch<ThemeController>();
    } on ProviderNotFoundException {
      // No ThemeController above us (isolated widget test) — nothing to
      // toggle, so render nothing rather than crash. Matches MmScaffold.
      return const SizedBox.shrink();
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool audible = theme.audioMaster && !theme.visualHapticOnly;
    return IconButton(
      tooltip: audible ? l.dashboardAudioMute : l.dashboardAudioUnmute,
      visualDensity: dense ? VisualDensity.compact : null,
      padding: dense ? EdgeInsets.zero : null,
      constraints: dense
          ? const BoxConstraints(minWidth: 28, minHeight: 28)
          : null,
      icon: Icon(
        audible ? Icons.volume_up : Icons.volume_off,
        size: size,
        color: audible ? (color ?? cs.primary) : cs.onSurfaceVariant,
      ),
      onPressed: () {
        if (audible) {
          theme.setAudioMaster(false);
        } else {
          // Unmuting also lifts "visual + haptic only" — otherwise that
          // switch would keep audio silent and the toggle would no-op.
          if (theme.visualHapticOnly) theme.setVisualHapticOnly(false);
          theme.setAudioMaster(true);
        }
      },
    );
  }
}
