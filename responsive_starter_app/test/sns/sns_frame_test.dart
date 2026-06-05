// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/sns/sns_frame.dart';

void main() {
  group('SnsFrame', () {
    test('caps grow metro < region < mesh', () {
      expect(SnsFrame.metro.maxHalfMeters, 20000);
      expect(SnsFrame.region.maxHalfMeters, 300000);
      expect(SnsFrame.mesh.maxHalfMeters,
          greaterThan(SnsFrame.region.maxHalfMeters));
    });

    test('next cycles metro → region → mesh → metro', () {
      expect(SnsFrame.metro.next, SnsFrame.region);
      expect(SnsFrame.region.next, SnsFrame.mesh);
      expect(SnsFrame.mesh.next, SnsFrame.metro);
    });
  });

  group('snsHalfExtentMeters', () {
    test('fits content (farthest + 15%) between scales', () {
      // 10 km farthest item, metro cap → 11.5 km.
      expect(snsHalfExtentMeters(10000, SnsFrame.metro.maxHalfMeters),
          closeTo(11500, 1));
    });

    test('clamps to the frame cap when content is farther', () {
      // Seattle ~233 km from Portland: metro caps at 20 km (edge-pinned),
      // region frames it.
      expect(snsHalfExtentMeters(233000, SnsFrame.metro.maxHalfMeters),
          20000);
      expect(snsHalfExtentMeters(233000, SnsFrame.region.maxHalfMeters),
          closeTo(233000 * 1.15, 1));
    });

    test('mesh fits even a very distant node', () {
      // ~430 km (Vancouver BC) fits under the mesh cap.
      expect(snsHalfExtentMeters(430000, SnsFrame.mesh.maxHalfMeters),
          closeTo(430000 * 1.15, 1));
    });

    test('never collapses below the 600 m floor', () {
      expect(snsHalfExtentMeters(0, SnsFrame.metro.maxHalfMeters), 600);
    });
  });
}
