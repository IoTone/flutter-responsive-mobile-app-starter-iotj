// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/paired_device_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('R41+1 PairedDeviceHistoryStore', () {
    test('empty prefs → empty list', () async {
      expect(await PairedDeviceHistoryStore.load(), isEmpty);
    });

    test('touch upserts and promotes most-recent to head', () async {
      await PairedDeviceHistoryStore.touch('id-a', 'Alpha');
      await PairedDeviceHistoryStore.touch('id-b', 'Bravo');
      await PairedDeviceHistoryStore.touch('id-c', 'Charlie');

      List<PairedDeviceHistoryEntry> hist =
          await PairedDeviceHistoryStore.load();
      expect(hist.map((PairedDeviceHistoryEntry e) => e.remoteId),
          <String>['id-c', 'id-b', 'id-a']);

      // Re-touching an existing entry promotes it, doesn't duplicate.
      await PairedDeviceHistoryStore.touch('id-a', 'Alpha');
      hist = await PairedDeviceHistoryStore.load();
      expect(hist.length, 3, reason: 'no duplicates');
      expect(hist.first.remoteId, 'id-a');
    });

    test('cap at maxEntries (5): oldest drops off', () async {
      for (final String suffix in <String>['1', '2', '3', '4', '5', '6']) {
        await PairedDeviceHistoryStore.touch('id-$suffix', 'Dev-$suffix');
        // Force a 1 ms gap so the lastUsedUnix ordering is stable
        // even at sub-second resolution (the store uses
        // millis-since-epoch ÷ 1000).
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final List<PairedDeviceHistoryEntry> hist =
          await PairedDeviceHistoryStore.load();
      expect(hist.length, 5);
      expect(hist.map((PairedDeviceHistoryEntry e) => e.remoteId),
          <String>['id-6', 'id-5', 'id-4', 'id-3', 'id-2']);
      expect(hist.any((PairedDeviceHistoryEntry e) => e.remoteId == 'id-1'),
          isFalse, reason: 'oldest entry must have dropped');
    });

    test('remove drops a specific entry', () async {
      await PairedDeviceHistoryStore.touch('id-a', 'Alpha');
      await PairedDeviceHistoryStore.touch('id-b', 'Bravo');
      await PairedDeviceHistoryStore.remove('id-a');
      final List<PairedDeviceHistoryEntry> hist =
          await PairedDeviceHistoryStore.load();
      expect(hist.length, 1);
      expect(hist.single.remoteId, 'id-b');
    });

    test('remove is a no-op for unknown id', () async {
      await PairedDeviceHistoryStore.touch('id-a', 'Alpha');
      await PairedDeviceHistoryStore.remove('not-in-list');
      final List<PairedDeviceHistoryEntry> hist =
          await PairedDeviceHistoryStore.load();
      expect(hist.length, 1);
    });

    test('corrupt blob → empty list (no crash)', () async {
      final SharedPreferences p =
          await SharedPreferences.getInstance();
      await p.setString('mm.pairedHistory.v1', '{not valid');
      expect(await PairedDeviceHistoryStore.load(), isEmpty);
    });
  });
}
