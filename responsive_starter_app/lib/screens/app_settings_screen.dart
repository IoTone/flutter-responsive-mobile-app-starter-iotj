// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../meshcore/meshcore_controller.dart';
import '../perms/first_run_controller.dart';
import '../perms/permissions_service.dart';
import '../tts/tts_controller.dart';

/// General app settings (R3/R4/R5/R21). Connection, language, TTS,
/// notifications, diagnostics, About/Terms. The **global TTS switch**
/// (R5 parent control) is functional from U3; the remaining rows are
/// routed scaffolds wired in U5.
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  /// R21 / U12 — first-time toggle-on of the background keepalive
  /// triggers the **notifications** permission ask. If the user
  /// declines we revert the switch and surface a snack with
  /// "Open settings". If they grant it, we proceed to start the
  /// foreground service via the existing setter.
  Future<void> _onBgToggle(
      BuildContext ctx, MeshcoreController mc, bool v) async {
    if (!v) {
      await mc.setBackgroundKeepaliveEnabled(false);
      return;
    }
    final PermissionsService perms = ctx.read<PermissionsService>();
    final bool already = await perms.notificationsGranted();
    PermissionResult r = PermissionResult.granted;
    if (!already) {
      r = await perms.requestNotifications();
    }
    if (!ctx.mounted) return;
    if (r == PermissionResult.granted ||
        r == PermissionResult.notApplicable) {
      await mc.setBackgroundKeepaliveEnabled(true);
      return;
    }
    // Denied — keep the toggle off and explain.
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      SnackBar(
        content: Text(r == PermissionResult.permanentlyDenied
            ? 'Notifications were permanently denied. '
                'The background service needs a persistent notification.'
            : 'Notifications are required for the background service. '
                'Tap Open settings to grant them.'),
        action: SnackBarAction(
          label: 'Open settings',
          onPressed: () =>
              ctx.read<PermissionsService>().openAppSettingsPage(),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TtsController tts = context.watch<TtsController>();
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final FirstRunController fr = context.watch<FirstRunController>();
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
          // R17/U8 — Android background keep-alive (foreground service
          // + persistent notification). No-op on iOS.
          SwitchListTile(
            title: const Text('Stay connected in background'),
            subtitle: Text(
              mc.backgroundKeepaliveEnabled
                  ? 'Android: a persistent notification keeps the radio '
                      'linked so messages arrive while backgrounded'
                  : 'Messages still arrive when you reopen the app '
                      '(radio buffers them); no background notification',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            secondary: Icon(mc.backgroundKeepaliveEnabled
                ? Icons.cloud_sync
                : Icons.cloud_off),
            value: mc.backgroundKeepaliveEnabled,
            onChanged: (bool v) => _onBgToggle(context, mc, v),
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
          // R21 / U12 — Permissions row: jumps to the OS app-settings
          // page where the user can flip BLE / Notifications etc.
          // back on after a permanent denial.
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Permissions'),
            subtitle: Text(
              'Open the OS settings page for this app — '
              'flip Bluetooth / Notifications on or off here.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () =>
                context.read<PermissionsService>().openAppSettingsPage(),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Show intro again on next launch'),
            subtitle: Text(
              fr.done
                  ? 'Wipes the first-run flag so the permissions intro '
                      "shows again — useful when you're testing the flow"
                  : 'Intro is currently scheduled for next launch',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            enabled: fr.done,
            onTap: () => fr.reset(),
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
