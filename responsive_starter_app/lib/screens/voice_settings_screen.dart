// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../ui/mm_scaffold.dart';
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

  /// Exposed for unit tests — direct entry into the cryptic-name
  /// parser so we can verify Android voice-ID prettification without
  /// spinning up the whole widget tree.
  @visibleForTesting
  static String prettyVoiceNameDebug(String raw, String locale) =>
      _VoiceSettingsScreenState._prettyVoiceName(raw, locale);
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

  /// R5+1 — by default the picker filters to voices whose locale
  /// language matches the phone's current language (e.g. phone =
  /// en-US → show only en-* voices). User can flip this off to see
  /// the full platform list when they explicitly want a non-native
  /// voice. Default on because the unfiltered platform list is
  /// hundreds of cryptic IDs on most Android devices.
  bool _onlyCurrentLanguage = true;

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

  /// First component of a BCP-47 locale tag, normalised to lower case.
  /// `"en-US"` → `"en"`. Robust to underscores (`en_US`) too.
  static String _langOf(String locale) {
    final String s = locale.replaceAll('_', '-');
    final int dash = s.indexOf('-');
    return (dash < 0 ? s : s.substring(0, dash)).toLowerCase();
  }

  /// Render a platform TTS voice name in something a human can read.
  ///
  /// iOS / macOS already give us friendly names ("Samantha", "Alex").
  /// Android's `getVoices()` returns IDs like
  /// `en-us-x-sfg#female_2-local` or `en-us-x-iol-network` — strip the
  /// locale prefix (we display it separately), the `-x-` engine
  /// marker, and the `-local` / `-network` tail (also surfaced
  /// separately via the OFFLINE badge), title-case what's left.
  /// Falls back to the raw name when nothing parses out — never
  /// returns an empty string.
  static String _prettyVoiceName(String raw, String locale) {
    if (!raw.contains('-') && !raw.contains('#')) return raw;
    String name = raw;
    final String localeLower = locale.toLowerCase().replaceAll('_', '-');
    if (name.toLowerCase().startsWith(localeLower)) {
      name = name.substring(localeLower.length);
      if (name.startsWith('-')) name = name.substring(1);
    }
    // Drop the engine-marker `-x-` if present.
    if (name.startsWith('x-')) name = name.substring(2);
    name = name
        .replaceAll('#', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'-(local|network)$'), '')
        .replaceAll('-', ' ')
        .trim();
    if (name.isEmpty) return raw;
    // Tokenise + label. The Android IDs are all-lowercase, so we
    // can't rely on existing casing to tell codenames from words.
    // Heuristic: short pure-letter tokens (≤4 chars, no digits) are
    // engine codenames ("sfg", "iol", "rjs") → uppercase. Longer
    // letter-tokens and any digit-bearing tokens are title-cased
    // so "female_2-local" becomes "Female 2".
    final List<String> tokens = name.split(RegExp(r'\s+'));
    return tokens.map((String t) {
      if (t.isEmpty) return t;
      final bool isShortLetters =
          t.length <= 4 && RegExp(r'^[a-zA-Z]+$').hasMatch(t);
      if (isShortLetters) return t.toUpperCase();
      return t[0].toUpperCase() + t.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final TtsController tc = context.watch<TtsController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<TtsVoice> allVoices = _voices ?? const <TtsVoice>[];
    final String phoneLang =
        _langOf(Localizations.localeOf(context).toLanguageTag());
    final List<TtsVoice> voices = _onlyCurrentLanguage
        ? <TtsVoice>[
            for (final TtsVoice v in allVoices)
              if (_langOf(v.locale) == phoneLang) v
          ]
        : allVoices;

    return Scaffold(
      appBar: AppBar(title: Text(l.voiceSettingsTitle)),
      body: MmScaffold(
        child: ListView(
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
                    fontFamily: 'JetBrains Mono')),
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
                    fontFamily: 'JetBrains Mono')),
          ),
          const Divider(),
          // Voice picker.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(l.voicePicker.toUpperCase(),
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          letterSpacing: 2)),
                ),
                if (allVoices.isNotEmpty)
                  Text(
                    _onlyCurrentLanguage
                        ? l.voicePickerFilteredCount(
                            voices.length, phoneLang.toUpperCase())
                        : l.voicePickerAllCount(allVoices.length),
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        fontFamily: 'JetBrains Mono'),
                  ),
              ],
            ),
          ),
          // R5+1 — language filter toggle. Default on; flipping off
          // surfaces every voice the platform reports (some Androids
          // have hundreds — useful only when the user wants a
          // deliberately non-native voice).
          SwitchListTile(
            dense: true,
            title: Text(l.voicePickerOnlyMyLanguage),
            subtitle: Text(
              l.voicePickerOnlyMyLanguageHint(phoneLang.toUpperCase()),
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 11),
            ),
            value: _onlyCurrentLanguage,
            onChanged: (bool v) =>
                setState(() => _onlyCurrentLanguage = v),
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
                    Expanded(
                      child: Text(_prettyVoiceName(v.name, v.locale)),
                    ),
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
            if (voices.isEmpty && allVoices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  l.voicePickerNoMatchForLanguage(
                      phoneLang.toUpperCase()),
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 12),
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
