import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/known_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save → load round-trips; clear empties', () async {
    await KnownStore.save(<String>{'aa', 'bb'});
    expect(await KnownStore.load(), <String>{'aa', 'bb'});
    await KnownStore.clear();
    expect(await KnownStore.load(), isEmpty);
  });

  test('load on empty prefs returns empty set', () async {
    expect(await KnownStore.load(), isEmpty);
  });
}
