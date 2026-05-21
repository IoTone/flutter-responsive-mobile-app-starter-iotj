// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../perms/first_run_controller.dart';
import '../perms/permissions_service.dart';

/// R21 / U12 — first-run permissions intro. Explains *why* the app
/// asks for Bluetooth and notifications, sets the offline-first
/// expectation, and gives the user two clearly-labelled paths:
///
/// 1. **Grant Bluetooth & continue** — the recommended path. Proactively
///    requests the BLE permission set. We deliberately **do not** ask
///    for notifications here; that prompt only fires the first time the
///    user enables "Stay connected in background" (R17 toggle).
/// 2. **Continue offline (skip permissions)** — fully supported. The
///    app still browses message history, themes, channel settings, and
///    diagnostics. Any action that actually needs the radio (Scan,
///    Connect, Send) will surface a per-action prompt later.
///
/// Either path marks first-run as done; the intro never reappears.
class FirstRunIntroScreen extends StatefulWidget {
  const FirstRunIntroScreen({super.key});

  @override
  State<FirstRunIntroScreen> createState() => _FirstRunIntroScreenState();
}

class _FirstRunIntroScreenState extends State<FirstRunIntroScreen> {
  bool _busy = false;
  String? _denialNote;

  Future<void> _grantAndContinue() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _denialNote = null;
    });
    final PermissionsService perms = context.read<PermissionsService>();
    final FirstRunController fr = context.read<FirstRunController>();
    final PermissionResult r = await perms.requestBle();
    if (!mounted) return;
    if (r == PermissionResult.granted ||
        r == PermissionResult.notApplicable) {
      await fr.markDone();
      return;
    }
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() {
      _busy = false;
      _denialNote = r == PermissionResult.permanentlyDenied
          ? l.firstRunDeniedPermanent
          : l.firstRunDeniedTransient;
    });
  }

  Future<void> _continueOffline() async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<FirstRunController>().markDone();
  }

  Future<void> _openSettings() async {
    await context.read<PermissionsService>().openAppSettingsPage();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData th = Theme.of(context);
    final ColorScheme cs = th.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Builder(builder: (BuildContext ctx) {
                final AppLocalizations l = AppLocalizations.of(ctx);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.firstRunHeader,
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            letterSpacing: 3)),
                    const SizedBox(height: 16),
                    Text(
                      l.firstRunTitle,
                      style: th.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 18),
                    _PermBlock(
                      icon: Icons.bluetooth_searching,
                      title: l.firstRunBleTitle,
                      body: l.firstRunBleBody,
                    ),
                    const SizedBox(height: 14),
                    _PermBlock(
                      icon: Icons.notifications_active_outlined,
                      title: l.firstRunNotificationsTitle,
                      body: l.firstRunNotificationsBody,
                    ),
                    const SizedBox(height: 14),
                    _PermBlock(
                      icon: Icons.cloud_off,
                      title: l.firstRunOfflineTitle,
                      body: l.firstRunOfflineBody,
                    ),
                  ],
                );
              }),
              const Spacer(),
              if (_denialNote != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.info_outline,
                          color: cs.onErrorContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _denialNote!,
                          style: TextStyle(color: cs.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(AppLocalizations.of(context).firstRunOpenSettings),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _grantAndContinue,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(AppLocalizations.of(context).firstRunGrant),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _continueOffline,
                  icon: const Icon(Icons.cloud_off),
                  label: Text(AppLocalizations.of(context).firstRunSkip),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermBlock extends StatelessWidget {
  const _PermBlock({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(body,
                  style: TextStyle(
                      color: cs.onSurfaceVariant, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
