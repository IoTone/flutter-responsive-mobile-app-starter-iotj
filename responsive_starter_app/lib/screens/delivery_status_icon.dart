// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../gen/app_localizations.dart';
import '../meshcore/chat_message.dart';

/// Per-message delivery glyph for outgoing chat/DM rows.
///
/// - sending   → clock (in flight to the radio)
/// - sent      → single check (accepted + transmitted into the mesh;
///               terminal for channel/broadcast)
/// - delivered → double check (DM recipient ack matched)
/// - failed    → alert (send error, or DM with no ack / no path)
class DeliveryStatusIcon extends StatelessWidget {
  const DeliveryStatusIcon(this.delivery, {super.key, this.size = 13});

  final MessageDelivery delivery;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final (IconData, Color, String) v = switch (delivery) {
      MessageDelivery.sending => (
          Icons.schedule,
          cs.onSurfaceVariant,
          l.deliverySending,
        ),
      MessageDelivery.sent => (
          Icons.check,
          cs.onSurfaceVariant,
          l.deliverySent,
        ),
      MessageDelivery.delivered => (
          Icons.done_all,
          cs.primary,
          l.deliveryDelivered,
        ),
      MessageDelivery.failed => (
          Icons.error_outline,
          cs.error,
          l.deliveryFailed,
        ),
    };
    return Tooltip(
      message: v.$3,
      child: Icon(v.$1, size: size, color: v.$2),
    );
  }
}
