// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/gen/app_localizations.dart';
import 'package:meshmore_sns_app/l10n/locale_controller.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/grid_screen.dart';
import 'package:meshmore_sns_app/theme/theme_controller.dart';

import '../meshcore/fake_transport.dart';

Widget _host(MeshcoreController mc) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<MeshcoreController>.value(value: mc),
          ChangeNotifierProvider<ThemeController>(
              create: (_) => ThemeController()),
        ],
        child: const GridScreen(),
      ),
    );

void main() {
  testWidgets('empty state when nothing is in fabric', (t) async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc =
        MeshcoreController(transportFactory: () async => fake);
    await t.pumpWidget(_host(mc));
    await t.pump();
    expect(find.text('Hyperlocal grid'), findsOneWidget);
    expect(
        find.textContaining('No fabric in range yet'), findsOneWidget);
    expect(t.takeException(), isNull);
    // Tear down — GridScreen owns a repeating AnimationController; the
    // explicit replacement triggers dispose so it's stopped cleanly.
    await t.pumpWidget(const SizedBox());
    mc.dispose();
  });

  testWidgets('with one node visible, status reads "1 in fabric"',
      (WidgetTester t) async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    await t.pumpWidget(_host(mc));
    await mc.connect();
    fake.emit(selfInfoFrame()); // → ready
    fake.emit(advertFrame(name: 'AdvNode', firstPubByte: 70));
    // Animate a couple of frames; the AnimationController repeats so
    // pumpAndSettle would never settle.
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));

    expect(find.textContaining('1 in fabric'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    mc.dispose();
  });
}
