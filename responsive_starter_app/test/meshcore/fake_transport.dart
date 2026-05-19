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

/// A `RESP_CODE_CONTACT` (0x03), built via the encode→swap-opcode
/// trick (same approach as nodes_screen_test).
Uint8List contactFrame({
  required String name,
  int firstPubByte = 70,
  int lastAdvertTs = 1700000000,
}) {
  final Contact c = Contact(
    publicKey: Uint8List.fromList(
        List<int>.generate(32, (int i) => (firstPubByte + i) & 0xFF)),
    type: 1,
    flags: 0,
    outPathLen: 0,
    outPath: Uint8List(64),
    name: name,
    lastAdvertTimestamp: lastAdvertTs,
    latitudeMicros: 0,
    longitudeMicros: 0,
    lastMod: 1,
  );
  final Uint8List cf = MeshcoreFrameCodec.addUpdateContact(c);
  cf[0] = 0x03;
  return cf;
}

/// `RESP_CODE_ERR` (0x01) with a 1-byte reason code.
Uint8List errorFrame(int code) => Uint8List.fromList(<int>[0x01, code]);

/// `RESP_CODE_CURR_TIME` (0x09) for an arbitrary unix time (u32 LE).
Uint8List currentTimeFrameAt(int unix) => Uint8List.fromList(<int>[
      0x09,
      unix & 0xFF,
      (unix >> 8) & 0xFF,
      (unix >> 16) & 0xFF,
      (unix >> 24) & 0xFF,
    ]);

/// `PUSH_CODE_MSGS_WAITING` (0x83) [+ optional count byte].
Uint8List msgsWaitingFrame({int? count}) => Uint8List.fromList(
    <int>[0x83, if (count != null) count]);

/// `RESP_CODE_NO_MORE_MESSAGES` (0x0A).
Uint8List noMoreMessagesFrame() => Uint8List.fromList(<int>[0x0A]);

/// `CHANNEL_INFO` (0x12): `[12][ch_idx][name 32B NUL-pad][secret 16B]`.
Uint8List channelInfoFrame({required int idx, required String name}) {
  final List<int> nameBytes = List<int>.filled(32, 0);
  final List<int> n = utf8.encode(name);
  nameBytes.setRange(0, n.length, n);
  return Uint8List.fromList(<int>[
    0x12, idx, ...nameBytes, ...List<int>.filled(16, 0),
  ]);
}

/// `PUSH_CODE_ADVERTISEMENT` (0x80):
/// `[80][pubkey 32][ts u32 LE][sig 64][app_data: flags | name…]`.
/// [ts] defaults to an ancient value to prove "in range" is judged
/// by local receive time, not the advert's sender clock.
Uint8List advertFrame({
  String name = 'NodeX',
  int firstPubByte = 9,
  int ts = 1,
}) =>
    Uint8List.fromList(<int>[
      0x80,
      ...List<int>.generate(32, (int i) => firstPubByte + i),
      ts & 0xFF, (ts >> 8) & 0xFF, (ts >> 16) & 0xFF, (ts >> 24) & 0xFF,
      ...List<int>.filled(64, 0x55),
      kAdvTypeChat | kAdvNameMask,
      ...utf8.encode(name),
    ]);
