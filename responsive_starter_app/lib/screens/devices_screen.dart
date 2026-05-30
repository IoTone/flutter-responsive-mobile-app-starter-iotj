// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../scanner/scanned_access_point.dart';
import '../scanner/scanned_device.dart';
import '../scanner/scanner_controller.dart';
import '../scanner/signal_distance.dart';
import 'device_detail_sheet.dart';
import 'scan_controls.dart';

/// Unified list of discovered devices: BLE first, then WiFi APs.
class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScannerController sc = context.watch<ScannerController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<ScannedDevice> ble = sc.devices;
    final List<ScannedAccessPoint> wifi = sc.accessPoints;

    if (ble.isEmpty && wifi.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l.devicesEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ScanControls.toggle(context),
                icon: Icon(sc.isScanning ? Icons.stop : Icons.play_arrow),
                label: Text(sc.isScanning ? l.scanStop : l.scanStart),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: <Widget>[
        if (ble.isNotEmpty) _SectionHeader(l.devicesSectionBle, cs: cs),
        for (final ScannedDevice d in ble)
          _BleRow(device: d, cs: cs, l: l),
        if (wifi.isNotEmpty) _SectionHeader(l.devicesSectionWifi, cs: cs),
        for (final ScannedAccessPoint ap in wifi)
          _WifiRow(ap: ap, cs: cs, l: l),
      ],
    );
  }
}

Color signalColor(int rssi, ColorScheme cs) => switch (SignalDistance.band(rssi)) {
      SignalBand.strong => cs.tertiary,
      SignalBand.medium => cs.secondary,
      SignalBand.weak => cs.onSurfaceVariant,
    };

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {required this.cs});
  final String text;
  final ColorScheme cs;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(text,
            style: TextStyle(
                color: cs.primary, fontSize: 12, letterSpacing: 3)),
      );
}

class _BleRow extends StatelessWidget {
  const _BleRow({required this.device, required this.cs, required this.l});
  final ScannedDevice device;
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.bluetooth, color: signalColor(device.rssi, cs)),
      title: Text(device.isNamed ? device.name : l.deviceUnnamed),
      subtitle: Text(device.id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
      trailing: Text(l.rssiDbm(device.rssi),
          style: TextStyle(color: signalColor(device.rssi, cs))),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => DeviceDetailSheet(deviceId: device.id),
      ),
    );
  }
}

class _WifiRow extends StatelessWidget {
  const _WifiRow({required this.ap, required this.cs, required this.l});
  final ScannedAccessPoint ap;
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final int? ch = ap.channel;
    final String meta =
        <String>[ap.band, if (ch != null) l.wifiChannel(ch)]
            .where((String s) => s.isNotEmpty)
            .join(' · ');
    return ListTile(
      leading: Icon(ap.isCurrentConnection ? Icons.wifi : Icons.wifi_find,
          color: signalColor(ap.rssi, cs)),
      title: Text(ap.displayName),
      subtitle: Text(
        <String>[ap.bssid, if (meta.isNotEmpty) meta].join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
      trailing: Text(l.rssiDbm(ap.rssi),
          style: TextStyle(color: signalColor(ap.rssi, cs))),
    );
  }
}
