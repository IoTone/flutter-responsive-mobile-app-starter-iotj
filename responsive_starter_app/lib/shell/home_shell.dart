import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_state_model.dart';
import '../screens/nodes_screen.dart';
import '../theme/theme_controller.dart';

/// The five primary views (R8 dashboard is the home / first page).
enum MmView { dashboard, chat, nodes, settings, about }

extension on MmView {
  String get title => switch (this) {
        MmView.dashboard => 'Dashboard',
        MmView.chat => 'Chat',
        MmView.nodes => 'Nodes',
        MmView.settings => 'Settings',
        MmView.about => 'About',
      };
  IconData get icon => switch (this) {
        MmView.dashboard => Icons.dashboard_outlined,
        MmView.chat => Icons.chat_bubble_outline,
        MmView.nodes => Icons.hub_outlined,
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

class _HomeShellState extends State<HomeShell> {
  final PageController _pc = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Owns splash teardown now (replaces the old demo home).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
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
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final MmView v in MmView.values)
              ListTile(
                leading: Icon(v.icon),
                title: Text(v.title),
                selected: v.index == _index,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _goTo(v.index, reduceMotion: reduceMotion);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final MmView current = MmView.values[_index];
    return Scaffold(
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
        title: Text(current.title),
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
          _Placeholder(MmView.dashboard, 'Network status, link, peers, '
              'events + collapsible chat — wired in U2.'),
          _Placeholder(MmView.chat, 'Active-channel chat + channel switch '
              'and TTS toggle — wired in U3.'),
          NodesScreen(),
          _SettingsView(),
          _AboutView(),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.view, this.note);
  final MmView view;
  final String note;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(view.icon, size: 48, color: cs.primary),
            const SizedBox(height: 12),
            Text(view.title.toUpperCase(),
                style: TextStyle(
                    fontSize: 22, letterSpacing: 4, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(note,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: cs.onSurface.withValues(alpha: .55))),
          ],
        ),
      ),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.router_outlined),
          title: const Text('Device configuration'),
          subtitle: const Text('Meshcore radio & device (R7)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/device'),
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('App settings'),
          subtitle: const Text('Connection, language, speech, data'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/app'),
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Profile & personalization'),
          subtitle: const Text('Theme, font size, audio, accessibility'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/profile'),
        ),
        ListTile(
          leading: const Icon(Icons.bluetooth_searching),
          title: const Text('Diagnostics & connect'),
          subtitle: const Text('Connect a radio · frame log · M6 capture'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('MESHMORE SNS',
                style: TextStyle(
                    fontSize: 22, letterSpacing: 4, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('v${app.getAppVersion()}',
                style:
                    TextStyle(color: cs.onSurface.withValues(alpha: .6))),
            const SizedBox(height: 16),
            Text(
              'A Meshcore companion client.\nCopyright IoTone Japan 2026.\n'
              'Terms & Conditions — wired in U5.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: .55)),
            ),
          ],
        ),
      ),
    );
  }
}
