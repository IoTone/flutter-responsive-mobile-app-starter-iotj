// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/battery_history_store.dart';
import 'package:meshmore_sns_app/meshcore/battery_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('round-trips per-device samples, oldest first', () async {
    final Map<String, List<BatterySample>> h =
        <String, List<BatterySample>>{
      'aabbccddeeff': <BatterySample>[
        (atUnix: 1000, millivolts: 4100),
        (atUnix: 1180, millivolts: 4050),
      ],
      '001122334455': <BatterySample>[
        (atUnix: 2000, millivolts: 3700),
      ],
    };
    await BatteryHistoryStore.save(h);
    final Map<String, List<BatterySample>> back =
        await BatteryHistoryStore.load();
    expect(back.keys, containsAll(<String>['aabbccddeeff', '001122334455']));
    expect(back['aabbccddeeff']!.length, 2);
    expect(back['aabbccddeeff']!.first.atUnix, 1000);
    expect(back['aabbccddeeff']!.last.millivolts, 4050);
  });

  test('empty store loads as empty map', () async {
    expect(await BatteryHistoryStore.load(), isEmpty);
  });

  test('clear wipes the store', () async {
    await BatteryHistoryStore.save(<String, List<BatterySample>>{
      'aa': <BatterySample>[(atUnix: 1, millivolts: 4000)],
    });
    await BatteryHistoryStore.clear();
    expect(await BatteryHistoryStore.load(), isEmpty);
  });

  test('drops out-of-range voltages and malformed entries on load',
      () async {
    // Hand-craft a corrupt blob directly in prefs.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mm.battery_history.v1':
          '{"dev":[[100,4000],[200,99999],[300,3800],["x","y"],[400]]}',
    });
    final Map<String, List<BatterySample>> back =
        await BatteryHistoryStore.load();
    // 99999 mV (out of range), the string pair, and the 1-element row
    // are all dropped; 4000 and 3800 survive.
    expect(back['dev']!.map((s) => s.millivolts), <int>[4000, 3800]);
  });

  test('corrupt JSON → empty map (no throw)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mm.battery_history.v1': '{ not json',
    });
    expect(await BatteryHistoryStore.load(), isEmpty);
  });
}
