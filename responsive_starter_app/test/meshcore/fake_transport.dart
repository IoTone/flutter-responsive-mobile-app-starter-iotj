// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meshcore/meshcore.dart';
import 'package:meshmore_sns_app/meshcore/background_keepalive.dart';

/// Records start/stop without touching the platform plugin.
class FakeBackgroundKeepalive implements BackgroundKeepalive {
  int starts = 0;
  int stops = 0;
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<bool> get isRunning async => starts > stops;
}

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

/// SELF_INFO (0x05) frame carrying a non-zero device location.
/// `lat` / `lon` are in degrees; we encode them as i32 micros LE
/// at the same byte offsets the firmware uses (lat = bytes 36..39,
/// lon = bytes 40..43; layout from `_decodeSelfInfo`).
Uint8List selfInfoFrameAt({required double lat, required double lon}) {
  final Uint8List f = Uint8List(58)..[0] = 0x05;
  final int latMicros = (lat * 1e6).round();
  final int lonMicros = (lon * 1e6).round();
  final ByteData bd = ByteData.view(f.buffer);
  bd.setInt32(36, latMicros, Endian.little);
  bd.setInt32(40, lonMicros, Endian.little);
  return f;
}

/// `RESP_CODE_CUSTOM_VARS` (0x15) frame with the given map encoded
/// as comma-separated `name:value` pairs (UTF-8).
Uint8List customVarsFrame(Map<String, String> values) {
  final String payload = values.entries
      .map((MapEntry<String, String> e) => '${e.key}:${e.value}')
      .join(',');
  final List<int> body = <int>[0x15, ...utf8.encode(payload)];
  return Uint8List.fromList(body);
}

/// CURR_TIME (0x09) frame for unix = 1700000000 (0x6553F100 LE).
Uint8List currentTimeFrame() =>
    Uint8List.fromList(<int>[0x09, 0x00, 0xF1, 0x53, 0x65]);

/// Legacy `CONTACT_MSG_RECV` (0x07 — DM):
/// `[07][pubkey_prefix 6][path_len][txt_type][ts u32 LE][text…]`.
Uint8List contactMessageFrame({
  required List<int> prefix,
  String text = 'hi',
  int pathLen = 0,
}) {
  assert(prefix.length == 6, 'DM prefix is exactly 6 bytes');
  return Uint8List.fromList(<int>[
    0x07,
    ...prefix,
    pathLen,
    0x00, // txt_type plain
    0x00, 0x00, 0x00, 0x00, // ts u32 LE
    ...utf8.encode(text),
  ]);
}

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
  int flags = 0,
}) {
  final Contact c = Contact(
    publicKey: Uint8List.fromList(
        List<int>.generate(32, (int i) => (firstPubByte + i) & 0xFF)),
    type: 1,
    flags: flags,
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

/// `RESP_CODE_DEVICE_INFO` (0x0D):
/// `[0D][fw_ver][max_contacts/2][max_grp_ch][ble_pin u32 LE]
///  [build 12][mfr 40][fw_ver_str 20][client_repeat][path_hash_mode]`.
Uint8List deviceInfoFrame({
  int fwVer = 9,
  int maxContactsHalf = 50,
  int maxChannels = 8,
  int blePin = 123456,
  String build = '2026-05-01',
  String mfr = 'Seeed',
  String fw = 'v1.15.0',
}) {
  List<int> cstr(String s, int n) {
    final List<int> b = List<int>.filled(n, 0);
    final List<int> e = utf8.encode(s);
    b.setRange(0, e.length > n ? n : e.length, e);
    return b;
  }

  return Uint8List.fromList(<int>[
    0x0D,
    fwVer,
    maxContactsHalf,
    maxChannels,
    blePin & 0xFF, (blePin >> 8) & 0xFF,
    (blePin >> 16) & 0xFF, (blePin >> 24) & 0xFF,
    ...cstr(build, 12),
    ...cstr(mfr, 40),
    ...cstr(fw, 20),
    0, // client_repeat
    0, // path_hash_mode
  ]);
}

/// `RESP_CODE_BATT_AND_STORAGE` (0x0C):
/// `[0C][batt_mv u16 LE][used_kb u32 LE][total_kb u32 LE]`.
Uint8List batteryFrame(int mv, {int usedKb = 0, int totalKb = 0}) =>
    Uint8List.fromList(<int>[
      0x0C,
      mv & 0xFF, (mv >> 8) & 0xFF,
      usedKb & 0xFF, (usedKb >> 8) & 0xFF,
      (usedKb >> 16) & 0xFF, (usedKb >> 24) & 0xFF,
      totalKb & 0xFF, (totalKb >> 8) & 0xFF,
      (totalKb >> 16) & 0xFF, (totalKb >> 24) & 0xFF,
    ]);

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
