// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/background_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('default: on for the public channel, off for the rest', () {
    expect(PlaceInferencePrefs.defaultFor(0), isTrue);
    expect(PlaceInferencePrefs.defaultFor(1), isFalse);
    expect(PlaceInferencePrefs.defaultFor(3), isFalse);
  });

  test('overrides round-trip through SharedPreferences', () async {
    await PlaceInferencePrefs.save(<int, bool>{0: false, 2: true});
    final Map<int, bool> back = await PlaceInferencePrefs.overrides();
    expect(back[0], isFalse);
    expect(back[2], isTrue);
    expect(back.containsKey(1), isFalse);
  });

  test('empty prefs → no overrides (falls back to defaults)', () async {
    expect(await PlaceInferencePrefs.overrides(), isEmpty);
  });

  test('corrupt blob → empty overrides (no throw)', () async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{'mm.placeInfer.channels': 'not json'});
    expect(await PlaceInferencePrefs.overrides(), isEmpty);
  });
}
