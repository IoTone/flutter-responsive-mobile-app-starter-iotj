// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import '../meshcore/city_lookup.dart';
import 'place_inference.dart';

/// R54 (c) — bridges the bundled GeoNames [CityLookup] to the
/// place-inference engine's [PlaceGazetteer] interface.
///
/// Reads the shared [CityLookup] instance lazily on each lookup
/// (`cachedOrNull`), so it degrades gracefully to "no matches" until the
/// asset has finished loading — the engine just yields nothing until
/// then, which is the correct offline-first behaviour. The app warms the
/// lookup at launch (`warmCityLookup`), so it's ready well before chat
/// traffic arrives.
class CityGazetteer implements PlaceGazetteer {
  const CityGazetteer();

  @override
  List<GazPlace> lookup(String name) {
    final CityLookup? lookup = CityLookup.cachedOrNull;
    if (lookup == null) return const <GazPlace>[];
    return <GazPlace>[
      for (final City c in lookup.byName(name))
        GazPlace(
          name: c.name,
          latitude: c.latitude,
          longitude: c.longitude,
          population: c.population,
        ),
    ];
  }
}
