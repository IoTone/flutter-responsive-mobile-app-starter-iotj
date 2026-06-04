// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart';

/// Registers the licenses of the **bundled non-code assets** with
/// Flutter's [LicenseRegistry] so they appear alongside the package
/// licenses in the standard `showLicensePage`.
///
/// Dependency (pub package) licenses are collected by Flutter
/// automatically; this covers the data + documentation we ship as
/// assets, which Flutter has no way to discover on its own:
///
/// - MeshCore documentation (firmware README + companion-radio-protocol
///   wiki) baked into `assets/docs/` — MIT, © MeshCore contributors.
/// - GeoNames `cities15000` dataset (`assets/data/cities15000.bin`) —
///   **CC-BY 4.0, which requires attribution.**
/// - Natural Earth 110m land polygons (`assets/data/world-110m.geojson`)
///   — public domain.
/// - OpenStreetMap raster tiles (R25 map view, fetched at runtime) —
///   map data © OpenStreetMap contributors, ODbL.
///
/// Call once at startup (before `runApp`).
void registerAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['Meshmore SNS — MeshCore documentation'],
      'The bundled MeshCore documentation (the firmware README and the '
      'Companion Radio Protocol, shown in the Docs section) is sourced '
      'from the MeshCore project at https://github.com/meshcore-dev/MeshCore '
      'and is used under the MIT License.\n'
      '\n'
      'Copyright (c) MeshCore contributors\n'
      '\n'
      'Permission is hereby granted, free of charge, to any person '
      'obtaining a copy of this software and associated documentation '
      'files (the "Software"), to deal in the Software without '
      'restriction, including without limitation the rights to use, copy, '
      'modify, merge, publish, distribute, sublicense, and/or sell copies '
      'of the Software, and to permit persons to whom the Software is '
      'furnished to do so, subject to the following conditions:\n'
      '\n'
      'The above copyright notice and this permission notice shall be '
      'included in all copies or substantial portions of the Software.\n'
      '\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, '
      'EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF '
      'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND '
      'NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS '
      'BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN '
      'ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN '
      'CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE '
      'SOFTWARE.',
    );

    yield const LicenseEntryWithLineBreaks(
      <String>['Meshmore SNS — GeoNames cities'],
      'The offline city dataset (cities15000) is derived from GeoNames '
      '(https://www.geonames.org) and is licensed under the Creative '
      'Commons Attribution 4.0 License (CC BY 4.0).\n'
      '\n'
      '© GeoNames (https://www.geonames.org).\n'
      'See https://creativecommons.org/licenses/by/4.0/ for the full '
      'license text.',
    );

    yield const LicenseEntryWithLineBreaks(
      <String>['Meshmore SNS — Natural Earth'],
      'The world land outline (110m land polygons) is from Natural Earth '
      '(https://www.naturalearthdata.com) and is in the public domain. '
      'No attribution is required; credit is given here as a courtesy.',
    );

    yield const LicenseEntryWithLineBreaks(
      <String>['Meshmore SNS — OpenStreetMap'],
      'The map view renders raster tiles whose underlying map data is '
      '© OpenStreetMap contributors, available under the Open Database '
      'License (ODbL). See https://www.openstreetmap.org/copyright.',
    );
  });
}
