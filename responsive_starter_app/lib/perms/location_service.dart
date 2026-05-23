// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

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

  /// A long-running stream of fixes that emits only when the user
  /// has moved more than [distanceFilterMeters] from the last
  /// emitted point. Returns an empty stream on platforms or test
  /// fakes that can't deliver it. Used by R36 auto-publish's
  /// "smart broadcast" mode. Callers must cancel the subscription
  /// when done.
  Stream<PhoneFix> positionStream({required int distanceFilterMeters});
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

  @override
  Stream<PhoneFix> positionStream({required int distanceFilterMeters}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        // `medium` accuracy is plenty for distance-filter
        // triggering and dramatically cheaper than `high`.
        accuracy: LocationAccuracy.medium,
        distanceFilter: distanceFilterMeters,
      ),
    ).map((Position p) {
      final double? alt =
          p.altitudeAccuracy > 0 ? p.altitude : null;
      return PhoneFix(
        latitude: p.latitude,
        longitude: p.longitude,
        altitudeMeters: alt,
      );
    });
  }
}

/// Test/default fake — never touches the platform layer. Set
/// [next] to control what the next call returns. Tests can also
/// emit synthetic stream events via [emit].
class NoopLocationService implements LocationService {
  NoopLocationService({this.next});
  PhoneFix? next;
  int callCount = 0;
  int? lastDistanceFilter;

  final StreamController<PhoneFix> _streamCtrl =
      StreamController<PhoneFix>.broadcast();

  @override
  Future<PhoneFix?> currentFix({Duration? timeLimit}) async {
    callCount++;
    return next;
  }

  @override
  Stream<PhoneFix> positionStream({required int distanceFilterMeters}) {
    lastDistanceFilter = distanceFilterMeters;
    return _streamCtrl.stream;
  }

  /// Push a synthetic fix through the stream — tests use this to
  /// simulate the user moving past the distance filter.
  void emit(PhoneFix fix) => _streamCtrl.add(fix);
}
