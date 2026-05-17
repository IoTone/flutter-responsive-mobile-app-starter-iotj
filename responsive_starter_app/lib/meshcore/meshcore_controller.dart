import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meshcore/meshcore.dart';

import 'ble_connector.dart';
import 'meshcore_connection.dart';

/// App-facing facade over [MeshcoreConnection], exposed via Provider.
///
/// The transport is obtained through [transportFactory]; the default
/// scans/connects over BLE, but tests inject a fake transport so the
/// whole controller path is `flutter test`-covered without hardware.
class MeshcoreController extends ChangeNotifier {
  MeshcoreController({
    Future<MeshcoreTransport> Function()? transportFactory,
    MeshcoreConnection? connection,
  })  : _transportFactory =
            transportFactory ?? BleConnector.scanAndConnect,
        _connection = connection ?? MeshcoreConnection() {
    _statesSub = _connection.states.listen((MeshcoreConnectionState s) {
      _state = s;
      notifyListeners();
    });
    _inboundSub = _connection.inbound.listen((MeshcoreInbound f) {
      _lastFrame = f;
      notifyListeners();
    });
  }

  final Future<MeshcoreTransport> Function() _transportFactory;
  final MeshcoreConnection _connection;

  StreamSubscription<MeshcoreConnectionState>? _statesSub;
  StreamSubscription<MeshcoreInbound>? _inboundSub;
  MeshcoreTransport? _transport;

  MeshcoreConnectionState _state = MeshcoreConnectionState.disconnected;
  MeshcoreInbound? _lastFrame;
  String? _error;
  bool _connecting = false;

  MeshcoreConnectionState get state => _state;
  MeshcoreInbound? get lastFrame => _lastFrame;
  SelfInfo? get selfInfo => _connection.selfInfo;
  String? get error => _error;
  bool get isConnecting => _connecting;
  bool get isReady => _state == MeshcoreConnectionState.ready;

  /// Acquire a transport and start the handshake. Safe to call again
  /// after a failure.
  Future<void> connect() async {
    if (_connecting) return;
    _connecting = true;
    _error = null;
    notifyListeners();
    try {
      await _transport?.close();
      final MeshcoreTransport t = await _transportFactory();
      _transport = t;
      _connection.attach(t);
    } catch (e) {
      _error = e.toString();
      _state = MeshcoreConnectionState.failed;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  /// Send a raw command frame (e.g. from [MeshcoreFrameCodec]).
  Future<void> send(Uint8List frame) => _connection.sendCommand(frame);

  Future<void> disconnect() async {
    await _transport?.close();
    _transport = null;
  }

  @override
  void dispose() {
    _statesSub?.cancel();
    _inboundSub?.cancel();
    unawaited(_transport?.close());
    unawaited(_connection.dispose());
    super.dispose();
  }
}
