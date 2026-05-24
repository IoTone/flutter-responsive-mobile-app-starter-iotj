// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/meshcore/node_tags_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('NodeTagsStore (R28 persistence)', () {
    test('empty prefs → empty map', () async {
      expect(await NodeTagsStore.load(), isEmpty);
    });

    test('save + load round-trips', () async {
      await NodeTagsStore.save(<String, List<String>>{
        'pk1': <String>['repeater', 'mt-hood'],
        'pk2': <String>['work'],
      });
      final Map<String, List<String>> back = await NodeTagsStore.load();
      expect(back, hasLength(2));
      expect(back['pk1'], <String>['repeater', 'mt-hood']);
      expect(back['pk2'], <String>['work']);
    });

    test('empty-list entries are dropped on save', () async {
      await NodeTagsStore.save(<String, List<String>>{
        'pk1': <String>['repeater'],
        'pk2': <String>[], // tombstone
      });
      final Map<String, List<String>> back = await NodeTagsStore.load();
      expect(back, hasLength(1));
      expect(back.containsKey('pk2'), isFalse,
          reason: 'tombstoned empty lists must not survive');
    });

    test('corrupt blob → empty map (no crash)', () async {
      final SharedPreferences p =
          await SharedPreferences.getInstance();
      await p.setString('mm.nodeTags.v1', '{not json');
      expect(await NodeTagsStore.load(), isEmpty);
    });
  });

  group('MeshcoreController tag API (R28)', () {
    test('addTagTo, tagsFor, removeTagFrom, allTags', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );

      // Empty initial state.
      expect(ctrl.tagsFor('pk1'), isEmpty);
      expect(ctrl.allTags, isEmpty);

      await ctrl.addTagTo('pk1', 'Repeater');
      await ctrl.addTagTo('pk1', 'mt-hood');
      await ctrl.addTagTo('pk2', 'work');
      // Case-insensitive dedup within a node.
      await ctrl.addTagTo('pk1', 'REPEATER');

      expect(ctrl.tagsFor('pk1'), <String>['Repeater', 'mt-hood']);
      expect(ctrl.tagsFor('pk2'), <String>['work']);
      // allTags is a deduped union (case-insensitive), sorted.
      expect(ctrl.allTags,
          <String>['mt-hood', 'Repeater', 'work']);

      await ctrl.removeTagFrom('pk1', 'mt-hood');
      expect(ctrl.tagsFor('pk1'), <String>['Repeater']);

      // Remove last tag → entry drops out of allTags.
      await ctrl.removeTagFrom('pk1', 'Repeater');
      await ctrl.removeTagFrom('pk2', 'work');
      expect(ctrl.tagsFor('pk1'), isEmpty);
      expect(ctrl.allTags, isEmpty);
      ctrl.dispose();
    });

    test('empty / whitespace-only tags are rejected', () async {
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController ctrl = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );
      await ctrl.addTagTo('pk1', '');
      await ctrl.addTagTo('pk1', '   ');
      expect(ctrl.tagsFor('pk1'), isEmpty);
      ctrl.dispose();
    });

    test('tags persist across controller re-construction', () async {
      // Seed prefs through one controller.
      final FakeMeshcoreTransport fake =
          FakeMeshcoreTransport(connected: true);
      final MeshcoreController a = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );
      await a.addTagTo('pk1', 'repeater');
      a.dispose();

      // Fresh controller picks up the persisted blob.
      final MeshcoreController b = MeshcoreController(
        transportFactory: () async => fake,
        connection: MeshcoreConnection(
            handshakeTimeout: const Duration(seconds: 5)),
      );
      // Wait for the _loadTags microtask to land.
      await Future<void>.delayed(Duration.zero);
      expect(b.tagsFor('pk1'), <String>['repeater']);
      b.dispose();
    });
  });
}
