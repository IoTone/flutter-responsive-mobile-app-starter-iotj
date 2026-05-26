// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT

/// Spatial-aware proximity classification for the IN RANGE / FAR
/// badges. Resolved by `MeshcoreController.proximityFor(node)`,
/// which has access to our own GPS fix.
///
/// Thresholds are deliberately wide (10 / 50 km) to absorb practical
/// LoRa multi-hop reach without yelling "FAR" at someone two cities
/// over who's still actually reachable.
enum NodeProximity {
  /// Both ends have GPS and distance < 10 km. UX: green "IN RANGE".
  near,

  /// Both ends have GPS and 10 km ≤ distance ≤ 50 km. UX: no badge
  /// — known location, ambiguously reachable. Distance text already
  /// communicates this.
  mid,

  /// Both ends have GPS and distance > 50 km. UX: "FAR" badge in a
  /// muted colour so the user can spot accidental long-haul entries.
  far,

  /// Distance unavailable (we or the peer has no GPS) AND the node
  /// has been heard within the last 5 minutes. UX: "IN RANGE" badge,
  /// because over the air we can apparently still talk to them.
  recent,

  /// Distance unavailable, no recent traffic. UX: no badge.
  unknown,
}

/// A Meshcore node discovered "in the area" — from a contact list
/// entry (`RESP_CODE_CONTACT`) or an over-the-air advertisement
/// (`PUSH_CODE_ADVERTISEMENT`). Keyed by full public key.
class DiscoveredNode {
  DiscoveredNode({
    required this.pubKeyHex,
    required this.name,
    required this.type,
    required this.lastHeardUnix,
    this.latitude,
    this.longitude,
    this.altitudeMeters,
    this.snrDb,
    this.rssi,
    this.deviceAdvertUnix,
    required this.viaAdvert,
  });

  final String pubKeyHex;
  String name;
  int type; // advert/contact type: 1 chat, 2 repeater, 3 room, 4 sensor
  int lastHeardUnix;
  double? latitude;
  double? longitude;

  /// R44 — altitude in metres above the WGS-84 ellipsoid, when
  /// known. Source-dependent:
  /// - For our own node: populated from the phone GPS fix when
  ///   present (PhoneFix.altitudeMeters), or from a future firmware
  ///   field that exposes the device's stored altitude.
  /// - For peers: always null today because the MeshCore advert
  ///   payload doesn't carry altitude yet (see
  ///   [Advert.altitudeMeters]). Reserved so consumers can wire UI
  ///   ahead of the wire-format work.
  double? altitudeMeters;

  double? snrDb;
  int? rssi;

  /// For contact-sourced nodes: the raw `lastAdvertTimestamp` in the
  /// *device's* clock. Kept so [lastHeardUnix] can be re-derived once
  /// the device-clock offset is learned (CURR_TIME may arrive after
  /// the contact). Null for live-advert nodes (already local time).
  int? deviceAdvertUnix;

  /// True if last updated from an OTA advert (vs. a synced contact).
  bool viaAdvert;

  /// True if we've heard from this node in the last 5 minutes.
  /// Purely temporal — does NOT imply spatial proximity (a node 300
  /// km away heard 30 s ago is still "recent"). For the UX-facing
  /// "in range" badge, use `MeshcoreController.proximityFor(node)`,
  /// which factors in actual distance when we have GPS on both ends.
  bool get recentlyHeard =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 - lastHeardUnix < 300;

  /// Deprecated alias kept temporarily for any external callers; same
  /// semantics as [recentlyHeard]. Internal call sites must use
  /// `MeshcoreController.proximityFor` so the badge reflects actual
  /// distance, not just recency.
  @Deprecated('Use MeshcoreController.proximityFor for spatial-aware '
      'badge logic; this getter is recency-only.')
  bool get inRange => recentlyHeard;

  String get signalLabel {
    final List<String> p = <String>[
      if (snrDb != null) 'SNR ${snrDb!.toStringAsFixed(1)}',
      if (rssi != null) 'RSSI $rssi',
    ];
    return p.join(' ');
  }

  String get typeLabel => switch (type) {
        1 => 'Chat',
        2 => 'Repeater',
        3 => 'Room',
        4 => 'Sensor',
        _ => 'Node',
      };

  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      latitude!.abs() <= 90.0 &&
      longitude!.abs() <= 180.0;

  String get shortId =>
      pubKeyHex.length >= 12 ? pubKeyHex.substring(0, 12) : pubKeyHex;
}
