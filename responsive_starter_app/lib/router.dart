import 'package:flutter/material.dart';
import 'package:responsive_starter_app/about.dart';
import 'package:responsive_starter_app/main.dart';

class RouterClass {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (context) => MyHomePage());
      case '/about':
        return MaterialPageRoute(builder: (context) => AboutPageWidget());
      default:
        return MaterialPageRoute(
            builder: (_) => Scaffold(
                  body: Center(
                      child: Text('No route defined for ${settings.name}')),
                ));
    }
  }
}