// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/widgets.dart';

import '../../theme/mm_skin.dart';
import '../../theme/mm_tokens.dart';
import '../dashboard_screen.dart';
import 'nerv_dashboard.dart';

/// R8 dashboard host — selects the **per-skin dashboard layout**. Most
/// skins use the SEELE monolith ([DashboardScreen]); NERV gets its own
/// telemetry-grid re-imagining. This is the per-screen override
/// mechanism: a skin opts into a distinct layout, others inherit the
/// default — so reskinning a screen is additive, never all-or-nothing.
class DashboardHost extends StatelessWidget {
  const DashboardHost({super.key});

  @override
  Widget build(BuildContext context) {
    return switch (context.skin.preset) {
      MmThemePreset.nerv => const NervDashboard(),
      _ => const DashboardScreen(),
    };
  }
}
