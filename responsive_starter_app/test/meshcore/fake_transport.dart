import 'dart:async';
import 'dart:convert';
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

/// Legacy `CHANNEL_MSG_RECV` (0x08):
/// `[08][ch_idx][path_len][txt_type][ts u32 LE][text…]`.
Uint8List channelMsgFrame({
  int idx = 0,
  String text = 'hi',
  int pathLen = 0x03,
}) =>
    Uint8List.fromList(<int>[
      0x08, idx, pathLen, 0x00, 0x00, 0x00, 0x00, 0x00,
      ...utf8.encode(text),
    ]);

/// `CHANNEL_INFO` (0x12): `[12][ch_idx][name 32B NUL-pad][secret 16B]`.
Uint8List channelInfoFrame({required int idx, required String name}) {
  final List<int> nameBytes = List<int>.filled(32, 0);
  final List<int> n = utf8.encode(name);
  nameBytes.setRange(0, n.length, n);
  return Uint8List.fromList(<int>[
    0x12, idx, ...nameBytes, ...List<int>.filled(16, 0),
  ]);
}
