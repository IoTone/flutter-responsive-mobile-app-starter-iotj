// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../meshcore/meshcore_controller.dart';
import '../perms/first_run_controller.dart';
import '../perms/permissions_service.dart';
import '../ui/mm_scaffold.dart';
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

  String _languageLabel(AppLocalizations l, Locale? loc) {
    if (loc == null) return l.settingsLanguageSystem;
    return switch (loc.languageCode) {
      'en' => l.settingsLanguageEnglish,
      'ja' => l.settingsLanguageJapanese,
      _ => loc.languageCode,
    };
  }

  Future<void> _pickLanguage(
      BuildContext ctx, LocaleController lc) async {
    final AppLocalizations l = AppLocalizations.of(ctx);
    final Locale? picked = await showModalBottomSheet<Locale?>(
      context: ctx,
      showDragHandle: true,
      builder: (BuildContext _) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(l.settingsLanguageSystem),
              trailing: lc.locale == null
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, null),
            ),
            ListTile(
              title: Text(l.settingsLanguageEnglish),
              trailing: lc.locale?.languageCode == 'en'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, const Locale('en')),
            ),
            ListTile(
              title: Text(l.settingsLanguageJapanese),
              trailing: lc.locale?.languageCode == 'ja'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, const Locale('ja')),
            ),
          ],
        ),
      ),
    );
    // `null` picked means "system default"; `picked == null && popped
    // by drag` means no change. Disambiguate by looking at whether the
    // sheet actually returned a value vs being dismissed. showModal*
    // returns null on dismiss, so we can't tell them apart here —
    // treat any returned-null as "system default" via an explicit tap
    // (drag-dismissed without tapping won't have a "System" trailing
    // check to confirm). Edge: dismissing the sheet now also resets
    // to system. Acceptable in v1.
    await lc.set(picked);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TtsController tts = context.watch<TtsController>();
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final FirstRunController fr = context.watch<FirstRunController>();
    final LocaleController lc = context.watch<LocaleController>();
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsHeading)),
      body: MmScaffold(
        child: ListView(
        children: <Widget>[
          ListTile(
            title: Text(l.settingsConnection),
            subtitle: Text(l.settingsConnectionSubtitle,
                style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          // R17/U8 — Android background keep-alive (foreground service
          // + persistent notification). No-op on iOS.
          SwitchListTile(
            title: Text(l.settingsBackgroundTitle),
            subtitle: Text(
              mc.backgroundKeepaliveEnabled
                  ? l.settingsBackgroundOn
                  : l.settingsBackgroundOff,
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            secondary: Icon(mc.backgroundKeepaliveEnabled
                ? Icons.cloud_sync
                : Icons.cloud_off),
            value: mc.backgroundKeepaliveEnabled,
            onChanged: (bool v) => _onBgToggle(context, mc, v),
          ),
          // Background peer-telemetry polling — politely cycles
          // contacts so temperature / altitude populate across the
          // fabric. Costs a little OTA airtime; off = no telemetry
          // traffic from us.
          SwitchListTile(
            title: Text(l.settingsTelemetryPoll),
            subtitle: Text(
              mc.telemetryPollEnabled
                  ? l.settingsTelemetryPollOn
                  : l.settingsTelemetryPollOff,
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            secondary: Icon(mc.telemetryPollEnabled
                ? Icons.thermostat
                : Icons.thermostat_auto),
            value: mc.telemetryPollEnabled,
            onChanged: (bool v) => mc.setTelemetryPollEnabled(v),
          ),
          // R4 — language picker. Tap-to-open bottom sheet with
          // System / English / 日本語; the choice is persisted by
          // LocaleController and re-skins the whole tree live.
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.settingsLanguage),
            subtitle: Text(_languageLabel(l, lc.locale),
                style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLanguage(context, lc),
          ),
          // SPEECH (R5) — functional from U3. Off by default; the
          // per-channel toggle in the Chat header is gated on this.
          SwitchListTile(
            title: Text(l.settingsSpeech),
            subtitle: Text(
              tts.enabled ? l.settingsSpeechOn : l.settingsSpeechOff,
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            secondary: Icon(
                tts.enabled ? Icons.record_voice_over : Icons.voice_over_off),
            value: tts.enabled,
            onChanged: (bool v) => tts.setEnabled(v),
          ),
          // R5 / U5 — Voice quality picker (rate / pitch / voice +
          // preview). Always reachable, even when SPEECH is off —
          // the preview button greys-out instead, with a hint.
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l.voiceSettingsTitle),
            subtitle: Text(
              '${l.voiceRate} · ${tts.rate.toStringAsFixed(2)}  ·  '
              '${l.voicePitch} · ${tts.pitch.toStringAsFixed(2)}'
              '${tts.voice == null ? '' : '  ·  ${tts.voice!.name}'}',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/voice'),
          ),
          // R36 — Auto-publish location. Lives here so users find
          // it under "App settings" rather than buried in Device
          // config; the device-side advert policy is separate.
          ListTile(
            leading: const Icon(Icons.satellite_alt),
            title: Text(l.locTitle),
            subtitle: Text(l.locTileSubtitle,
                style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/location'),
          ),
          ListTile(
            title: Text(l.settingsNotifications),
            subtitle: Text(l.settingsNotificationsSubtitle,
                style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          // R21 / U12 — Permissions row: jumps to the OS app-settings
          // page where the user can flip BLE / Notifications etc.
          // back on after a permanent denial.
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l.settingsPermissions),
            subtitle: Text(
              l.settingsPermissionsSubtitle,
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () =>
                context.read<PermissionsService>().openAppSettingsPage(),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(l.settingsShowIntro),
            subtitle: Text(
              fr.done
                  ? l.settingsShowIntroEnabled
                  : l.settingsShowIntroDisabled,
              style: TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            enabled: fr.done,
            onTap: () => fr.reset(),
          ),
          ListTile(
            title: Text(l.settingsData),
            subtitle: Text(l.settingsDataSubtitle,
                style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
      ),
    );
  }
}
