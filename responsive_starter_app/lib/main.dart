// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import 'package:meshmore_sns_app/app_router.dart';
import 'package:meshmore_sns_app/app_state_model.dart';
import 'package:meshmore_sns_app/cue/asset_audio_pack.dart';
import 'package:meshmore_sns_app/cue/cue_service.dart';
import 'package:meshmore_sns_app/gen/app_localizations.dart';
import 'package:meshmore_sns_app/l10n/locale_controller.dart';
import 'package:meshmore_sns_app/meshcore/auto_publish_controller.dart';
import 'package:meshmore_sns_app/meshcore/background_keepalive.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/perms/first_run_controller.dart';
import 'package:meshmore_sns_app/perms/location_service.dart';
import 'package:meshmore_sns_app/perms/permissions_service.dart';
import 'package:meshmore_sns_app/screens/first_run_intro_screen.dart';
import 'package:meshmore_sns_app/splash/branded_splash_screen.dart';
import 'package:meshmore_sns_app/theme/theme_controller.dart';
import 'package:meshmore_sns_app/tts/tts_controller.dart';

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
          ChangeNotifierProvider<TtsController>(
            create: (_) => TtsController()..load(),
          ),
          Provider<CueService>(
            create: (BuildContext ctx) {
              final ThemeController tc = ctx.read<ThemeController>();
              return CueService(
                theme: tc,
                // R12 per-theme audio: pull WAV cues from
                // assets/audio/<themeKey>/<cue>.wav at play time.
                audio: AssetAudioPack(theme: tc),
              );
            },
          ),
          ChangeNotifierProvider<MeshcoreController>(
            create: (_) => MeshcoreController(
              backgroundKeepalive: createBackgroundKeepalive(),
              locationService: const GeolocatorLocationService(),
            )..autoConnectIfPaired(),
          ),
          Provider<PermissionsService>(
            create: (_) => const PlatformPermissionsService(),
          ),
          ChangeNotifierProvider<FirstRunController>(
            create: (_) => FirstRunController()..load(),
          ),
          ChangeNotifierProvider<LocaleController>(
            create: (_) => LocaleController()..load(),
          ),
          // R36 — auto-publish location. Owns its own
          // shared_preferences-backed settings + the periodic
          // timer / position stream. Constructed lazily to read
          // the already-built MeshcoreController; loads persisted
          // state immediately so a previously-enabled loop
          // resumes after a cold launch.
          ChangeNotifierProvider<AutoPublishController>(
            create: (BuildContext ctx) => AutoPublishController(
              mc: ctx.read<MeshcoreController>(),
              location: const GeolocatorLocationService(),
            )..load(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  });
}

/// Root widget. Owns the single MaterialApp + the go_router config;
/// theme and font-scale come from [ThemeController] (R14).
///
/// Lifts `FlutterNativeSplash.remove()` up to here (away from
/// HomeShell) so the native splash dismisses regardless of which
/// gate paints next — HomeShell, the first-run intro, or the
/// loading placeholder.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Flutter-side splash min-display gate. Even when first-run prefs
  /// resolve in microseconds the user gets ~1.5 s of the branded
  /// splash with the rotating icon + version readout. Without this,
  /// shared_preferences typically resolves before the first frame
  /// and the splash never shows.
  bool _minSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _minSplashElapsed = true);
    });
  }

  // R4 / U5 — l10n wiring shared between every MaterialApp branch:
  // delegates for the generated AppLocalizations + Material + Cupertino
  // + Widgets, plus the supported-locales list.
  static const List<LocalizationsDelegate<Object>> _localeDelegates =
      <LocalizationsDelegate<Object>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = context.watch<ThemeController>();
    final FirstRunController fr = context.watch<FirstRunController>();
    final LocaleController lc = context.watch<LocaleController>();

    // R21 / U12 — gate the app on first-run state. While the pref
    // is loading we render the splash holder so the test binding
    // doesn't see a different MaterialApp shape mid-frame. When
    // first-run is NOT done we mount a small MaterialApp around the
    // intro screen (so it has theming + a Navigator without booting
    // the full router). When done, the regular router-app boots.
    // Show the branded Flutter splash while either (a) first-run
    // prefs are still loading OR (b) the 1.5 s min-display gate
    // hasn't elapsed. Without (b) the splash never appears on
    // device — shared_preferences usually resolves before the
    // first frame.
    if (!fr.loaded || !_minSplashElapsed) {
      return MaterialApp(
        theme: tc.theme,
        locale: lc.locale,
        supportedLocales: LocaleController.supported,
        localizationsDelegates: _localeDelegates,
        home: const BrandedSplashScreen(),
      );
    }
    if (!fr.done) {
      return MaterialApp(
        title: 'Meshmore SNS',
        theme: tc.theme,
        locale: lc.locale,
        supportedLocales: LocaleController.supported,
        localizationsDelegates: _localeDelegates,
        home: const FirstRunIntroScreen(),
      );
    }
    return MaterialApp.router(
      title: 'Meshmore SNS',
      theme: tc.theme,
      locale: lc.locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: _localeDelegates,
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
