import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/perms/first_run_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('default load → done is false', () async {
    final FirstRunController c = FirstRunController();
    expect(c.loaded, isFalse);
    await c.load();
    expect(c.loaded, isTrue);
    expect(c.done, isFalse);
  });

  test('markDone persists across load cycles', () async {
    final FirstRunController a = FirstRunController();
    await a.load();
    await a.markDone();
    expect(a.done, isTrue);

    final FirstRunController b = FirstRunController();
    await b.load();
    expect(b.done, isTrue, reason: 'flag survives a fresh load');
  });

  test('reset wipes the flag', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mm.firstRun.done': true,
    });
    final FirstRunController c = FirstRunController();
    await c.load();
    expect(c.done, isTrue);
    await c.reset();
    expect(c.done, isFalse);

    final FirstRunController d = FirstRunController();
    await d.load();
    expect(d.done, isFalse, reason: 'reset removed the pref');
  });

  test('preloaded constructor short-circuits load()', () async {
    final FirstRunController c =
        FirstRunController.preloaded(done: true);
    expect(c.loaded, isTrue);
    expect(c.done, isTrue);
  });
}
