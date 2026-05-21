import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/perms/first_run_controller.dart';
import 'package:meshmore_sns_app/perms/permissions_service.dart';
import 'package:meshmore_sns_app/screens/first_run_intro_screen.dart';

Widget _host(FirstRunController fr, PermissionsService perms) => MultiProvider(
      providers: [
        ChangeNotifierProvider<FirstRunController>.value(value: fr),
        Provider<PermissionsService>.value(value: perms),
      ],
      child: const MaterialApp(home: FirstRunIntroScreen()),
    );

void main() {
  testWidgets('Grant path requests BLE and marks first-run done',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FirstRunController fr = FirstRunController();
    await fr.load();
    final NoopPermissionsService perms = NoopPermissionsService();
    await t.pumpWidget(_host(fr, perms));

    await t.tap(find.text('Grant Bluetooth & continue'));
    await t.pumpAndSettle();

    expect(fr.done, isTrue);
  });

  testWidgets('Skip path marks first-run done without requesting BLE',
      (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FirstRunController fr = FirstRunController();
    await fr.load();
    final NoopPermissionsService perms = NoopPermissionsService(ble: false);
    await t.pumpWidget(_host(fr, perms));

    await t.tap(find.text('Continue offline (skip permissions)'));
    await t.pumpAndSettle();

    expect(fr.done, isTrue);
  });

  testWidgets('Grant denied keeps first-run NOT done and shows '
      'OS-settings affordance', (WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final FirstRunController fr = FirstRunController();
    await fr.load();
    final NoopPermissionsService perms = NoopPermissionsService(ble: false);
    await t.pumpWidget(_host(fr, perms));

    await t.tap(find.text('Grant Bluetooth & continue'));
    await t.pumpAndSettle();

    expect(fr.done, isFalse);
    expect(find.text('Open OS settings'), findsOneWidget);
  });
}
