import 'package:shared_preferences/shared_preferences.dart';

/// Persisted opt-in for the Android background keep-alive foreground
/// service (R17 / U8). Default **on** — the user accepted the
/// persistent notification as the cost of reliable background
/// delivery; users can still turn it off in App settings.
abstract final class BackgroundKeepalivePrefs {
  static const String _kEnabled = 'mm.bg.keepalive';

  static Future<bool> enabled() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? true;
  }

  static Future<void> setEnabled(bool v) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, v);
  }
}
