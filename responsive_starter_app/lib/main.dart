import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/app_router.dart';
import 'package:meshmore_sns_app/app_state_model.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/theme/theme_controller.dart';

void main() {
  final WidgetsBinding widgetsBinding =
      WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>(create: (_) => AppState()),
          ChangeNotifierProvider<ThemeController>(
            create: (_) => ThemeController()..load(),
          ),
          ChangeNotifierProvider<MeshcoreController>(
            create: (_) => MeshcoreController()..autoConnectIfPaired(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  });
}

/// Root widget. Owns the single MaterialApp + the go_router config;
/// theme and font-scale come from [ThemeController] (R14).
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = context.watch<ThemeController>();
    return MaterialApp.router(
      title: 'Meshmore SNS',
      theme: tc.theme,
      routerConfig: appRouter,
      builder: (BuildContext context, Widget? child) {
        // User font-size scale (R14) layered on top of the OS text
        // scale (R13 — honour the platform setting).
        final MediaQueryData mq = MediaQuery.of(context);
        final double osScale = mq.textScaler.scale(1.0);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(osScale * tc.fontScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
