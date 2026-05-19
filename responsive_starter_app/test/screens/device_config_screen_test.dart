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

  testWidgets('Japan (ARIB T108) preset fills freq+BW+SF+CR+TX (R15)',
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
    await ctrl.connect();
    fake.emit(selfInfoFrame());
    await t.pumpAndSettle();

    await t.tap(find.text('JP (920.5–923.5 · ARIB T108)'));
    await t.pumpAndSettle();

    String fieldText(String label) => t
        .widget<TextField>(find.widgetWithText(TextField, label))
        .controller!
        .text;

    // Source: MeshCore issue #460, comment 4080531481 (@jirogit).
    expect(fieldText('Frequency (MHz)'), '920.8');
    expect(fieldText('Bandwidth (kHz)'), '125.0');
    expect(fieldText('Spreading factor (5–12)'), '12');
    expect(fieldText('Coding rate (5–8)'), '8'); // CR 4/8 → denominator 8
    expect(fieldText('TX power (dBm)'), '13');

    final int before = fake.sent.length;
    await t.tap(find.text('Apply radio params'));
    await t.pumpAndSettle();
    expect(fake.sent.length, greaterThan(before));
    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x0B), isTrue);
    ctrl.dispose();
  });

  testWidgets('Identity/Advert: Set name → 0x08, Set location → 0x0E',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 3200));
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
    await ctrl.connect();
    fake.emit(selfInfoFrame());
    await t.pumpAndSettle();

    final Finder scrollable = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('Set name'), 400,
        scrollable: scrollable);
    await t.enterText(
        find.widgetWithText(TextField, 'Node name (advertised)'),
        'NodeA');
    await t.tap(find.text('Set name'));
    await t.pumpAndSettle();
    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x08), isTrue);

    await t.scrollUntilVisible(
        find.text('Set advert location'), 400,
        scrollable: scrollable);
    await t.enterText(
        find.widgetWithText(TextField, 'Advert latitude (°)'), '35.681');
    await t.enterText(
        find.widgetWithText(TextField, 'Advert longitude (°)'),
        '139.767');
    await t.tap(find.text('Set advert location'));
    await t.pumpAndSettle();
    expect(fake.sent.any((f) => f.isNotEmpty && f[0] == 0x0E), isTrue);
    ctrl.dispose();
  });
}
