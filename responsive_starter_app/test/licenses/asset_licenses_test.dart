// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meshmore_sns_app/licenses/asset_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled-asset attributions are registered with the license page',
      () async {
    registerAssetLicenses();

    final Set<String> packages = <String>{};
    final Map<String, String> bodies = <String, String>{};
    await for (final LicenseEntry e in LicenseRegistry.licenses) {
      for (final String p in e.packages) {
        packages.add(p);
        bodies[p] =
            e.paragraphs.map((LicenseParagraph p) => p.text).join('\n');
      }
    }

    // The documentation we bundle (the user's question) is attributed
    // with its MIT notice.
    expect(packages, contains('Meshmore SNS — MeshCore documentation'));
    expect(bodies['Meshmore SNS — MeshCore documentation'],
        contains('MIT'));

    // ...and the other attribution-bearing assets we ship.
    expect(packages, contains('Meshmore SNS — GeoNames cities'));
    expect(bodies['Meshmore SNS — GeoNames cities'], contains('CC BY 4.0'));
    expect(packages, contains('Meshmore SNS — Natural Earth'));
    expect(packages, contains('Meshmore SNS — OpenStreetMap'));
  });
}
