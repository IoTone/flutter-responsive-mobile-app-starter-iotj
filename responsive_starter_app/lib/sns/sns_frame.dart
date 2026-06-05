// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT

/// R51/R54 — the SNS grid's base **scale stop**. The view fits content
/// to the chosen frame's cap, so the user can pull back from a tight
/// metro view to a regional or whole-mesh one (a node 200+ km away —
/// Seattle, Vancouver BC — would otherwise sit off the 20 km frame).
///
/// Analogous to the radial view's range stops, kept as a pure enum so
/// the scale math is unit-testable away from the painter.
enum SnsFrame {
  /// Tight local view — ~20 km half-extent. Default; distant nodes pin
  /// to the edge.
  metro,

  /// Regional — ~300 km half-extent (covers e.g. the Puget Sound from
  /// Portland). Farther nodes still edge-pin.
  region,

  /// Whole mesh — fit every item, however far (effectively unbounded
  /// for a LoRa fabric).
  mesh,
}

extension SnsFrameX on SnsFrame {
  /// Upper bound on the view's half-extent, in metres.
  double get maxHalfMeters => switch (this) {
        SnsFrame.metro => 20000,
        SnsFrame.region => 300000,
        SnsFrame.mesh => 5000000,
      };

  /// The next stop in the cycle (metro → region → mesh → metro).
  SnsFrame get next =>
      SnsFrame.values[(index + 1) % SnsFrame.values.length];
}

/// The view's half-extent in metres: fit-to-content (the farthest item,
/// plus 15% margin) clamped between a 600 m floor and the frame's cap.
double snsHalfExtentMeters(double maxOffsetMeters, double maxHalfMeters) =>
    (maxOffsetMeters * 1.15).clamp(600.0, maxHalfMeters);
