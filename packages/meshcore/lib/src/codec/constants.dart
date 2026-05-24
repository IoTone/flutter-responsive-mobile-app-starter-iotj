// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
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
/// are read from `examples/companion_radio/MyMesh.cpp` and
/// `src/MeshCore.h` at the pinned commit.
const int kPubKeySize = 32; // PUB_KEY_SIZE
const int kPrivKeySize = 64; // PRV_KEY_SIZE
const int kSignatureSize = 64; // SIGNATURE_SIZE
const int kMaxPathSize = 64; // MAX_PATH_SIZE
const int kContactNameSize = 32;

/// Channel + cipher sizes (from `src/MeshCore.h` / `src/Mesh.h`).
///
/// `mesh::GroupChannel { uint8_t hash[PATH_HASH_SIZE];
///   uint8_t secret[PUB_KEY_SIZE]; }` — so the channel secret BUFFER is
/// [kPubKeySize] (32) bytes. The AES-128 key is the first
/// [kCipherKeySize] (16) bytes; the HMAC is keyed over all 32. The
/// companion protocol (SET_CHANNEL / CHANNEL_INFO) only conveys the
/// first [kChannelPskSize] (16) bytes — the upper 16 bytes of a
/// channel's HMAC key are NOT carried on the companion link and must be
/// confirmed against a real device (M6 interop fixture).
const int kCipherKeySize = 16; // CIPHER_KEY_SIZE  (AES-128)
const int kCipherBlockSize = 16; // CIPHER_BLOCK_SIZE
const int kCipherMacSize = 2; // CIPHER_MAC_SIZE  (truncated HMAC)
const int kChannelSecretSize = kPubKeySize; // GroupChannel.secret = 32
const int kChannelPskSize = 16; // bytes carried by SET_CHANNEL
const int kChannelNameSize = 32;

/// Channel/contact text `txt_type` values (companion protocol).
const int kTxtTypePlain = 0;

/// `TXT_TYPE_SIGNED_PLAIN` — contact message carries a 4-byte signature
/// prefix before the text.
const int kTxtTypeSignedPlain = 2;

/// `path_len` sentinel meaning the message arrived via flood routing.
const int kPathLenFlood = 0xFF;

/// Contacts are referenced in messages by a 6-byte public-key prefix
/// (`memcpy(&out_frame[i], from.id.pub_key, 6)`).
const int kPubKeyPrefixSize = 6;

/// Signature prefix carried by signed contact messages (txt_type == 2).
const int kSignaturePrefixSize = 4;

/// `CMD_SET_ADVERT_NAME` max name length.
const int kMaxAdvertName = 31;

/// `RESP_CODE_DEVICE_INFO` (0x0D) fixed string-field sizes.
const int kDeviceBuildDateSize = 12;
const int kDeviceManufacturerSize = 40;
const int kDeviceFirmwareVersionSize = 20;

/// Radio/tuning scale factor: on-wire uint32 = value × 1000.
const int kRadioScale = 1000;

/// --- Advert (`AdvertDataHelpers.h`, pinned commit). ---
/// Advert node types (low nibble of the app_data flags byte).
const int kAdvTypeNone = 0;
const int kAdvTypeChat = 1;
const int kAdvTypeRepeater = 2;
const int kAdvTypeRoom = 3;
const int kAdvTypeSensor = 4;
const int kAdvTypeMask = 0x0F;

/// Advert app_data optional-field flag masks.
const int kAdvLatLonMask = 0x10;
const int kAdvFeat1Mask = 0x20;
const int kAdvFeat2Mask = 0x40;
const int kAdvNameMask = 0x80;

/// Advert packet envelope sizes (`src/Mesh.cpp`):
/// `pub_key(32) ‖ timestamp(4 LE) ‖ signature(64) ‖ app_data`.
/// The Ed25519-signed message is `pub_key ‖ timestamp ‖ app_data`.
const int kAdvertHeaderSize = kPubKeySize + 4 + kSignatureSize; // 100

/// --- Over-the-air packet format (`docs/packet_format.md`, pinned). ---
/// Header byte 0: bits0-1 route type, bits2-5 payload type, bits6-7 ver.
const int kPktRouteTypeMask = 0x03;
const int kPktPayloadTypeMask = 0x3C; // >> 2
const int kPktPayloadTypeShift = 2;
const int kPktVersionMask = 0xC0; // >> 6

const int kRouteTransportFlood = 0x00;
const int kRouteFlood = 0x01;
const int kRouteDirect = 0x02;
const int kRouteTransportDirect = 0x03;

/// Transport codes (4 bytes) precede the path for the TRANSPORT_* routes.
const int kTransportCodesSize = 4;

const int kPayloadTypeReq = 0x00;
const int kPayloadTypeResponse = 0x01;
const int kPayloadTypeTxtMsg = 0x02;
const int kPayloadTypeAck = 0x03;
const int kPayloadTypeAdvert = 0x04;
const int kPayloadTypeGrpTxt = 0x05;
const int kPayloadTypeGrpData = 0x06;
const int kPayloadTypeAnonReq = 0x07;
const int kPayloadTypePath = 0x08;
const int kPayloadTypeTrace = 0x09;

/// Path-length byte: bits0-5 hop count, bits6-7 hash-size code.
const int kPathHopMask = 0x3F;
const int kPathHashSizeShift = 6;

/// --- Well-known PUBLIC channel (`docs/qr_codes.md`, pinned commit). ---
/// `meshcore://channel/add?name=Public&secret=8b3387e9c5cdea6ac9e5edbaa115cd72`
/// The shared secret is 16 bytes throughout the ecosystem; the firmware
/// `GroupChannel.secret` tail (bytes 16..32) is not carried — see
/// [kChannelSecretSize].
const String kPublicChannelName = 'Public';
const List<int> kPublicChannelPsk = <int>[
  0x8b, 0x33, 0x87, 0xe9, 0xc5, 0xcd, 0xea, 0x6a, //
  0xc9, 0xe5, 0xed, 0xba, 0xa1, 0x15, 0xcd, 0x72,
];

/// Command opcodes (App → Device). First byte of an outbound frame.
///
/// Values are cross-checked against `examples/companion_radio/MyMesh.cpp`
/// at the pinned commit (the markdown doc omits several commands).
/// Additional commands (text message, self-advert, radio params, …) are
/// added in their milestones from the same pinned source.
extension type const MeshcoreCommand(int code) {
  /// Must be the first frame after connect. `CMD_APP_START`.
  static const MeshcoreCommand appStart = MeshcoreCommand(0x01);

  /// `CMD_SEND_TXT_MSG` — direct/contact text message.
  static const MeshcoreCommand sendTextMessage = MeshcoreCommand(0x02);

  static const MeshcoreCommand sendChannelMessage = MeshcoreCommand(0x03);

  /// `CMD_GET_CONTACTS` — source-only (not in companion_protocol.md).
  static const MeshcoreCommand getContacts = MeshcoreCommand(0x04);

  /// `CMD_SEND_SELF_ADVERT` — emit our advert (flood or zero-hop).
  static const MeshcoreCommand sendSelfAdvert = MeshcoreCommand(0x07);

  /// `CMD_SET_ADVERT_NAME` — set our advertised node name.
  static const MeshcoreCommand setAdvertName = MeshcoreCommand(0x08);

  /// `CMD_ADD_UPDATE_CONTACT` — add/replace a contact (148-byte body).
  static const MeshcoreCommand addUpdateContact = MeshcoreCommand(0x09);

  /// `CMD_GET_DEVICE_TIME` — source-only.
  static const MeshcoreCommand getDeviceTime = MeshcoreCommand(0x05);

  /// `CMD_SET_DEVICE_TIME` — source-only.
  static const MeshcoreCommand setDeviceTime = MeshcoreCommand(0x06);

  /// `CMD_SYNC_NEXT_MESSAGE` — pull the next queued inbound message.
  static const MeshcoreCommand syncNextMessage = MeshcoreCommand(0x0A);

  /// --- Device / radio configuration (R7), `MyMesh.cpp` pinned. ---
  /// `CMD_SET_RADIO_PARAMS` — freq/bw/SF/CR.
  static const MeshcoreCommand setRadioParams = MeshcoreCommand(0x0B);

  /// `CMD_SET_RADIO_TX_POWER` — TX power (int8 dBm).
  static const MeshcoreCommand setRadioTxPower = MeshcoreCommand(0x0C);

  /// `CMD_SET_ADVERT_LATLON` — advertised location.
  static const MeshcoreCommand setAdvertLatLon = MeshcoreCommand(0x0E);

  static const MeshcoreCommand getBatteryStorage = MeshcoreCommand(0x14);

  /// `CMD_SET_TUNING_PARAMS` — rx-delay base / airtime factor.
  static const MeshcoreCommand setTuningParams = MeshcoreCommand(0x15);

  static const MeshcoreCommand deviceQuery = MeshcoreCommand(0x16);
  static const MeshcoreCommand getChannel = MeshcoreCommand(0x1F);
  static const MeshcoreCommand setChannel = MeshcoreCommand(0x20);

  /// `CMD_SET_OTHER_PARAMS` — manual-add / telemetry / loc policy.
  static const MeshcoreCommand setOtherParams = MeshcoreCommand(0x26);

  /// `CMD_GET_CUSTOM_VARS` — request the device's custom string-keyed
  /// settings map. Reply is `RESP_CODE_CUSTOM_VARS` (0x15) carrying a
  /// comma-separated `name:value,name:value,...` payload. Used to read
  /// `gps`, `gps_interval`, etc.
  static const MeshcoreCommand getCustomVars = MeshcoreCommand(0x28);

  /// `CMD_SET_CUSTOM_VAR` — write a single string-keyed setting.
  /// Body: `[name]:[value]` (ASCII, no NUL — frame length defines end).
  /// Reply: OK on success, ERR on bad arg.
  static const MeshcoreCommand setCustomVar = MeshcoreCommand(0x29);

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

  /// `RESP_CODE_CUSTOM_VARS` (21 = 0x15) — reply to CMD_GET_CUSTOM_VARS.
  /// Payload: comma-separated `name:value` pairs (ASCII, no NUL).
  static const MeshcoreResponse customVars = MeshcoreResponse(0x15);

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
