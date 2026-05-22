// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../tts/tts_controller.dart';

/// R5 / U5 — TTS **quality** picker. Sits below the global SPEECH
/// switch in App settings. Three knobs, all persisted by the
/// [TtsController]:
///
///   - **Rate**  — slider over `TtsController.minRate..maxRate`.
///   - **Pitch** — slider over `TtsController.minPitch..maxPitch`.
///   - **Voice** — picker populated from
///     `flutter_tts.getVoices()` via `tc.listVoices()`.
///
/// A "Try a phrase" button speaks `voicePreviewPhrase` so the user
/// can audition changes without waiting for an inbound channel
/// message to fire.
class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  List<TtsVoice>? _voices;
  bool _loadingVoices = true;

  /// Cache of `flutter_tts.isLanguageAvailable(locale)` answers,
  /// resolved per unique locale (not per voice — many voices share
  /// the same locale). Lets us flag each voice row with an
  /// **OFFLINE** badge once the local language pack lookup has
  /// answered.
  final Map<String, bool> _offline = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _reloadVoices();
  }

  Future<void> _reloadVoices() async {
    final TtsController tc = context.read<TtsController>();
    final List<TtsVoice> v = await tc.listVoices();
    if (!mounted) return;
    setState(() {
      _voices = v;
      _loadingVoices = false;
    });
    // Resolve offline-availability per unique locale in the
    // background. setState as each completes so badges fade in
    // without blocking the initial render.
    final Set<String> locales = <String>{for (final TtsVoice voice in v) voice.locale};
    for (final String locale in locales) {
      final bool available = await tc.isLanguageAvailable(locale);
      if (!mounted) return;
      setState(() => _offline[locale] = available);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TtsController tc = context.watch<TtsController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<TtsVoice> voices = _voices ?? const <TtsVoice>[];

    return Scaffold(
      appBar: AppBar(title: Text(l.voiceSettingsTitle)),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              l.voiceSettingsHint,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          // Rate.
          ListTile(
            title: Text(l.voiceRate),
            subtitle: Slider(
              min: TtsController.minRate,
              max: TtsController.maxRate,
              value: tc.rate,
              label: tc.rate.toStringAsFixed(2),
              onChanged: tc.setRate,
            ),
            trailing: Text(tc.rate.toStringAsFixed(2),
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace')),
          ),
          // Pitch.
          ListTile(
            title: Text(l.voicePitch),
            subtitle: Slider(
              min: TtsController.minPitch,
              max: TtsController.maxPitch,
              value: tc.pitch,
              label: tc.pitch.toStringAsFixed(2),
              onChanged: tc.setPitch,
            ),
            trailing: Text(tc.pitch.toStringAsFixed(2),
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace')),
          ),
          const Divider(),
          // Voice picker.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l.voicePicker.toUpperCase(),
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                    letterSpacing: 2)),
          ),
          if (_loadingVoices)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (voices.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                l.voicePickerEmpty,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 12),
              ),
            )
          else ...<Widget>[
            ListTile(
              dense: true,
              onTap: () => tc.setVoice(null),
              leading: Icon(
                tc.voice == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: tc.voice == null
                    ? cs.primary
                    : cs.onSurfaceVariant,
              ),
              title: Text(l.voicePickerSystem),
            ),
            for (final TtsVoice v in voices)
              ListTile(
                dense: true,
                onTap: () => tc.setVoice(v),
                leading: Icon(
                  tc.voice?.id == v.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: tc.voice?.id == v.id
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
                title: Row(
                  children: <Widget>[
                    Expanded(child: Text(v.name)),
                    if (_offline[v.locale] == true)
                      _OfflineBadge(
                        label: l.voiceOfflineBadge,
                        color: cs.tertiary,
                      ),
                  ],
                ),
                subtitle: Text(
                  v.qualityHint == null
                      ? v.locale
                      : '${v.locale} · ${v.qualityHint}',
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 11),
                ),
              ),
          ],
          const Divider(),
          // Preview.
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: tc.enabled
                    ? () => tc.previewPhrase(l.voicePreviewPhrase)
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(l.voicePreview),
              ),
            ),
          ),
          if (!tc.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                l.voicePreviewDisabledHint,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small "OFFLINE" pill rendered next to a voice's name when the
/// platform reports its language pack is installed locally. Honest
/// signal for users who care about offline operation (privacy /
/// battery / field use without coverage).
class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
