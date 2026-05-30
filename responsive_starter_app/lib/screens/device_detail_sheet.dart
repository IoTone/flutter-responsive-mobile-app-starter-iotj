// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../scanner/scanned_device.dart';
import '../scanner/scanner_controller.dart';

/// Detail sheet for a scanned BLE device. Live-updates from the
/// controller so RSSI tracks while the sheet is open. Connection
/// management + vendor lookup are layered on in a later phase.
class DeviceDetailSheet extends StatelessWidget {
  const DeviceDetailSheet({super.key, required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final ScannerController sc = context.watch<ScannerController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ScannedDevice? d = sc.deviceById(deviceId);

    if (d == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.devicesEmpty,
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(d.isNamed ? d.name : l.deviceUnnamed,
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _kv(l.deviceDetailId, d.id, cs),
            _kv(l.deviceDetailSignal, l.rssiDbm(d.rssi), cs),
            if (d.companyId != null)
              _kv(l.deviceDetailVendor,
                  '0x${d.companyId!.toRadixString(16).padLeft(4, '0')}', cs),
            if (d.serviceUuids.isNotEmpty)
              _kv(l.deviceDetailServices, d.serviceUuids.join(', '), cs),
            _kv(l.deviceDetailFirstSeen, _hms(d.firstSeen), cs),
            _kv(l.deviceDetailLastSeen, _hms(d.lastSeen), cs),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
                width: 96,
                child: Text(k,
                    style: TextStyle(color: cs.onSurfaceVariant))),
            Expanded(
              child: Text(v,
                  style: TextStyle(
                      color: cs.onSurface, fontFamily: 'monospace')),
            ),
          ],
        ),
      );

  static String _hms(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}
