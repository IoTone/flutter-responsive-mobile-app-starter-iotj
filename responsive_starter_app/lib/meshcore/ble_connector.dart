// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshcore/meshcore.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_meshcore_transport.dart';
import 'paired_device_store.dart';

/// Thrown when scan/connect cannot complete.
class BleConnectException implements Exception {
  BleConnectException(this.message);
  final String message;
  @override
  String toString() => 'BleConnectException: $message';
}

/// Scans for a MeshCore companion device, connects, locates the
/// RX/TX characteristics, and returns a ready [BleMeshcoreTransport].
///
/// Device-side (flutter_blue_plus) — exercised on real hardware in M6;
/// `flutter analyze`-clean here.
abstract final class BleConnector {
  static final Guid _service = Guid(MeshcoreBle.serviceUuid);
  static final Guid _rxUuid = Guid(MeshcoreBle.rxCharacteristicUuid);
  static final Guid _txUuid = Guid(MeshcoreBle.txCharacteristicUuid);

  /// Request the runtime BLE permissions (Android 12+: scan/connect;
  /// older Android: fine location). iOS is governed by Info.plist.
  static Future<bool> ensurePermissions() async {
    final Map<Permission, PermissionStatus> r = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    // scan + connect are the ones that actually gate BLE on modern
    // Android; location is only needed pre-Android-12.
    final bool scan = r[Permission.bluetoothScan]?.isGranted ?? false;
    final bool conn = r[Permission.bluetoothConnect]?.isGranted ?? false;
    return scan && conn;
  }

  static bool _sameUuid(Guid a, Guid b) =>
      a.str.toLowerCase() == b.str.toLowerCase();

  /// Scan → connect → discover → return a transport.
  static Future<BleMeshcoreTransport> scanAndConnect({
    Duration scanTimeout = const Duration(seconds: 15),
    bool writeWithoutResponse = false,
  }) async {
    if (!await ensurePermissions()) {
      throw BleConnectException('BLE permissions denied');
    }

    // Wait for the adapter to be on.
    final BluetoothAdapterState adapter = await FlutterBluePlus.adapterState
        .firstWhere((BluetoothAdapterState s) =>
            s == BluetoothAdapterState.on ||
            s == BluetoothAdapterState.unavailable)
        .timeout(const Duration(seconds: 5),
            onTimeout: () => BluetoothAdapterState.unknown);
    if (adapter != BluetoothAdapterState.on) {
      throw BleConnectException('Bluetooth adapter not on ($adapter)');
    }

    await FlutterBluePlus.startScan(
      withServices: <Guid>[_service],
      timeout: scanTimeout,
    );
    final List<ScanResult> hits = await FlutterBluePlus.scanResults
        .firstWhere((List<ScanResult> r) => r.isNotEmpty)
        .timeout(scanTimeout, onTimeout: () => const <ScanResult>[]);
    await FlutterBluePlus.stopScan();
    if (hits.isEmpty) {
      throw BleConnectException('No MeshCore device found');
    }

    final BluetoothDevice device = hits.first.device;
    await device.connect();
    return _finish(device, writeWithoutResponse);
  }

  /// Connect directly to a previously-paired device by its BLE remote
  /// id (no scan). Used by [autoConnect] for fast startup reconnect.
  static Future<BleMeshcoreTransport> connectToRemoteId(
    String remoteId, {
    Duration timeout = const Duration(seconds: 12),
    bool writeWithoutResponse = false,
  }) async {
    if (!await ensurePermissions()) {
      throw BleConnectException('BLE permissions denied');
    }
    final BluetoothDevice device = BluetoothDevice.fromId(remoteId);
    await device.connect(timeout: timeout);
    return _finish(device, writeWithoutResponse);
  }

  /// R41 — start a BLE scan and stream the full list of MeshCore
  /// devices currently visible. The UI uses this to populate a
  /// "Choose device" picker; rather than [scanAndConnect]'s
  /// `hits.first` shortcut, the user explicitly taps the device they
  /// want. Caller is responsible for calling [stopScan] when the
  /// picker closes (or letting the [timeout] elapse).
  ///
  /// Each event from the stream is the **complete current set** of
  /// hits seen so far in this scan; new devices appearing later
  /// produce an updated list including the prior entries. RSSI in
  /// each [ScanResult] updates between snapshots.
  static Stream<List<ScanResult>> scanForDevices({
    Duration timeout = const Duration(seconds: 12),
  }) async* {
    if (!await ensurePermissions()) {
      throw BleConnectException('BLE permissions denied');
    }
    final BluetoothAdapterState adapter = await FlutterBluePlus.adapterState
        .firstWhere((BluetoothAdapterState s) =>
            s == BluetoothAdapterState.on ||
            s == BluetoothAdapterState.unavailable)
        .timeout(const Duration(seconds: 5),
            onTimeout: () => BluetoothAdapterState.unknown);
    if (adapter != BluetoothAdapterState.on) {
      throw BleConnectException('Bluetooth adapter not on ($adapter)');
    }
    await FlutterBluePlus.startScan(
      withServices: <Guid>[_service],
      timeout: timeout,
    );
    yield* FlutterBluePlus.scanResults;
  }

  /// Stop an in-flight scan, if any. Idempotent — safe to call when
  /// no scan is running.
  static Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {/* already stopped or unsupported */}
  }

  /// Startup path: reconnect to the saved paired device if there is
  /// one; otherwise fall back to a scan. Always the default transport
  /// factory so the M7 reconnect policy keeps working too.
  static Future<BleMeshcoreTransport> autoConnect({
    bool writeWithoutResponse = false,
  }) async {
    final PairedDevice? paired = await PairedDeviceStore.read();
    if (paired != null) {
      try {
        return await connectToRemoteId(paired.remoteId,
            writeWithoutResponse: writeWithoutResponse);
      } catch (_) {
        // Saved device unreachable — fall back to scanning.
      }
    }
    return scanAndConnect(writeWithoutResponse: writeWithoutResponse);
  }

  /// Discover services/characteristics, enable notifications, persist
  /// the device as paired, and wrap it as a transport.
  static Future<BleMeshcoreTransport> _finish(
      BluetoothDevice device, bool writeWithoutResponse) async {
    try {
      final List<BluetoothService> services = await device.discoverServices();
      final BluetoothService svc = services.firstWhere(
        (BluetoothService s) => _sameUuid(s.uuid, _service),
        orElse: () =>
            throw BleConnectException('MeshCore service not present'),
      );
      final BluetoothCharacteristic rx = svc.characteristics.firstWhere(
        (BluetoothCharacteristic c) => _sameUuid(c.uuid, _rxUuid),
        orElse: () => throw BleConnectException('RX characteristic missing'),
      );
      final BluetoothCharacteristic tx = svc.characteristics.firstWhere(
        (BluetoothCharacteristic c) => _sameUuid(c.uuid, _txUuid),
        orElse: () => throw BleConnectException('TX characteristic missing'),
      );
      await tx.setNotifyValue(true);
      final String name = device.platformName.isNotEmpty
          ? device.platformName
          : (device.advName.isNotEmpty
              ? device.advName
              : device.remoteId.str);
      await PairedDeviceStore.save(device.remoteId.str, name);
      return BleMeshcoreTransport(
        device: device,
        rx: rx,
        tx: tx,
        writeWithoutResponse: writeWithoutResponse,
      );
    } catch (_) {
      await device.disconnect();
      rethrow;
    }
  }
}
