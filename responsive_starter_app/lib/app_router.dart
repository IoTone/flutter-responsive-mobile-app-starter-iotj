import 'package:go_router/go_router.dart';

import 'screens/app_settings_screen.dart';
import 'screens/channels_screen.dart';
import 'screens/device_config_screen.dart';
import 'screens/dm_screen.dart';
import 'screens/grid_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/personalization_screen.dart';
import 'shell/home_shell.dart';

/// App routes (R11). `/` hosts the 5-view swipe shell; the Settings
/// hub pushes its three sub-screens.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, __) => const HomeShell()),
    GoRoute(
      path: '/settings/device',
      builder: (_, __) => const DeviceConfigScreen(),
    ),
    GoRoute(
      path: '/settings/app',
      builder: (_, __) => const AppSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/profile',
      builder: (_, __) => const PersonalizationScreen(),
    ),
    GoRoute(
      path: '/settings/channels',
      builder: (_, __) => const ChannelsScreen(),
    ),
    GoRoute(path: '/grid', builder: (_, __) => const GridScreen()),
    GoRoute(
      path: '/dm/:pubkey',
      builder: (_, GoRouterState state) => DmScreen(
        peerPubKeyHex: state.pathParameters['pubkey']!,
      ),
    ),
    GoRoute(
      path: '/settings/diagnostics',
      builder: (_, __) => const DiagnosticsScreen(),
    ),
  ],
);
