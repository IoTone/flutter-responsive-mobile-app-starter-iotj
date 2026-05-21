// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/gen/app_localizations.dart';
import 'package:meshmore_sns_app/l10n/locale_controller.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/dashboard_screen.dart';

import '../meshcore/fake_transport.dart';

const List<LocalizationsDelegate<Object>> _kLocaleDelegates =
    <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  testWidgets('offline → connected dashboard (status slab, radio, feed)',
      (WidgetTester t) async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: LocaleController.supported,
        localizationsDelegates: _kLocaleDelegates,
        home: ChangeNotifierProvider<MeshcoreController>.value(
          value: ctrl,
          child: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );

    // Disconnected state.
    expect(find.text('PEERS IN RANGE'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.textContaining('OFFLINE'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);
    expect(find.text('— awaiting device —'), findsOneWidget);
    expect(find.text('— no activity —'), findsOneWidget);

    // Connect + handshake.
    await ctrl.connect();
    fake.emit(selfInfoFrame());
    await t.pumpAndSettle();

    expect(find.textContaining('LINKED · NO ALERTS'), findsOneWidget);
    expect(find.text('CONNECT'), findsNothing);
    expect(find.textContaining('self-info'), findsOneWidget);

    // An inbound channel message lands in the recent feed.
    final Uint8List chMsg = Uint8List.fromList(<int>[
      0x08, 0x00, 0x03, 0x00, 0x04, 0x03, 0x02, 0x01,
      ...utf8.encode('hello mesh'),
    ]);
    fake.emit(chMsg);
    await t.pumpAndSettle();
    expect(find.textContaining('"hello mesh"'), findsOneWidget);
    ctrl.dispose();
  });
}
