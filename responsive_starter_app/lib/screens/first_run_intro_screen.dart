import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    setState(() {
      _busy = false;
      _denialNote = r == PermissionResult.permanentlyDenied
          ? "Bluetooth was permanently denied — open OS settings to "
              "grant it. You can still use the app offline."
          : "Bluetooth wasn't granted — you can continue offline or "
              "open OS settings to change your mind.";
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
              Text('MESHMORE · WELCOME',
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      letterSpacing: 3)),
              const SizedBox(height: 16),
              Text(
                "Quick heads-up on what we'll ask for",
                style: th.textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              _PermBlock(
                icon: Icons.bluetooth_searching,
                title: 'Bluetooth',
                body: 'To pair with your MeshCore radio and exchange '
                    'messages over the local mesh. Required to send / '
                    'receive over the air.',
              ),
              const SizedBox(height: 14),
              _PermBlock(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                body: 'Asked only if you turn on '
                    '"Stay connected in background" later in App settings. '
                    "Skipped today so you're not interrupted twice.",
              ),
              const SizedBox(height: 14),
              _PermBlock(
                icon: Icons.cloud_off,
                title: 'Offline is fine',
                body: "If you skip Bluetooth, the app still works — "
                    'browse message history, configure channels, read '
                    'diagnostics. Just no live mesh traffic until you '
                    'grant Bluetooth.',
              ),
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
                    label: const Text('Open OS settings'),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _grantAndContinue,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Grant Bluetooth & continue'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _continueOffline,
                  icon: const Icon(Icons.cloud_off),
                  label: const Text('Continue offline (skip permissions)'),
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
