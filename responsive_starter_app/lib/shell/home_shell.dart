// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_state_model.dart';
import '../cue/cue_bridge.dart';
import '../cue/cue_service.dart';
import '../gen/app_localizations.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import '../screens/chat_screen.dart';
import 'boot_overlay.dart';
import '../screens/dashboards/dashboard_host.dart';
import '../screens/docs_hub_screen.dart';
import '../screens/nodes_screen.dart';
import '../theme/theme_controller.dart';

/// The six primary views (R8 dashboard is the home / first page;
/// R53 adds the Docs tab, sitting after Settings).
enum MmView { dashboard, chat, nodes, settings, docs, about }

extension on MmView {
  /// Localised tab label. Pass `AppLocalizations.of(context)` from the
  /// caller; we don't reach for a context here so the call sites
  /// stay explicit about what they're translating.
  String title(AppLocalizations l) => switch (this) {
        MmView.dashboard => l.tabDashboard,
        MmView.chat => l.tabChat,
        MmView.nodes => l.tabNodes,
        MmView.docs => l.tabDocs,
        MmView.settings => l.tabSettings,
        MmView.about => l.tabAbout,
      };
  IconData get icon => switch (this) {
        MmView.dashboard => Icons.dashboard_outlined,
        MmView.chat => Icons.chat_bubble_outline,
        MmView.nodes => Icons.hub_outlined,
        MmView.docs => Icons.menu_book_outlined,
        MmView.settings => Icons.settings_outlined,
        MmView.about => Icons.info_outline,
      };
}

/// Primary navigation shell (R11): horizontal swipe between the five
/// views; the app-bar leading control opens a quick-nav sheet on
/// **tap or long-press** (long-press = the spec gesture; tap = the
/// accessible, non-gesture-only equivalent — R13). No hamburger
/// drawer by design.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with WidgetsBindingObserver {
  final PageController _pc = PageController();
  int _index = 0;
  CueBridge? _cueBridge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // U6: app-scoped event → cue dispatch (R12/R13). Reads providers
    // once at start; both are above us in the tree.
    _cueBridge = CueBridge(
      context.read<MeshcoreController>(),
      context.read<CueService>(),
    );
    // Owns splash teardown now (replaces the old demo home).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cueBridge?.dispose();
    _pc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // R17: on return to foreground, re-ensure the link + drain the
    // radio's queue (messages buffered while backgrounded).
    if (state == AppLifecycleState.resumed) {
      context.read<MeshcoreController>().onAppResumed();
    }
  }

  void _goTo(int i, {required bool reduceMotion}) {
    if (reduceMotion) {
      _pc.jumpToPage(i);
    } else {
      _pc.animateToPage(i,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    }
  }

  Future<void> _openQuickNav() async {
    final bool reduceMotion = context.read<ThemeController>().reduceMotion;
    final AppLocalizations l = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final MmView v in MmView.values)
                ListTile(
                  leading: Icon(v.icon),
                  title: Text(v.title(l)),
                  selected: v.index == _index,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _goTo(v.index, reduceMotion: reduceMotion);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final MmView current = MmView.values[_index];
    // Root back handling (R11): from a non-Dashboard tab, Back returns
    // to the Dashboard instead of trying to pop the root route (which
    // is what crashed on Android). On the Dashboard, Back is allowed
    // through so the OS gracefully backgrounds the app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _goTo(0,
              reduceMotion:
                  context.read<ThemeController>().reduceMotion);
        }
      },
      child: BootOverlay(child: Scaffold(
      appBar: AppBar(
        leading: Semantics(
          button: true,
          label: 'Quick navigation',
          child: InkWell(
            onTap: _openQuickNav,
            onLongPress: _openQuickNav,
            customBorder: const CircleBorder(),
            child: const Icon(Icons.menu_open),
          ),
        ),
        title: Text(current.title(l)),
        actions: const <Widget>[RadioLinkIndicator()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (final MmView v in MmView.values)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 3, vertical: 4),
                  child: GestureDetector(
                    onTap: () => _goTo(v.index,
                        reduceMotion:
                            context.read<ThemeController>().reduceMotion),
                    child: Container(
                      width: v.index == _index ? 18 : 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: v.index == _index
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: .3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: PageView(
        controller: _pc,
        onPageChanged: (int i) => setState(() => _index = i),
        children: const <Widget>[
          DashboardHost(),
          ChatScreen(),
          NodesScreen(),
          _SettingsView(),
          DocsHubScreen(),
          _AboutView(),
        ],
      ),
      ),
      ),
    );
  }
}


class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return ListView(
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.router_outlined),
          title: Text(l.settingsHubDevice),
          subtitle: Text(l.settingsHubDeviceSub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/device'),
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text(l.settingsHubApp),
          subtitle: Text(l.settingsHubAppSub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/app'),
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(l.settingsHubProfile),
          subtitle: Text(l.settingsHubProfileSub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/profile'),
        ),
        ListTile(
          leading: const Icon(Icons.tag),
          title: Text(l.settingsHubChannels),
          subtitle: Text(l.settingsHubChannelsSub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/channels'),
        ),
        ListTile(
          leading: const Icon(Icons.bluetooth_searching),
          title: Text(l.settingsHubDiagnostics),
          subtitle: Text(l.settingsHubDiagnosticsSub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/diagnostics'),
        ),
      ],
    );
  }
}

class _AboutView extends StatelessWidget {
  const _AboutView();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppState app = context.watch<AppState>();
    final AppLocalizations l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('MESHMORE SNS',
                style: TextStyle(
                    fontSize: 22, letterSpacing: 4, color: cs.onSurface)),
            const SizedBox(height: 4),
            // The EN + JP subtitles are intentionally rendered as a
            // *pair* regardless of the active locale — the brand name
            // is bilingual.
            Text(l.aboutSubtitleEn,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: .8))),
            const SizedBox(height: 2),
            Text(l.aboutSubtitleJa,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: .65))),
            const SizedBox(height: 14),
            Text(l.aboutVersion(app.getAppVersion()),
                style:
                    TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            const SizedBox(height: 16),
            Text(
              '${l.aboutDescription}\n'
              '${l.aboutCopyright}\n'
              '${l.aboutLicense}',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: .65)),
            ),
            const SizedBox(height: 18),
            Text(l.aboutMadeWith,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: .55),
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 14),
            Text(l.aboutTerms,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: .4),
                    fontSize: 11)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: l.appName,
                applicationVersion: l.aboutVersion(app.getAppVersion()),
                applicationLegalese: l.aboutCopyright,
              ),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(l.aboutLicensesButton),
            ),
            const SizedBox(height: 10),
            Text(l.aboutAttributions,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: .45),
                    fontSize: 10.5,
                    height: 1.4)),
          ],
        ),
      ),
    );
  }
}

/// Always-visible radio link state (every primary view). Tap → the
/// Diagnostics & connect screen.
class RadioLinkIndicator extends StatelessWidget {
  const RadioLinkIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;

    final ({String label, Color color, IconData icon}) v =
        switch (mc.state) {
      MeshcoreConnectionState.ready => (
          label: 'LINKED',
          color: cs.tertiary,
          icon: Icons.bluetooth_connected,
        ),
      MeshcoreConnectionState.handshaking => (
          label: 'SYNC',
          color: cs.secondary,
          icon: Icons.bluetooth_searching,
        ),
      MeshcoreConnectionState.reconnecting => (
          label: 'RETRY',
          color: cs.secondary,
          icon: Icons.bluetooth_searching,
        ),
      MeshcoreConnectionState.failed => (
          label: 'FAIL',
          color: cs.error,
          icon: Icons.bluetooth_disabled,
        ),
      MeshcoreConnectionState.disconnected => (
          label: mc.isConnecting ? 'SCAN' : 'OFFLINE',
          color: cs.onSurfaceVariant,
          icon: Icons.bluetooth_disabled,
        ),
    };

    return Semantics(
      button: true,
      label: 'Radio ${v.label}',
      child: InkWell(
        onTap: () => context.push('/settings/diagnostics'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration:
                    BoxDecoration(color: v.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Icon(v.icon, size: 16, color: v.color),
              const SizedBox(width: 4),
              Text(
                v.label,
                style: TextStyle(
                  color: v.color,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
