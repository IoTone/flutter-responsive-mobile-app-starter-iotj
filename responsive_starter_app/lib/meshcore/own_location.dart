// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
/// Where our own latitude/longitude came from for distance/bearing
/// math (Nodes screen distances, R18 grid GPS positioning, R22
/// "Set advert location" workflow).
enum OwnLocationSource {
  /// The connected MeshCore device reported a non-zero lat/lon in
  /// `SelfInfo` — typically from its onboard GPS, but could also be
  /// a previously-pinned manual value the device persisted.
  deviceReported,

  /// A one-shot phone-GPS fix (Phase B / U13). Not produced by the
  /// current code path; reserved for the geolocator wiring.
  phoneFix,

  /// No location is known — neither device nor phone has reported
  /// one. UI surfaces this with a "Configure" CTA.
  none,
}

class OwnLocation {
  const OwnLocation({
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final OwnLocationSource source;

  /// A short human-readable source label for status chips/tiles.
  String get sourceLabel => switch (source) {
        OwnLocationSource.deviceReported => 'device',
        OwnLocationSource.phoneFix => 'phone GPS',
        OwnLocationSource.none => 'none',
      };

  @override
  String toString() => 'OwnLocation($latitude, $longitude, $sourceLabel)';
}
