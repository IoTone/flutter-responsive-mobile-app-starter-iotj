// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/mm_tokens.dart';
import '../theme/theme_controller.dart';

/// Profile & personalization (R14): live preset / font / accessibility
/// picker. The chosen design concept is the default theme; all six
/// ship here as selectable presets (D = default, also high-contrast).
class PersonalizationScreen extends StatelessWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = context.watch<ThemeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & personalization')),
      body: ListView(
          children: <Widget>[
            const _Section('THEME PRESET'),
            // Plain ListTile + onTap (rather than RadioGroup +
            // RadioListTile) — the latter wasn't reliably firing
            // `setPreset` in 3.35, so the chosen theme was a no-op.
            // We render the radio glyph by hand so the row visually
            // matches a RadioListTile.
            for (final MmThemePreset p in MmThemePreset.values)
              ListTile(
                dense: true,
                onTap: () => tc.setPreset(p),
                leading: Icon(
                  tc.preset == p
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: tc.preset == p
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(p.label),
                trailing: _Swatches(kMmPresets[p]!),
              ),
            const Divider(),
          const _Section('TYPE'),
          ListTile(
            dense: true,
            title: const Text('Font size'),
            subtitle: Slider(
              min: 0.8,
              max: 1.6,
              divisions: 8,
              value: tc.fontScale,
              label: '${(tc.fontScale * 100).round()}%',
              onChanged: tc.setFontScale,
            ),
          ),
          const Divider(),
          const _Section('ACCESSIBILITY (R13)'),
          SwitchListTile(
            dense: true,
            title: const Text('High contrast'),
            subtitle: const Text('Force the SEELE high-contrast palette'),
            value: tc.highContrast,
            onChanged: tc.setHighContrast,
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Reduce motion'),
            value: tc.reduceMotion,
            onChanged: tc.setReduceMotion,
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Visual + haptic only'),
            subtitle: const Text('No information by sound; turns audio off'),
            value: tc.visualHapticOnly,
            onChanged: tc.setVisualHapticOnly,
          ),
          const Divider(),
          const _Section('AUDIO ALERTS (R12)'),
          SwitchListTile(
            dense: true,
            title: const Text('Audio alerts'),
            subtitle: Text(tc.visualHapticOnly
                ? 'Disabled by "visual + haptic only"'
                : 'Off by default; augmentation only'),
            value: tc.audioMaster,
            onChanged: tc.visualHapticOnly ? null : tc.setAudioMaster,
          ),
          ],
        ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

class _Swatches extends StatelessWidget {
  const _Swatches(this.t);
  final MmTokens t;
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[dot(t.base), dot(t.accent), dot(t.alert)],
    );
  }
}
