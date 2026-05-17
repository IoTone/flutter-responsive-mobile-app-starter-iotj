import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/nodes_screen.dart';

import '../meshcore/fake_transport.dart';

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
    await t.pumpAndSettle();

    expect(find.text('RepeaterA'), findsOneWidget);
    expect(find.text('NodeZ'), findsOneWidget);
    expect(find.textContaining('node(s) in range'), findsOneWidget);
    expect(ctrl.nodes.length, 2);
    ctrl.dispose();
  });
}
