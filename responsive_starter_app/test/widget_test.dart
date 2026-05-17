// Smoke test for Meshmore SNS app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/app_state_model.dart';
import 'package:meshmore_sns_app/main.dart';
import 'package:meshmore_sns_app/theme/theme_controller.dart';

void main() {
  testWidgets('App boots without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>(create: (_) => AppState()),
          ChangeNotifierProvider<ThemeController>(
            create: (_) => ThemeController(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    // App should mount at least one MaterialApp + Scaffold on first frame.
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);

    // Drain the demo `Future.delayed` timers scheduled by the home page
    // initializer so the test binding doesn't complain about pending timers.
    // (Three 1-second waits.)
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
