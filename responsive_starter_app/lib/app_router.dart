// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:go_router/go_router.dart';

import 'screens/about_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'shell/home_shell.dart';

/// App routes. `/` hosts the swipe shell; sub-pages are pushed on top.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, __) => const HomeShell()),
    GoRoute(
      path: '/diagnostics',
      builder: (_, __) => const DiagnosticsScreen(),
    ),
    GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
  ],
);
