// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/util/force_layout.dart';

void main() {
  group('ForceLayout', () {
    test('two connected nodes converge toward springLength', () {
      // Start them 300 px apart; spring rest length is 70 → after a
      // few hundred steps they should sit close to 70 px apart.
      final layout = ForceLayout(
        positions: <String, NodePosition>{
          'a': NodePosition(x: 0, y: 0, pinned: true),
          'b': NodePosition(x: 300, y: 0),
        },
        edges: <(String, String)>[('a', 'b')],
        centerStrength: 0, // disable centering for this test
      );
      for (int i = 0; i < 500; i++) {
        layout.step();
      }
      final double dx = layout.positions['b']!.x - 0;
      expect(dx, closeTo(70.0, 25.0),
          reason: 'b should settle near spring rest length');
    });

    test('disconnected nodes repel until centered by centerStrength', () {
      final layout = ForceLayout(
        positions: <String, NodePosition>{
          'a': NodePosition(x: 0, y: 0),
          'b': NodePosition(x: 5, y: 0),
        },
        edges: const <(String, String)>[],
        centerX: 100,
        centerY: 100,
      );
      for (int i = 0; i < 600; i++) {
        layout.step();
      }
      // Both end up near the centre but apart from each other.
      final a = layout.positions['a']!;
      final b = layout.positions['b']!;
      expect((a.x - 100).abs(), lessThan(200));
      expect((a.y - 100).abs(), lessThan(200));
      expect(((a.x - b.x).abs() + (a.y - b.y).abs()), greaterThan(20));
    });

    test('pinned node never moves regardless of forces', () {
      final NodePosition self = NodePosition(x: 50, y: 50, pinned: true);
      final layout = ForceLayout(
        positions: <String, NodePosition>{
          'self': self,
          'p': NodePosition(x: 51, y: 51),
        },
        edges: <(String, String)>[('self', 'p')],
      );
      for (int i = 0; i < 200; i++) {
        layout.step();
      }
      expect(self.x, 50.0);
      expect(self.y, 50.0);
      expect(self.vx, 0.0);
      expect(self.vy, 0.0);
    });

    test('kinetic energy decays toward zero (simulation settles)', () {
      final layout = ForceLayout(
        positions: <String, NodePosition>{
          's': NodePosition(x: 100, y: 100, pinned: true),
          'a': NodePosition(x: 300, y: 100),
          'b': NodePosition(x: -100, y: 100),
        },
        edges: <(String, String)>[('s', 'a'), ('s', 'b')],
      );
      // Velocities start at zero, so the first ~10 steps accelerate;
      // peak kinetic is somewhere in the middle. Track the peak,
      // then verify energy at step 800 is well below it.
      double peak = 0;
      for (int i = 0; i < 50; i++) {
        final double k = layout.step();
        if (k > peak) peak = k;
      }
      double late = 0;
      for (int i = 0; i < 800; i++) {
        late = layout.step();
      }
      expect(late, lessThan(peak * 0.2),
          reason: 'damping should drain at least 80% of peak energy');
    });
  });
}
