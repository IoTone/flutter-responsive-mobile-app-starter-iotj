import 'package:shared_preferences/shared_preferences.dart';

/// Persisted set of *known* node public keys (hex) — nodes we've had
/// **direct/attributable communication with** (received DM, or one
/// we've directly exchanged with). Per R18 this drives the
/// **steady pulse** on the hyperlocal grid. Distinct from
/// `FavoriteStore` (= "contact" / rapid blink) and from "fabric"
/// (anything seen).
abstract final class KnownStore {
  static const String _kKey = 'mm.known.v1';

  static Future<Set<String>> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final List<String>? v = p.getStringList(_kKey);
    return v == null ? <String>{} : v.toSet();
  }

  static Future<void> save(Set<String> pubKeyHexes) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setStringList(_kKey, pubKeyHexes.toList(growable: false));
  }

  static Future<void> clear() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kKey);
  }
}
