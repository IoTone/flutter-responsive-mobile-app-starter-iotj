// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:typed_data';

/// Abstract bidirectional byte transport to a Meshcore companion radio.
///
/// This package is Flutter-free: the concrete BLE implementation
/// (flutter_blue_plus + the Nordic-UART-style service, see
/// [MeshcoreBle]) lives in the app. Tests feed bytes directly.
///
/// Contract:
///  * Each element emitted by [incoming] is exactly ONE protocol frame
///    (one BLE notification = one frame; the transport is responsible for
///    not splitting or coalescing notifications).
///  * [send] transmits exactly one protocol frame (one BLE write).
///  * [connected] reflects link state; the codec/session layers react to
///    it for reconnection.
abstract interface class MeshcoreTransport {
  /// One decoded frame's raw bytes per event (response/push frames).
  Stream<Uint8List> get incoming;

  /// Link-state changes. `true` = ready to [send].
  Stream<bool> get connected;

  /// Whether the transport is currently connected.
  bool get isConnected;

  /// Send exactly one protocol frame. Throws [StateError] if not
  /// connected.
  Future<void> send(Uint8List frame);

  /// Release resources and close the link.
  Future<void> close();
}
