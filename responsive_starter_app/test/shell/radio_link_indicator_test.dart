// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/shell/home_shell.dart';

import '../meshcore/fake_transport.dart';

void main() {
  testWidgets('reflects link state: OFFLINE → LINKED',
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
        home: ChangeNotifierProvider<MeshcoreController>.value(
          value: ctrl,
          child: const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: SafeArea(child: RadioLinkIndicator()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('OFFLINE'), findsOneWidget);

    await ctrl.connect();
    await t.pump();
    expect(find.text('SYNC'), findsOneWidget); // handshaking

    fake.emit(selfInfoFrame());
    await t.pumpAndSettle();
    expect(find.text('LINKED'), findsOneWidget);
    ctrl.dispose();
  });
}
