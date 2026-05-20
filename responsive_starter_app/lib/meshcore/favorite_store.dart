import 'package:shared_preferences/shared_preferences.dart';

/// Persisted set of favourited node public keys (hex).
///
/// In our UX, a **contact** = a fabric node the user has explicitly
/// favourited (an established relationship), distinct from the mesh
/// **fabric** of merely-seen nodes. Survives restarts; drives the
/// R18 rapid-blink semantics.
abstract final class FavoriteStore {
  static const String _kKey = 'mm.favorites.v1';

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
