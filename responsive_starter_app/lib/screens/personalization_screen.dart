// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
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
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.personalizationHeading)),
      body: ListView(
          children: <Widget>[
            _Section(l.personalizationThemePreset),
            // When High contrast is ON, the rendered theme is forced
            // to SEELE regardless of which preset is selected. Hint
            // the user so a tap that "does nothing" makes sense.
            if (tc.highContrast)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.personalizationHighContrastHint,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface,
                              fontSize: 12,
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Plain ListTile + onTap (rather than RadioGroup +
            // RadioListTile) — the latter wasn't reliably firing
            // `setPreset` in 3.35, so the chosen theme was a no-op.
            // We render the radio glyph by hand so the row visually
            // matches a RadioListTile.
            for (final MmThemePreset p in MmThemePreset.values)
              Opacity(
                opacity: tc.highContrast ? 0.55 : 1.0,
                child: ListTile(
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
              ),
            const Divider(),
          _Section(l.personalizationType),
          ListTile(
            dense: true,
            title: Text(l.personalizationFontSize),
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
          _Section(l.personalizationAccessibility),
          SwitchListTile(
            dense: true,
            title: Text(l.personalizationHighContrast),
            subtitle: Text(l.personalizationHighContrastSubtitle),
            value: tc.highContrast,
            onChanged: tc.setHighContrast,
          ),
          SwitchListTile(
            dense: true,
            title: Text(l.personalizationReduceMotion),
            value: tc.reduceMotion,
            onChanged: tc.setReduceMotion,
          ),
          SwitchListTile(
            dense: true,
            title: Text(l.personalizationVisualHapticOnly),
            subtitle: Text(l.personalizationVisualHapticOnlySubtitle),
            value: tc.visualHapticOnly,
            onChanged: tc.setVisualHapticOnly,
          ),
          const Divider(),
          _Section(l.personalizationAudioAlerts),
          SwitchListTile(
            dense: true,
            title: Text(l.personalizationAudioMaster),
            subtitle: Text(tc.visualHapticOnly
                ? l.personalizationAudioMasterDisabled
                : l.personalizationAudioMasterEnabled),
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
