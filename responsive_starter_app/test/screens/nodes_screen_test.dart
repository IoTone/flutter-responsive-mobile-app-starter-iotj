// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/gen/app_localizations.dart';
import 'package:meshmore_sns_app/l10n/locale_controller.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/nodes_screen.dart';

import '../meshcore/fake_transport.dart';

const List<LocalizationsDelegate<Object>> _kLocaleDelegates =
    <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: LocaleController.supported,
      localizationsDelegates: _kLocaleDelegates,
      home: child,
    );

void main() {
  testWidgets('discovers nodes from CONTACT + ADVERT frames',
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
          child: const Scaffold(body: NodesScreen()),
        ),
      ),
    );

    expect(find.textContaining('Not connected'), findsOneWidget);

    await ctrl.connect();
    fake.emit(selfInfoFrame());
    await t.pumpAndSettle();

    // CONTACT (0x03) via the encode→swap-opcode round-trip trick.
    final Contact c = Contact(
      publicKey: Uint8List.fromList(List<int>.generate(32, (int i) => i + 1)),
      type: 2,
      flags: 0,
      outPathLen: 0,
      outPath: Uint8List(64),
      name: 'RepeaterA',
      lastAdvertTimestamp: 1700000000,
      latitudeMicros: 1000000,
      longitudeMicros: -2000000,
      lastMod: 1,
    );
    final Uint8List cf = MeshcoreFrameCodec.addUpdateContact(c);
    cf[0] = 0x03;
    fake.emit(cf);

    // ADVERT (0x80): pubkey + ts + sig + app_data(flags|name).
    final List<int> adv = <int>[
      0x80,
      ...List<int>.generate(32, (int i) => i + 9),
      0x04, 0x03, 0x02, 0x01,
      ...List<int>.filled(64, 0x55),
      kAdvTypeChat | kAdvNameMask,
      ...utf8.encode('NodeZ'),
    ];
    fake.emit(Uint8List.fromList(adv));

    // RF-log (0x88) wrapping an ADVERT OTA packet → node WITH signal.
    final List<int> advPayload = <int>[
      ...List<int>.generate(32, (int i) => i + 40),
      0x04, 0x03, 0x02, 0x01,
      ...List<int>.filled(64, 0x11),
      kAdvTypeChat | kAdvNameMask,
      ...utf8.encode('RfNode'),
    ];
    final int header = (kPayloadTypeAdvert << kPktPayloadTypeShift) |
        kRouteFlood;
    final List<int> rfLog = <int>[
      0x88,
      6 * 4, // SNR +6.0
      (-90) & 0xFF, // RSSI -90
      header,
      0x00, // path-len: 0 hops
      ...advPayload,
    ];
    fake.emit(Uint8List.fromList(rfLog));
    await t.pumpAndSettle();

    expect(find.text('RepeaterA'), findsOneWidget);
    expect(find.text('NodeZ'), findsOneWidget);
    expect(find.text('RfNode'), findsOneWidget);
    expect(find.textContaining('SNR 6.0'), findsOneWidget);
    expect(find.textContaining('in fabric'), findsOneWidget);
    expect(ctrl.nodes.length, 3);

    // Scan action solicits adverts + syncs contacts.
    final int before = fake.sent.length;
    await t.tap(find.text('Scan area'));
    await t.pump();
    expect(find.text('Scanning…'), findsOneWidget);
    expect(fake.sent.length, greaterThanOrEqualTo(before + 2));
    ctrl.dispose();
  });

  testWidgets('Advertise broadcasts a self-advert (0x07) + explains',
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
          child: const Scaffold(body: NodesScreen()),
        ),
      ),
    );
    await ctrl.connect();
    fake.emit(selfInfoFrame());
    await t.pumpAndSettle();

    // Empty state sets the right expectation (advert-driven).
    expect(find.textContaining('Discovery is advert-driven'),
        findsOneWidget);

    // Advertise opens a routing chooser.
    await t.tap(find.text('Advertise'));
    await t.pumpAndSettle();
    expect(find.text('Flood advert'), findsOneWidget);
    expect(find.text('Zero-hop advert'), findsOneWidget);

    // Flood → SEND_SELF_ADVERT (0x07) with flood flag 1.
    await t.tap(find.text('Flood advert'));
    await t.pumpAndSettle();
    expect(
      fake.sent.any((f) => f.length >= 2 && f[0] == 0x07 && f[1] == 1),
      isTrue,
    );
    expect(find.textContaining('Flood advert sent'), findsOneWidget);

    // Zero-hop → flood flag 0.
    await t.tap(find.text('Advertise'));
    await t.pumpAndSettle();
    await t.tap(find.text('Zero-hop advert'));
    await t.pumpAndSettle();
    expect(
      fake.sent.any((f) => f.length >= 2 && f[0] == 0x07 && f[1] == 0),
      isTrue,
    );
    expect(find.textContaining('Zero-hop advert sent'), findsOneWidget);
    ctrl.dispose();
  });

  testWidgets('star toggles a fabric node into a contact (favourite)',
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
          child: const Scaffold(body: NodesScreen()),
        ),
      ),
    );
    await ctrl.connect();
    fake.emit(selfInfoFrame()); // → ready, so the status line renders
    fake.emit(advertFrame(name: 'AdvNode', firstPubByte: 70));
    await t.pumpAndSettle();

    // One row → one star (initially outlined).
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);

    await t.tap(find.byIcon(Icons.star_border));
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNothing);
    expect(ctrl.favorites, hasLength(1));
    expect(find.textContaining('1 contact'), findsOneWidget);

    // Untoggle.
    await t.tap(find.byIcon(Icons.star));
    await t.pumpAndSettle();
    expect(ctrl.favorites, isEmpty);
    ctrl.dispose();
  });
}
