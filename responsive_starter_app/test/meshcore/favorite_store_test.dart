import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/favorite_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save → load round-trips; clear empties', () async {
    await FavoriteStore.save(<String>{'aa', 'bb'});
    expect(await FavoriteStore.load(), <String>{'aa', 'bb'});
    await FavoriteStore.clear();
    expect(await FavoriteStore.load(), isEmpty);
  });

  test('load on empty prefs returns empty set', () async {
    expect(await FavoriteStore.load(), isEmpty);
  });
}
