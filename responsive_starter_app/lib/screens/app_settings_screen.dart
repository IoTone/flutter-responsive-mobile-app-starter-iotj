import 'package:flutter/material.dart';

/// General app settings (R3/R4/R5). Connection, language, TTS,
/// notifications, diagnostics, About/Terms. Wired in U5; U1 ships the
/// routed, themed scaffold.
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: ListView(
        children: <Widget>[
          for (final ({String h, String s}) row in const <({String h, String s})>[
            (h: 'CONNECTION', s: 'Auto-reconnect (M7 backoff) · forget device'),
            (h: 'LANGUAGE (R4)', s: 'System · English · 日本語'),
            (h: 'SPEECH (R5)', s: 'TTS off by default · voice · rate'),
            (h: 'NOTIFICATIONS', s: 'Critical → system notification + vibrate'),
            (h: 'DATA / ABOUT', s: 'Export diagnostics · logs · About · Terms'),
          ])
            ListTile(
              title: Text(row.h),
              subtitle: Text(row.s,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Wired (BLE/L10n/TTS/notifications) in U5.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .5)),
            ),
          ),
        ],
      ),
    );
  }
}
