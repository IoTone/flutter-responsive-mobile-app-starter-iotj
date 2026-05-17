// Meshcore companion-radio protocol constants.
//
// SOURCE OF TRUTH — transcribed from the MeshCore firmware repository,
// pinned to:
//
//   tag    : companion-v1.15.0
//   commit : dee3e26ac081a5c668c69b66c16a6544a44ddc5b
//   file   : docs/companion_protocol.md
//   url    : https://github.com/meshcore-dev/MeshCore/blob/
//            dee3e26ac081a5c668c69b66c16a6544a44ddc5b/docs/companion_protocol.md
//
// This M0 file seeds the framing parameters, BLE UUIDs, and the core
// opcode set. The remaining opcodes/field layouts are transcribed
// per-milestone (M1–M4) against this SAME pinned commit. When the pin is
// bumped, update the header above and re-verify every value below.
//
// DO NOT change a numeric value here without re-reading the pinned doc.

/// Pinned firmware reference. Bump deliberately, never silently.
const String kMeshcoreFirmwarePinTag = 'companion-v1.15.0';
const String kMeshcoreFirmwarePinCommit =
    'dee3e26ac081a5c668c69b66c16a6544a44ddc5b';

/// BLE transport (Nordic-UART-style service used by the companion link).
///
/// Framing rule: each characteristic write / notification is exactly ONE
/// protocol frame. There is no length prefix; frame boundaries are the
/// BLE MTU boundaries. Multi-byte integers are little-endian; strings are
/// UTF-8. (CayenneLPP payloads, where present, are big-endian.)
abstract final class MeshcoreBle {
  static const String serviceUuid =
      '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

  /// App → Device (the app WRITEs command frames here).
  static const String rxCharacteristicUuid =
      '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

  /// Device → App (the app SUBSCRIBES for response/push notifications).
  static const String txCharacteristicUuid =
      '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
}

/// Common protocol field sizes (from firmware, pinned commit).
///
/// `PUB_KEY_SIZE`, `MAX_PATH_SIZE`, and the 32-byte contact name field
/// are read from `examples/companion_radio/MyMesh.cpp` at the pinned
/// commit (RESP_CODE_CONTACT serialization).
const int kPubKeySize = 32;
const int kMaxPathSize = 64;
const int kContactNameSize = 32;

/// Command opcodes (App → Device). First byte of an outbound frame.
///
/// Values are cross-checked against `examples/companion_radio/MyMesh.cpp`
/// at the pinned commit (the markdown doc omits several commands).
/// Additional commands (text message, self-advert, radio params, …) are
/// added in their milestones from the same pinned source.
extension type const MeshcoreCommand(int code) {
  /// Must be the first frame after connect. `CMD_APP_START`.
  static const MeshcoreCommand appStart = MeshcoreCommand(0x01);
  static const MeshcoreCommand sendChannelMessage = MeshcoreCommand(0x03);

  /// `CMD_GET_CONTACTS` — source-only (not in companion_protocol.md).
  static const MeshcoreCommand getContacts = MeshcoreCommand(0x04);

  /// `CMD_GET_DEVICE_TIME` — source-only.
  static const MeshcoreCommand getDeviceTime = MeshcoreCommand(0x05);

  /// `CMD_SET_DEVICE_TIME` — source-only.
  static const MeshcoreCommand setDeviceTime = MeshcoreCommand(0x06);

  /// `CMD_SYNC_NEXT_MESSAGE` — pull the next queued inbound message.
  static const MeshcoreCommand syncNextMessage = MeshcoreCommand(0x0A);

  static const MeshcoreCommand getBatteryStorage = MeshcoreCommand(0x14);
  static const MeshcoreCommand deviceQuery = MeshcoreCommand(0x16);
  static const MeshcoreCommand getChannel = MeshcoreCommand(0x1F);
  static const MeshcoreCommand setChannel = MeshcoreCommand(0x20);
  static const MeshcoreCommand sendChannelDatagram = MeshcoreCommand(0x3E);
}

/// Response / push opcodes (Device → App). First byte of an inbound frame.
///
/// Opcodes >= 0x80 are asynchronous push notifications (not direct
/// replies to a command).
extension type const MeshcoreResponse(int code) {
  static const MeshcoreResponse ok = MeshcoreResponse(0x00);
  static const MeshcoreResponse error = MeshcoreResponse(0x01);
  static const MeshcoreResponse contactStart = MeshcoreResponse(0x02);
  static const MeshcoreResponse contact = MeshcoreResponse(0x03);
  static const MeshcoreResponse contactEnd = MeshcoreResponse(0x04);
  static const MeshcoreResponse selfInfo = MeshcoreResponse(0x05);
  static const MeshcoreResponse msgSent = MeshcoreResponse(0x06);
  static const MeshcoreResponse contactMsgRecv = MeshcoreResponse(0x07);
  static const MeshcoreResponse channelMsgRecv = MeshcoreResponse(0x08);
  static const MeshcoreResponse currentTime = MeshcoreResponse(0x09);
  static const MeshcoreResponse noMoreMsgs = MeshcoreResponse(0x0A);
  static const MeshcoreResponse battery = MeshcoreResponse(0x0C);
  static const MeshcoreResponse deviceInfo = MeshcoreResponse(0x0D);
  static const MeshcoreResponse contactMsgRecvV3 = MeshcoreResponse(0x10);
  static const MeshcoreResponse channelMsgRecvV3 = MeshcoreResponse(0x11);
  static const MeshcoreResponse channelInfo = MeshcoreResponse(0x12);

  /// --- Asynchronous push codes (>= 0x80) ---
  static const MeshcoreResponse advertisement = MeshcoreResponse(0x80);
  static const MeshcoreResponse ack = MeshcoreResponse(0x82);
  static const MeshcoreResponse messagesWaiting = MeshcoreResponse(0x83);

  /// RF log data — safely ignorable by the codec.
  static const MeshcoreResponse logData = MeshcoreResponse(0x88);

  bool get isPush => code >= 0x80;
}

/// SNR byte → dB conversion used by the V3 receive frames.
///
/// `snrDb = (signed8(value)) / 4.0`
double snrByteToDb(int rawByte) {
  assert(rawByte >= 0 && rawByte <= 0xFF, 'expected an unsigned byte');
  final int signed = rawByte < 128 ? rawByte : rawByte - 256;
  return signed / 4.0;
}
