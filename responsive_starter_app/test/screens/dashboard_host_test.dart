// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshmore_sns_app/gen/app_localizations.dart';
import 'package:meshmore_sns_app/l10n/locale_controller.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/dashboards/dashboard_host.dart';
import 'package:meshmore_sns_app/theme/mm_tokens.dart';
import 'package:meshmore_sns_app/theme/theme_controller.dart';

import '../meshcore/fake_transport.dart';

Future<ThemeController> _pump(WidgetTester t, MeshcoreController mc) async {
  final ThemeController tc = ThemeController();
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: tc),
        ChangeNotifierProvider<MeshcoreController>.value(value: mc),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: LocaleController.supported,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: DashboardHost()),
      ),
    ),
  );
  return tc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('host shows the SEELE monolith by default, NERV when selected',
      (WidgetTester t) async {
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => FakeMeshcoreTransport(connected: true),
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final ThemeController tc = await _pump(t, mc);

    // Default preset (SEELE) → the monolith dashboard (no NERV brand bar).
    expect(find.text('PEERS IN RANGE'), findsOneWidget);
    expect(find.text('MESHMORE // NERV'), findsNothing);

    // Switch to NERV → the telemetry-grid re-imagining (brand bar +
    // chamfered panels appear).
    await tc.setPreset(MmThemePreset.nerv);
    await t.pumpAndSettle();
    expect(find.text('MESHMORE // NERV'), findsOneWidget);

    // Back to SEELE → brand bar gone again.
    await tc.setPreset(MmThemePreset.seele);
    await t.pumpAndSettle();
    expect(find.text('MESHMORE // NERV'), findsNothing);
    expect(find.text('PEERS IN RANGE'), findsOneWidget);
  });

  testWidgets('host shows the Hyperlocal radar when selected',
      (WidgetTester t) async {
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => FakeMeshcoreTransport(connected: true),
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final ThemeController tc = await _pump(t, mc);
    // Reduce-motion stops the radar sweep so the tree can settle (the
    // sweep is an infinite animation otherwise).
    await tc.setReduceMotion(true);
    await tc.setPreset(MmThemePreset.hyperlocal);
    await t.pumpAndSettle();

    // Radar dashboard: the empty-field prompt + the PEERS status rail,
    // and none of the other skins' signatures.
    expect(find.text('Listening for nodes…'), findsOneWidget);
    expect(find.textContaining('PEERS', findRichText: true),
        findsOneWidget); // status rail
    expect(find.text('MESHMORE // NERV'), findsNothing);
    expect(find.text('PEERS IN RANGE'), findsNothing);
  });

  testWidgets('host shows the AG-HUD gauges when selected',
      (WidgetTester t) async {
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => FakeMeshcoreTransport(connected: true),
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final ThemeController tc = await _pump(t, mc);
    // Reduce-motion stops the gauge sweep so the tree can settle.
    await tc.setReduceMotion(true);
    await tc.setPreset(MmThemePreset.agHud);
    await t.pumpAndSettle();

    // AG-HUD signature: the brand bar + the SIGNAL gauge label.
    expect(find.text('MESHMORE // AG'), findsOneWidget);
    expect(find.text('SIGNAL'), findsOneWidget);
    expect(find.text('MESHMORE // NERV'), findsNothing);
  });

  testWidgets('host shows the DR Pop colour blocks when selected',
      (WidgetTester t) async {
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => FakeMeshcoreTransport(connected: true),
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final ThemeController tc = await _pump(t, mc);
    await tc.setPreset(MmThemePreset.drPop);
    await t.pumpAndSettle();

    // DR Pop signature: trademark brand bar + a PHASE code.
    expect(find.text('MESHMORE™'), findsOneWidget);
    expect(find.textContaining('PHASE_'), findsOneWidget);
    expect(find.text('MESHMORE // AG'), findsNothing);
  });
}
