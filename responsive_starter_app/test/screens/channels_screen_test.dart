// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/channels_screen.dart';

import '../meshcore/fake_transport.dart';

Future<MeshcoreController> _ready(FakeMeshcoreTransport fake) async {
  final MeshcoreController ctrl = MeshcoreController(
    transportFactory: () async => fake,
    connection:
        MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
  );
  await ctrl.connect();
  fake.emit(selfInfoFrame()); // → ready
  return ctrl;
}

Widget _host(MeshcoreController mc) => MaterialApp(
      home: ChangeNotifierProvider<MeshcoreController>.value(
        value: mc,
        child: const ChannelsScreen(),
      ),
    );

void main() {
  testWidgets('edit slot via #hashtag sends SET_CHANNEL + lists it',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = await _ready(fake);
    await t.pumpWidget(_host(mc));
    fake.emit(channelInfoFrame(idx: 0, name: 'Public'));
    await t.pumpAndSettle();

    expect(find.text('Public'), findsOneWidget); // slot 0
    expect(find.text('— empty —'), findsWidgets); // empty slots

    // Open the editor for slot 1 (empty → "Set").
    await t.tap(find.text('Set').first);
    await t.pumpAndSettle();
    expect(find.text('Channel slot 1'), findsOneWidget);

    await t.tap(find.text('#tag'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, 'e.g. #mygroup'), '#ops');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    // CMD_SET_CHANNEL opcode is 0x20.
    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x20), isTrue);
    // Name defaults to the hashtag itself; optimistic list update.
    expect(find.text('#ops'), findsOneWidget);
    mc.dispose();
  });

  testWidgets('tapping a configured slot sets it active', (t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = await _ready(fake);
    await t.pumpWidget(_host(mc));
    fake.emit(channelInfoFrame(idx: 1, name: 'Ops'));
    await t.pumpAndSettle();

    expect(mc.activeChannel, 0);
    await t.tap(find.text('Ops'));
    await t.pumpAndSettle();
    expect(mc.activeChannel, 1);
    mc.dispose();
  });
}
