// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

/// One node's mutable position + velocity in the force-directed
/// simulation. Pinned nodes (e.g. the user's own node at the centre)
/// have their position locked.
class NodePosition {
  NodePosition({
    required this.x,
    required this.y,
    this.pinned = false,
  });

  double x;
  double y;
  double vx = 0;
  double vy = 0;
  final bool pinned;
}

/// R50 — Fruchterman-Reingold-flavoured force-directed layout.
///
/// Each [step] applies three forces to every node:
/// - **Repulsion** between all pairs (Coulomb-style, ∝ 1/d²).
/// - **Attraction** along each edge (spring toward a rest length).
/// - **Centering** so the cloud doesn't drift off-canvas.
///
/// The integration is verlet-ish with strong damping — produces a
/// pleasant settling motion instead of an oscillating spring-mass
/// system. Tuned for ~50–200 nodes; outside that range tweak
/// [repulsion] / [springLength] / [damping].
///
/// The class is mutable and stateful so the view layer can step it
/// once per animation frame without reallocating. Pure-Dart, no
/// Flutter dependency — fully unit-testable.
class ForceLayout {
  ForceLayout({
    required this.positions,
    required this.edges,
    this.repulsion = 6000.0,
    this.springLength = 70.0,
    this.springStiffness = 0.06,
    this.damping = 0.82,
    this.centerStrength = 0.012,
    this.centerX = 0,
    this.centerY = 0,
  });

  /// Mutable; one entry per node id. The simulation rewrites
  /// `x` / `y` / `vx` / `vy` in place each [step].
  final Map<String, NodePosition> positions;

  /// Undirected edge list — `(fromId, toId)` pairs. Edge direction
  /// doesn't matter for spring forces; the view layer handles
  /// drawing arrowheads.
  final List<(String, String)> edges;

  double repulsion;
  double springLength;
  double springStiffness;
  double damping;
  double centerStrength;
  double centerX;
  double centerY;

  /// One simulation tick. Idempotent given the same inputs; safe to
  /// call from a paint callback. Returns the **kinetic energy** of
  /// the system after the step — when this approaches zero the
  /// layout has settled and the view can stop animating.
  double step({double dt = 0.02}) {
    final List<String> ids = positions.keys.toList(growable: false);
    final int n = ids.length;
    final Map<String, double> fx = <String, double>{
      for (final String id in ids) id: 0
    };
    final Map<String, double> fy = <String, double>{
      for (final String id in ids) id: 0
    };

    // Repulsion — all-pairs O(n²). For meshes of <200 nodes this is
    // ~40 K operations per step, fine at 60 fps.
    for (int i = 0; i < n; i++) {
      final NodePosition a = positions[ids[i]]!;
      for (int j = i + 1; j < n; j++) {
        final NodePosition b = positions[ids[j]]!;
        double dx = a.x - b.x;
        double dy = a.y - b.y;
        double d2 = dx * dx + dy * dy;
        if (d2 < 1) {
          // Coincident nodes — push apart in a deterministic
          // direction so the sim doesn't NaN.
          dx = 0.5 - (i / n);
          dy = 0.5 - (j / n);
          d2 = dx * dx + dy * dy + 1;
        }
        final double d = math.sqrt(d2);
        final double f = repulsion / d2;
        final double ux = dx / d;
        final double uy = dy / d;
        fx[ids[i]] = fx[ids[i]]! + ux * f;
        fy[ids[i]] = fy[ids[i]]! + uy * f;
        fx[ids[j]] = fx[ids[j]]! - ux * f;
        fy[ids[j]] = fy[ids[j]]! - uy * f;
      }
    }

    // Springs — pull connected nodes toward [springLength].
    for (final (String fromId, String toId) in edges) {
      final NodePosition? a = positions[fromId];
      final NodePosition? b = positions[toId];
      if (a == null || b == null) continue;
      double dx = b.x - a.x;
      double dy = b.y - a.y;
      double d = math.sqrt(dx * dx + dy * dy);
      if (d < 1) d = 1;
      final double displacement = d - springLength;
      final double f = springStiffness * displacement;
      final double ux = dx / d;
      final double uy = dy / d;
      fx[fromId] = fx[fromId]! + ux * f;
      fy[fromId] = fy[fromId]! + uy * f;
      fx[toId] = fx[toId]! - ux * f;
      fy[toId] = fy[toId]! - uy * f;
    }

    // Centering — weak pull toward the canvas centre so islands of
    // disconnected nodes don't drift to infinity.
    for (final String id in ids) {
      final NodePosition p = positions[id]!;
      fx[id] = fx[id]! + (centerX - p.x) * centerStrength;
      fy[id] = fy[id]! + (centerY - p.y) * centerStrength;
    }

    // Integrate. Pinned nodes keep their position; their velocity
    // stays zero so they don't accumulate force.
    double kinetic = 0;
    for (final String id in ids) {
      final NodePosition p = positions[id]!;
      if (p.pinned) {
        p.vx = 0;
        p.vy = 0;
        continue;
      }
      p.vx = (p.vx + fx[id]! * dt) * damping;
      p.vy = (p.vy + fy[id]! * dt) * damping;
      p.x += p.vx;
      p.y += p.vy;
      kinetic += p.vx * p.vx + p.vy * p.vy;
    }
    return kinetic;
  }
}
