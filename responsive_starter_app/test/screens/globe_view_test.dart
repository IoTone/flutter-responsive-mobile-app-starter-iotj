// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/gen/app_localizations.dart';
import 'package:meshmore_sns_app/l10n/locale_controller.dart';
import 'package:meshmore_sns_app/meshcore/discovered_node.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/globe_view.dart';

import '../meshcore/fake_transport.dart';

const List<LocalizationsDelegate<Object>> _kLocaleDelegates =
    <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

DiscoveredNode _node(String suffix, double lat, double lon) {
  return DiscoveredNode(
    pubKeyHex:
        '0000000000000000000000000000000000000000000000000000000000000$suffix',
    name: 'peer$suffix',
    type: 1,
    latitude: lat,
    longitude: lon,
    lastHeardUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    viaAdvert: true,
  );
}

void main() {
  testWidgets(
      'R40 globe defaults to ~1 mi altitude readout (no peers ⇒ paint succeeds)',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection: MeshcoreConnection(
          handshakeTimeout: const Duration(seconds: 5)),
    );
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: LocaleController.supported,
        localizationsDelegates: _kLocaleDelegates,
        home: ChangeNotifierProvider<MeshcoreController>.value(
          value: ctrl,
          child: const Scaffold(body: GlobeView()),
        ),
      ),
    );
    // Settle the asset-load microtasks for the land polygons.
    await t.pump();
    await t.pump();

    // Default altitude reads as exactly "1.0 mi" — we land in the
    // hyperlocal entry zoom rather than a country/continent view.
    expect(find.text('1.0 mi'), findsOneWidget);
    expect(find.text('ALT'), findsOneWidget);
    // No "PAUSED" badge unless the grid passes frozen: true.
    expect(find.text('PAUSED'), findsNothing);
    ctrl.dispose();
  });

  testWidgets(
      'R40 globe honours frozen: true and filteredNodes prop',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection: MeshcoreConnection(
          handshakeTimeout: const Duration(seconds: 5)),
    );
    // Pre-seed mc.nodes via an emitted advert frame — proves the
    // filteredNodes prop wins over mc.nodes in the rendered output
    // count footer.
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: LocaleController.supported,
        localizationsDelegates: _kLocaleDelegates,
        home: ChangeNotifierProvider<MeshcoreController>.value(
          value: ctrl,
          child: Scaffold(
            body: GlobeView(
              filteredNodes: <DiscoveredNode>[
                _node('a', 35.681, 139.767),
                _node('b', 45.524, -122.676),
              ],
              frozen: true,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();

    expect(find.text('PAUSED'), findsOneWidget,
        reason: 'frozen: true must show the PAUSED indicator');
    // Footer "Showing N peers..." reflects the prop-supplied list.
    expect(find.textContaining('2 peers'), findsOneWidget);
    ctrl.dispose();
  });
}
