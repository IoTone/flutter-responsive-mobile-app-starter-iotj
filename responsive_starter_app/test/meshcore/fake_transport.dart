import 'dart:async';
import 'dart:typed_data';

import 'package:meshcore/meshcore.dart';

/// Programmable in-memory [MeshcoreTransport] for hardware-free tests.
class FakeMeshcoreTransport implements MeshcoreTransport {
  FakeMeshcoreTransport({bool connected = false}) : _isConnected = connected;

  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<bool> _connected =
      StreamController<bool>.broadcast();

  /// Every frame passed to [send], in order.
  final List<Uint8List> sent = <Uint8List>[];

  bool _isConnected;
  bool failSend = false;
  bool closed = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  Stream<bool> get connected => _connected.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> send(Uint8List frame) async {
    if (!_isConnected) throw StateError('not connected');
    if (failSend) throw StateError('send failed (test)');
    sent.add(Uint8List.fromList(frame));
  }

  @override
  Future<void> close() async {
    closed = true;
    _isConnected = false;
    await _incoming.close();
    await _connected.close();
  }

  // --- test controls ---

  void emit(Uint8List frame) => _incoming.add(frame);

  void setConnected(bool value) {
    _isConnected = value;
    _connected.add(value);
  }
}

/// Minimal valid SELF_INFO (0x05) frame: opcode + 57 fixed bytes,
/// empty trailing name. Decodes to a `SelfInfoFrame`.
Uint8List selfInfoFrame() => Uint8List(58)..[0] = 0x05;

/// CURR_TIME (0x09) frame for unix = 1700000000 (0x6553F100 LE).
Uint8List currentTimeFrame() =>
    Uint8List.fromList(<int>[0x09, 0x00, 0xF1, 0x53, 0x65]);
