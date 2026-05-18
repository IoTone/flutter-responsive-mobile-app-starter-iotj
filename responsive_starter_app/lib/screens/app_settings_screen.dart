import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tts/tts_controller.dart';

/// General app settings (R3/R4/R5). Connection, language, TTS,
/// notifications, diagnostics, About/Terms. The **global TTS switch**
/// (R5 parent control) is functional from U3; the remaining rows are
/// routed scaffolds wired in U5.
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TtsController tts = context.watch<TtsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: const Text('CONNECTION'),
            subtitle: Text('Auto-reconnect (M7 backoff) · forget device',
                style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('LANGUAGE (R4)'),
            subtitle: Text('System · English · 日本語',
                style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          // SPEECH (R5) — functional from U3. Off by default; the
          // per-channel toggle in the Chat header is gated on this.
          SwitchListTile(
            title: const Text('SPEECH (R5)'),
            subtitle: Text(
              tts.enabled
                  ? 'Text-to-speech ON · per-channel toggle in Chat'
                  : 'Text-to-speech OFF (default) · reads channel messages',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            secondary: Icon(
                tts.enabled ? Icons.record_voice_over : Icons.voice_over_off),
            value: tts.enabled,
            onChanged: (bool v) => tts.setEnabled(v),
          ),
          ListTile(
            title: const Text('NOTIFICATIONS'),
            subtitle: Text('Critical → system notification + vibrate',
                style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('DATA / ABOUT'),
            subtitle: Text('Export diagnostics · logs · About · Terms',
                style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Voice/rate picker, BLE, L10n and notifications wired in U5.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .5)),
            ),
          ),
        ],
      ),
    );
  }
}
