import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/screens/device_config_screen.dart';

import '../meshcore/fake_transport.dart';

void main() {
  testWidgets('radio config: preset fills freq, Apply sends 0x0B',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 2600));
    addTearDown(() => t.binding.setSurfaceSize(null));
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
          child: const DeviceConfigScreen(),
        ),
      ),
    );

    // Not connected initially (Apply is gated on `ready`).
    expect(ctrl.state, MeshcoreConnectionState.disconnected);

    await ctrl.connect();
    fake.emit(selfInfoFrame());
    await t.pumpAndSettle();

    // US band preset (top of the list) fills the frequency field.
    await t.tap(find.text('US (902–928 MHz)'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(
              find.widgetWithText(TextField, 'Frequency (MHz)'))
          .controller!
          .text,
      '915.0',
    );

    final int before = fake.sent.length;
    await t.tap(find.text('Apply radio params'));
    await t.pumpAndSettle();
    expect(fake.sent.length, greaterThan(before));
    // CMD_SET_RADIO_PARAMS opcode is 0x0B.
    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x0B), isTrue);
    ctrl.dispose();
  });
}
