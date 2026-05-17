import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshcore/meshcore.dart';

/// [MeshcoreTransport] over BLE using the MeshCore companion service
/// (Nordic-UART-style): write command frames to the RX characteristic,
/// receive response/push frames as TX notifications. Per the pinned
/// protocol, **one notification / one write == exactly one frame**, so
/// no reassembly is needed at this layer.
///
/// Construction is separated from connection orchestration (see
/// [BleConnector]) so this class stays a thin, device-validated
/// adapter; the testable logic lives in [MeshcoreConnection].
class BleMeshcoreTransport implements MeshcoreTransport {
  BleMeshcoreTransport({
    required BluetoothDevice device,
    required BluetoothCharacteristic rx,
    required BluetoothCharacteristic tx,
    bool writeWithoutResponse = false,
  })  : _device = device,
        _rx = rx,
        _tx = tx,
        _writeWithoutResponse = writeWithoutResponse {
    _incomingSub = _tx.onValueReceived.listen((List<int> v) {
      if (!_incoming.isClosed) {
        _incoming.add(Uint8List.fromList(v));
      }
    });
    _connSub = _device.connectionState.listen((BluetoothConnectionState s) {
      _isConnected = s == BluetoothConnectionState.connected;
      if (!_connected.isClosed) _connected.add(_isConnected);
    });
  }

  final BluetoothDevice _device;
  final BluetoothCharacteristic _rx;
  final BluetoothCharacteristic _tx;
  final bool _writeWithoutResponse;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<bool> _connected =
      StreamController<bool>.broadcast();

  StreamSubscription<List<int>>? _incomingSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _isConnected = true;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<bool> get connected => _connected.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> send(Uint8List frame) {
    if (!_isConnected) {
      throw StateError('BLE link not connected');
    }
    return _rx.write(frame, withoutResponse: _writeWithoutResponse);
  }

  @override
  Future<void> close() async {
    await _incomingSub?.cancel();
    await _connSub?.cancel();
    _isConnected = false;
    try {
      await _device.disconnect();
    } catch (_) {
      // Best-effort.
    }
    await _incoming.close();
    await _connected.close();
  }
}
