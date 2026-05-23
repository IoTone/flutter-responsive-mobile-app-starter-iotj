// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:geolocator/geolocator.dart';

/// R22 / U13 — small interface for the **one-shot phone-GPS fix**
/// used as a fallback when the MeshCore device has no GPS. Behind
/// an interface so tests don't reach `geolocator`'s platform plugin
/// (which can't run in a vm/widget test).
///
/// Concrete impls: [GeolocatorLocationService] (real); [NoopLocationService]
/// (test fake — returns whatever was injected).
class PhoneFix {
  const PhoneFix({
    required this.latitude,
    required this.longitude,
    this.altitudeMeters,
  });
  final double latitude;
  final double longitude;

  /// Altitude above the WGS-84 reference ellipsoid, in meters.
  /// Null when the platform didn't report a usable altitude (no
  /// barometric / GPS-derived altitude available).
  final double? altitudeMeters;
}

abstract class LocationService {
  /// Returns a single fix, or `null` if the device says it can't
  /// produce one (services disabled, denied, timeout). Implementations
  /// must catch their own platform exceptions — callers never see
  /// raw plugin errors.
  Future<PhoneFix?> currentFix({Duration timeLimit});
}

/// Real implementation backed by `geolocator`. Uses high accuracy
/// with a default 15 s cap; callers can override.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<PhoneFix?> currentFix(
      {Duration timeLimit = const Duration(seconds: 15)}) async {
    try {
      // Service-enabled check (location off in OS settings → no fix
      // is possible no matter how many perms we have).
      final bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      final Position p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      // Only treat altitude as meaningful when the platform reports
      // a non-zero altitudeAccuracy — otherwise we'd surface 0 m
      // for users whose GPS chips don't supply altitude data.
      final double? alt =
          p.altitudeAccuracy > 0 ? p.altitude : null;
      return PhoneFix(
        latitude: p.latitude,
        longitude: p.longitude,
        altitudeMeters: alt,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Test/default fake — never touches the platform layer. Set
/// [next] to control what the next call returns.
class NoopLocationService implements LocationService {
  NoopLocationService({this.next});
  PhoneFix? next;
  int callCount = 0;

  @override
  Future<PhoneFix?> currentFix({Duration? timeLimit}) async {
    callCount++;
    return next;
  }
}
