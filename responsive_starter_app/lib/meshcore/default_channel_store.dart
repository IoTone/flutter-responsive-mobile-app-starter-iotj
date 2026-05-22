// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:shared_preferences/shared_preferences.dart';

/// User-preferred default channel slot to land on at app launch
/// (R33). Persisted via `shared_preferences` and applied by
/// `MeshcoreController` once the device reaches `ready`.
///
/// `null` = no preference (fall through to whatever the device
/// reports as its persisted active slot).
abstract final class DefaultChannelStore {
  static const String _kKey = 'mm.defaultChannel';

  /// Returns the saved default slot index, or `null` if unset.
  static Future<int?> read() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getInt(_kKey);
  }

  /// Persist a default slot index. Pass `null` to clear.
  static Future<void> write(int? idx) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    if (idx == null) {
      await p.remove(_kKey);
    } else {
      await p.setInt(_kKey, idx);
    }
  }
}
