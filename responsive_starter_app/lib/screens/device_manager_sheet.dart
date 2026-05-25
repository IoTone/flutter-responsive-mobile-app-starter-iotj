// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/ble_connector.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';

/// R41 — Device management sheet. Single place to:
///   - see what we're currently paired to and the live connection state,
///   - disconnect or reconnect,
///   - forget the paired device,
///   - scan for nearby MeshCore devices and pick a different one (when
///     two T1000-Es are in range, this is how you choose).
///
/// Lives in a modal bottom sheet rather than a full screen so it can be
/// summoned from the dashboard's "DEVICE" chip with one tap and
/// dismissed by swiping down — no nested-route boilerplate.
class DeviceManagerSheet extends StatefulWidget {
  const DeviceManagerSheet({super.key});

  /// Convenience opener so callers don't have to remember the modal
  /// presentation flags.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext _) => const DeviceManagerSheet(),
    );
  }

  @override
  State<DeviceManagerSheet> createState() => _DeviceManagerSheetState();
}

class _DeviceManagerSheetState extends State<DeviceManagerSheet> {
  /// Live snapshot of devices found in the current scan. Keyed by
  /// remote ID so a device whose RSSI updates doesn't appear twice.
  final Map<String, ScanResult> _hits = <String, ScanResult>{};

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  String? _scanError;

  @override
  void dispose() {
    _scanSub?.cancel();
    BleConnector.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _scanError = null;
      _hits.clear();
    });
    try {
      _scanSub = BleConnector.scanForDevices(
        timeout: const Duration(seconds: 12),
      ).listen(
        (List<ScanResult> snapshot) {
          if (!mounted) return;
          // Merge into the keyed map so we don't lose earlier hits
          // when a snapshot omits a device that's now out of range
          // for a single sweep. Each device is upserted by remote id.
          for (final ScanResult r in snapshot) {
            _hits[r.device.remoteId.str] = r;
          }
          setState(() {});
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() {
            _scanError = '$e';
            _scanning = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _scanning = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanError = '$e';
        _scanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    await BleConnector.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _pickDevice(
      MeshcoreController mc, ScanResult r) async {
    await _stopScan();
    final String name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : (r.device.advName.isNotEmpty
            ? r.device.advName
            : r.device.remoteId.str);
    if (!mounted) return;
    Navigator.of(context).pop();
    await mc.connectToPickedDevice(
        remoteId: r.device.remoteId.str, name: name);
  }

  Future<void> _disconnect(MeshcoreController mc) async {
    await mc.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _forget(MeshcoreController mc) async {
    await mc.forgetDevice();
    if (mounted) Navigator.of(context).pop();
  }

  String _stateLabel(MeshcoreController mc, AppLocalizations l) {
    if (mc.isConnecting) return l.deviceMgrStateConnecting;
    return switch (mc.state) {
      MeshcoreConnectionState.ready => l.deviceMgrStateConnected,
      MeshcoreConnectionState.handshaking => l.deviceMgrStateConnecting,
      MeshcoreConnectionState.reconnecting =>
        l.deviceMgrStateReconnecting,
      MeshcoreConnectionState.failed => l.deviceMgrStateFailed,
      MeshcoreConnectionState.disconnected =>
        l.deviceMgrStateDisconnected,
    };
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isLive = mc.state == MeshcoreConnectionState.ready ||
        mc.state == MeshcoreConnectionState.handshaking;
    final bool isPaired = mc.hasPairedDevice;

    final List<ScanResult> sortedHits = _hits.values.toList()
      ..sort((ScanResult a, ScanResult b) =>
          b.rssi.compareTo(a.rssi));

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header.
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l.deviceMgrTitle,
                  style: TextStyle(
                      color: cs.primary,
                      fontSize: 12,
                      letterSpacing: 3)),
            ),
            // Current state line.
            _StatusRow(
              name: mc.pairedName ?? l.deviceMgrNoPair,
              state: _stateLabel(mc, l),
              alert: mc.state == MeshcoreConnectionState.failed,
              live: isLive,
            ),
            const SizedBox(height: 12),
            // Primary actions row.
            Row(
              children: <Widget>[
                if (isLive)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.link_off, size: 18),
                      label: Text(l.deviceMgrDisconnect),
                      onPressed: () => _disconnect(mc),
                    ),
                  )
                else if (isPaired)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.link, size: 18),
                      label: Text(l.deviceMgrReconnect),
                      onPressed: mc.isConnecting
                          ? null
                          : () => mc.connect(),
                    ),
                  ),
                if (isPaired) const SizedBox(width: 8),
                if (isPaired)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l.deviceMgrForget),
                    onPressed: () => _forget(mc),
                  ),
              ],
            ),
            const Divider(height: 28),
            // Scan section.
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(l.deviceMgrPick,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          letterSpacing: 2)),
                ),
                if (_scanning)
                  TextButton.icon(
                    icon: const Icon(Icons.stop_circle_outlined,
                        size: 16),
                    label: Text(l.deviceMgrStopScan),
                    onPressed: _stopScan,
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.search, size: 16),
                    label: Text(l.deviceMgrScan),
                    onPressed: _startScan,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_scanError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.deviceMgrScanFailed('$_scanError'),
                  style: TextStyle(
                      color: cs.error, fontSize: 12),
                ),
              ),
            if (sortedHits.isEmpty && !_scanning && _scanError == null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
                child: Text(l.deviceMgrScanHint,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 12)),
              ),
            if (sortedHits.isEmpty && _scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            // Hit list — capped to ~6 rows of fixed scroll so the
            // sheet doesn't grow past the screen on a noisy scan.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sortedHits.length,
                itemBuilder: (BuildContext _, int i) {
                  final ScanResult r = sortedHits[i];
                  final String name = r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : (r.device.advName.isNotEmpty
                          ? r.device.advName
                          : r.device.remoteId.str);
                  // Highlight the currently-paired device, if any.
                  final bool isCurrent =
                      mc.pairedName == name; // best-effort match
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isCurrent
                          ? Icons.check_circle
                          : Icons.bluetooth,
                      color: isCurrent
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    title: Text(name),
                    subtitle: Text(
                      '${r.device.remoteId.str}  ·  '
                      'RSSI ${r.rssi}',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontFamily: 'monospace',
                          fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickDevice(mc, r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.name,
    required this.state,
    required this.alert,
    required this.live,
  });
  final String name;
  final String state;
  final bool alert;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color accent = alert
        ? cs.error
        : live
            ? cs.primary
            : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: .5)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
              live
                  ? Icons.bluetooth_connected
                  : alert
                      ? Icons.error_outline
                      : Icons.bluetooth_disabled,
              color: accent,
              size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(name,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(state,
                    style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        letterSpacing: 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
