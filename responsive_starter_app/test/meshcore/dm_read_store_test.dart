// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/dm_read_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('default load → empty map; never-read peers are 0', () async {
    final DmReadStore s = DmReadStore();
    await s.load();
    expect(s.loaded, isTrue);
    expect(s.lastReadAtMs('deadbeef'), 0);
  });

  test('markRead persists across a fresh load', () async {
    final DmReadStore a = DmReadStore();
    await a.load();
    await a.markRead('peer-1', at: DateTime(2026, 5, 21, 10));
    expect(a.lastReadAtMs('peer-1'),
        DateTime(2026, 5, 21, 10).millisecondsSinceEpoch);

    final DmReadStore b = DmReadStore();
    await b.load();
    expect(b.lastReadAtMs('peer-1'),
        DateTime(2026, 5, 21, 10).millisecondsSinceEpoch);
  });

  test('markRead is monotonic — older timestamps are ignored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final DmReadStore s = DmReadStore();
    await s.load();
    final DateTime later = DateTime(2026, 5, 21, 12);
    final DateTime earlier = DateTime(2026, 5, 21, 8);
    await s.markRead('peer-2', at: later);
    await s.markRead('peer-2', at: earlier);
    expect(
        s.lastReadAtMs('peer-2'), later.millisecondsSinceEpoch,
        reason: 'an earlier mark must not un-read later messages');
  });
}
