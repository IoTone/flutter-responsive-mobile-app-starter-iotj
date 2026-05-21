// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Package-wide test bootstrap (Flutter auto-loads this file).
///
/// `MeshcoreController` (constructed by most tests) restores chat
/// history via `shared_preferences` on construction. Without a mock
/// the platform channel never answers and the test hangs 10 min —
/// so install an empty mock for every test by default. Individual
/// tests may still call `SharedPreferences.setMockInitialValues(...)`
/// to seed specific values.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Reset BEFORE EVERY test (not once) so messages a test persists
  // don't leak into the next via the shared mock store. Tests that
  // need seeded values call setMockInitialValues again afterwards.
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  await testMain();
}
