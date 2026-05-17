import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/diagnostics_screen.dart';

import '../meshcore/fake_transport.dart';

void main() {
  Future<(MeshcoreController, FakeMeshcoreTransport)> pump(
      WidgetTester t) async {
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
          child: const DiagnosticsScreen(),
        ),
      ),
    );
    return (ctrl, fake);
  }

  testWidgets('starts disconnected; connect → ready shows device',
      (WidgetTester t) async {
    final (MeshcoreController ctrl, FakeMeshcoreTransport fake) =
        await pump(t);

    expect(find.textContaining('State: disconnected'), findsOneWidget);
    expect(find.text('Scan & connect'), findsOneWidget);

    await t.tap(find.text('Scan & connect'));
    await t.pumpAndSettle();
    fake.emit(selfInfoFrame());
    await t.pumpAndSettle();

    expect(find.textContaining('State: ready'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    ctrl.dispose();
  });

  testWidgets('send button transmits a frame once connected',
      (WidgetTester t) async {
    final (MeshcoreController ctrl, FakeMeshcoreTransport fake) =
        await pump(t);
    await t.tap(find.text('Scan & connect'));
    await t.pumpAndSettle();
    fake.emit(selfInfoFrame());
    await t.pumpAndSettle();

    final int before = fake.sent.length; // APP_START already sent
    await t.tap(find.text('Get time'));
    await t.pumpAndSettle();
    expect(fake.sent.length, greaterThan(before));
    expect(find.text('Sent get-time'), findsOneWidget);
    ctrl.dispose();
  });

  testWidgets('raw frame log decodes inbound frames', (WidgetTester t) async {
    final (MeshcoreController ctrl, FakeMeshcoreTransport fake) =
        await pump(t);
    await t.tap(find.text('Scan & connect'));
    await t.pumpAndSettle();
    fake.emit(currentTimeFrame());
    await t.pumpAndSettle();

    expect(find.textContaining('CurrentTimeFrame'), findsWidgets);
    ctrl.dispose();
  });
}
