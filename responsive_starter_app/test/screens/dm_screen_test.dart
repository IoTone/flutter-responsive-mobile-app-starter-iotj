// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/dm_screen.dart';

import '../meshcore/fake_transport.dart';

Widget _host(MeshcoreController mc, String peer) => MaterialApp(
      home: ChangeNotifierProvider<MeshcoreController>.value(
        value: mc,
        child: DmScreen(peerPubKeyHex: peer),
      ),
    );

void main() {
  testWidgets('DM history renders + compose+send emits 0x02',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController mc = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    // Deterministic peer hex (full 64) — the full inbound prefix→
    // node match is covered by the controller test.
    const String peer =
        'aabbccddeeff' '00000000000000000000000000'
        '00000000000000000000000000';

    // Pump FIRST (testWidgets' fake clock advances only via pump;
    // bare `Future.delayed` inside the test callback hangs).
    await t.pumpWidget(_host(mc, peer));
    await t.pump();
    expect(find.text('— no messages yet —'), findsOneWidget);

    await mc.connect();
    fake.emit(selfInfoFrame()); // → ready
    await t.pump();
    await t.pump(const Duration(milliseconds: 10));

    // Compose + send a DM (outgoing path).
    await t.enterText(find.byType(TextField), 'reply to peer');
    await t.pump();
    await t.tap(find.byIcon(Icons.send));
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));

    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x02), isTrue);
    expect(find.text('reply to peer'), findsOneWidget);
    mc.dispose();
  });
}
