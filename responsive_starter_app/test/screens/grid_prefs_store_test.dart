// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshmore_sns_app/screens/grid_prefs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('null when nothing saved', () async {
    expect(await GridPrefsStore.load(), isNull);
  });

  test('round-trips the grid preferences', () async {
    await GridPrefsStore.save(const GridPrefs(
      modeIndex: 9,
      scaleIndex: 3,
      northUp: false,
      live: true,
      intervalSec: 30,
    ));
    final GridPrefs p = (await GridPrefsStore.load())!;
    expect(p.modeIndex, 9);
    expect(p.scaleIndex, 3);
    expect(p.northUp, isFalse);
    expect(p.live, isTrue);
    expect(p.intervalSec, 30);
  });
}
