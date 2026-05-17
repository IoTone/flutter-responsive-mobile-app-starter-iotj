import 'package:flutter/material.dart';
import 'package:meshmore_sns_app/about.dart';
import 'package:meshmore_sns_app/main.dart';
import 'package:meshmore_sns_app/screens/personalization_screen.dart';

/// Legacy Navigator 1.0 route table. Kept for the starter views; the
/// Meshmore primary navigation (R11 swipe + long-press menu) will move to
/// `go_router` in a follow-up step.
class RouterClass {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute<void>(builder: (_) => const MyHomePage());
      case '/about':
        return MaterialPageRoute<void>(builder: (_) => const AboutPageWidget());
      case '/personalization':
        return MaterialPageRoute<void>(
            builder: (_) => const PersonalizationScreen());
      default:
        return MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}