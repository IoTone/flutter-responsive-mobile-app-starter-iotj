// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:typed_data';

import '../model/advert.dart';
import '../model/channel_info.dart';
import '../model/channel_message.dart';
import '../model/contact.dart';
import '../model/contact_message.dart';
import '../model/device_config.dart';
import '../model/rf_log.dart';
import '../model/self_info.dart';
import 'byte_cursor.dart';
import 'constants.dart';
import 'decode_error.dart';
import 'inbound.dart';

/// Encodes app→device command frames and decodes device→app frames.
///
/// Frame = `[opcode][payload]`, one frame per BLE write/notification,
/// little-endian. All layouts are pinned (see [kMeshcoreFirmwarePinTag]).
///
/// [decode] is **total**: it returns a [DecodeFailure] for malformed or
/// truncated input and an [UnsupportedFrame] for opcodes not handled in
/// this milestone. It never throws.
abstract final class MeshcoreFrameCodec {
  // ---------------------------------------------------------------------
  // Encoders (App → Device)
  // ---------------------------------------------------------------------

  /// `CMD_APP_START` (0x01): `01 [7 reserved] [app name UTF-8]`.
  ///
  /// Firmware requires `len >= 8` and ignores bytes 1..7. The app name
  /// is the trailing bytes (no NUL terminator; frame-length delimited).
  static Uint8List appStart({required String appName}) {
    final FrameBuilder b = FrameBuilder()
      ..u8(MeshcoreCommand.appStart.code)
      ..zeros(7)
      ..utf8String(appName);
    return b.build();
  }

  /// `CMD_GET_CONTACTS` (0x04). Optionally filters to contacts modified
  /// at/after [since] (uint32 unix seconds) for incremental sync.
  static Uint8List getContacts({int? since}) {
    final FrameBuilder b = FrameBuilder()..u8(MeshcoreCommand.getContacts.code);
    if (since != null) b.u32(since);
    return b.build();
  }

  /// `CMD_GET_DEVICE_TIME` (0x05).
  static Uint8List getDeviceTime() =>
      (FrameBuilder()..u8(MeshcoreCommand.getDeviceTime.code)).build();

  /// `CMD_SET_DEVICE_TIME` (0x06): `06 [unix uint32 LE]`.
  static Uint8List setDeviceTime(int unixSeconds) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.setDeviceTime.code)
          ..u32(unixSeconds))
        .build();
  }

  /// `CMD_SYNC_NEXT_MESSAGE` (0x0A).
  static Uint8List syncNextMessage() =>
      (FrameBuilder()..u8(MeshcoreCommand.syncNextMessage.code)).build();

  /// `CMD_SEND_CHANNEL_TXT_MSG` (0x03):
  /// `03 [txt_type] [channel_idx] [timestamp u32 LE] [text UTF-8]`.
  ///
  /// The app sends plaintext + channel index; the device performs the
  /// over-the-air channel encryption.
  static Uint8List sendChannelTextMessage({
    required int channelIdx,
    required int timestamp,
    required String text,
    int txtType = kTxtTypePlain,
  }) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.sendChannelMessage.code)
          ..u8(txtType)
          ..u8(channelIdx)
          ..u32(timestamp)
          ..utf8String(text))
        .build();
  }

  /// `CMD_SEND_TXT_MSG` (0x02):
  /// `02 [txt_type] [attempt] [timestamp u32 LE] [pubkey_prefix 6]
  /// [text UTF-8]`.
  ///
  /// The recipient is addressed by the first 6 bytes of its public key.
  static Uint8List sendTextMessage({
    required List<int> pubKeyPrefix,
    required int timestamp,
    required String text,
    int txtType = kTxtTypePlain,
    int attempt = 0,
  }) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.sendTextMessage.code)
          ..u8(txtType)
          ..u8(attempt)
          ..u32(timestamp)
          ..fixed(pubKeyPrefix, kPubKeyPrefixSize)
          ..utf8String(text))
        .build();
  }

  /// `CMD_SEND_SELF_ADVERT` (0x07): `07 [1=flood | 0=zero-hop]`.
  static Uint8List sendSelfAdvert({bool flood = true}) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.sendSelfAdvert.code)
          ..u8(flood ? 1 : 0))
        .build();
  }

  /// `CMD_SET_ADVERT_NAME` (0x08): `08 [name UTF-8, <= 31 bytes]`.
  static Uint8List setAdvertName(String name) {
    final List<int> n = utf8.encode(name);
    return (FrameBuilder()
          ..u8(MeshcoreCommand.setAdvertName.code)
          ..raw(n.length > kMaxAdvertName
              ? n.sublist(0, kMaxAdvertName)
              : n))
        .build();
  }

  /// `CMD_ADD_UPDATE_CONTACT` (0x09): the 148-byte contact body
  /// (same layout as `RESP_CODE_CONTACT`).
  static Uint8List addUpdateContact(Contact c) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.addUpdateContact.code)
          ..fixed(c.publicKey, kPubKeySize)
          ..u8(c.type)
          ..u8(c.flags)
          ..u8(c.outPathLen)
          ..fixed(c.outPath, kMaxPathSize)
          ..fixed(utf8.encode(c.name), kContactNameSize)
          ..u32(c.lastAdvertTimestamp)
          ..i32(c.latitudeMicros)
          ..i32(c.longitudeMicros)
          ..u32(c.lastMod))
        .build();
  }

  // ---------------------------------------------------------------------
  // Device / radio configuration (R7)
  // ---------------------------------------------------------------------

  /// `CMD_SET_RADIO_PARAMS` (0x0B):
  /// `0B [freq u32 LE ×1000] [bw u32 LE ×1000] [sf] [cr] [repeat?]`.
  static Uint8List setRadioParams(RadioParams p) {
    final FrameBuilder b = FrameBuilder()
      ..u8(MeshcoreCommand.setRadioParams.code)
      ..u32((p.frequencyMhz * kRadioScale).round())
      ..u32((p.bandwidthKhz * kRadioScale).round())
      ..u8(p.spreadingFactor)
      ..u8(p.codingRate);
    if (p.repeat != null) b.u8(p.repeat!);
    return b.build();
  }

  /// `CMD_SET_RADIO_TX_POWER` (0x0C): `0C [power int8 dBm]`.
  static Uint8List setRadioTxPower(int dbm) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.setRadioTxPower.code)
          ..u8(dbm & 0xFF))
        .build();
  }

  /// `CMD_SET_ADVERT_LATLON` (0x0E):
  /// `0E [lat i32 LE ×1e6] [lon i32 LE ×1e6] [alt i32 LE optional]`.
  static Uint8List setAdvertLatLon({
    required int latitudeMicros,
    required int longitudeMicros,
    int? altitudeMicros,
  }) {
    final FrameBuilder b = FrameBuilder()
      ..u8(MeshcoreCommand.setAdvertLatLon.code)
      ..i32(latitudeMicros)
      ..i32(longitudeMicros);
    if (altitudeMicros != null) b.i32(altitudeMicros);
    return b.build();
  }

  /// `CMD_SET_OTHER_PARAMS` (0x26):
  /// `26 [manual_add] [telemetry_packed] [loc_policy?] [multi_acks?]`.
  static Uint8List setOtherParams({
    required int manualAddContacts,
    required int telemetryModePacked,
    int? advertLocPolicy,
    int? multiAcks,
  }) {
    final FrameBuilder b = FrameBuilder()
      ..u8(MeshcoreCommand.setOtherParams.code)
      ..u8(manualAddContacts)
      ..u8(telemetryModePacked);
    if (advertLocPolicy != null) {
      b.u8(advertLocPolicy);
      if (multiAcks != null) b.u8(multiAcks);
    }
    return b.build();
  }

  /// `CMD_GET_CUSTOM_VARS` (0x28): request the device's custom
  /// string-keyed settings (`gps`, `gps_interval`, etc.). Reply is
  /// `RESP_CODE_CUSTOM_VARS` (0x15) decoded into [CustomVarsFrame].
  static Uint8List getCustomVars() =>
      (FrameBuilder()..u8(MeshcoreCommand.getCustomVars.code)).build();

  /// `CMD_SET_CUSTOM_VAR` (0x29): write a single string-keyed setting.
  /// Body: `[opcode][name]:[value]` (ASCII, no NUL — frame length
  /// defines end). The firmware splits on the first `:` so values
  /// containing `:` would be truncated; values containing `,` are
  /// fine since they aren't a separator on the request path.
  static Uint8List setCustomVar({
    required String name,
    required String value,
  }) {
    assert(!name.contains(':'),
        'custom var name must not contain ":" (frame separator)');
    return (FrameBuilder()
          ..u8(MeshcoreCommand.setCustomVar.code)
          ..utf8String('$name:$value'))
        .build();
  }

  /// `CMD_SET_TUNING_PARAMS` (0x15):
  /// `15 [rx_delay_base u32 LE ×1000] [airtime_factor u32 LE ×1000]`.
  static Uint8List setTuningParams({
    required double rxDelayBaseSeconds,
    required double airtimeFactor,
  }) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.setTuningParams.code)
          ..u32((rxDelayBaseSeconds * kRadioScale).round())
          ..u32((airtimeFactor * kRadioScale).round()))
        .build();
  }

  /// `CMD_DEVICE_QUERY` (0x16): `16 [app_target_ver]`.
  static Uint8List deviceQuery({int appTargetVer = 1}) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.deviceQuery.code)
          ..u8(appTargetVer))
        .build();
  }

  /// `CMD_GET_BATT_AND_STORAGE` (0x14): `14`.
  static Uint8List getBatteryStorage() =>
      (FrameBuilder()..u8(MeshcoreCommand.getBatteryStorage.code)).build();

  /// `CMD_GET_CHANNEL` (0x1F): `1F [channel_idx]`.
  static Uint8List getChannel(int channelIdx) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.getChannel.code)
          ..u8(channelIdx))
        .build();
  }

  /// `CMD_SET_CHANNEL` (0x20):
  /// `20 [channel_idx] [name 32B NUL-padded] [secret 16B]` (50 bytes).
  ///
  /// [psk] is the 16-byte AES-128 channel key as carried by the
  /// companion link (truncated/zero-padded to [kChannelPskSize]).
  static Uint8List setChannel({
    required int channelIdx,
    required String name,
    required List<int> psk,
  }) {
    return (FrameBuilder()
          ..u8(MeshcoreCommand.setChannel.code)
          ..u8(channelIdx)
          ..fixed(utf8.encode(name), kChannelNameSize)
          ..fixed(psk, kChannelPskSize))
        .build();
  }

  // ---------------------------------------------------------------------
  // Decoder (Device → App) — total, never throws.
  // ---------------------------------------------------------------------

  static MeshcoreInbound decode(Uint8List frame) {
    if (frame.isEmpty) {
      return const DecodeFailure(
        MeshcoreDecodeError(DecodeErrorKind.empty, 'empty frame'),
      );
    }
    final int op = frame[0];
    final ByteCursor c = ByteCursor(frame);
    try {
      c.u8('opcode'); // consume opcode
      switch (op) {
        case 0x00: // RESP_CODE_OK
          final int? v = c.remaining >= 4 ? c.u32('ok.value') : null;
          return OkFrame(v);

        case 0x01: // RESP_CODE_ERR
          final int? code = c.remaining >= 1 ? c.u8('err.code') : null;
          return ErrorFrame(code);

        case 0x02: // RESP_CODE_CONTACTS_START
          return ContactsStartFrame(c.u32('contactsStart.count'));

        case 0x03: // RESP_CODE_CONTACT
          return ContactFrame(_decodeContact(c));

        case 0x04: // RESP_CODE_END_OF_CONTACTS
          return EndOfContactsFrame(c.u32('endOfContacts.lastMod'));

        case 0x05: // RESP_CODE_SELF_INFO
          return SelfInfoFrame(_decodeSelfInfo(c));

        case 0x06: // RESP_CODE_SENT
          return MsgSentFrame(MsgSent(
            isFlood: c.u8('msgSent.floodFlag') != 0,
            expectedAck: c.u32('msgSent.expectedAck'),
            estTimeoutMs: c.u32('msgSent.estTimeoutMs'),
          ));

        case 0x07: // RESP_CODE_CONTACT_MSG_RECV (legacy)
          return ContactMessageFrame(_decodeContactMsg(c, v3: false));

        case 0x08: // RESP_CODE_CHANNEL_MSG_RECV (legacy)
          return ChannelMessageFrame(_decodeChannelMsg(c, v3: false));

        case 0x09: // RESP_CODE_CURR_TIME
          return CurrentTimeFrame(c.u32('currentTime.unix'));

        case 0x0C: // RESP_CODE_BATT_AND_STORAGE
          return BatteryStorageFrame(BatteryStorage(
            batteryMillivolts: c.u16('battery.mv'),
            storageUsedKb: c.u32('battery.usedKb'),
            storageTotalKb: c.u32('battery.totalKb'),
          ));

        case 0x0D: // RESP_CODE_DEVICE_INFO
          return DeviceInfoFrame(DeviceInfo(
            firmwareVerCode: c.u8('deviceInfo.fwVer'),
            maxContacts: c.u8('deviceInfo.maxContactsHalf') * 2,
            maxGroupChannels: c.u8('deviceInfo.maxGroupChannels'),
            blePin: c.u32('deviceInfo.blePin'),
            firmwareBuildDate:
                c.fixedCString(kDeviceBuildDateSize, 'deviceInfo.build'),
            manufacturer: c.fixedCString(
                kDeviceManufacturerSize, 'deviceInfo.manufacturer'),
            firmwareVersion: c.fixedCString(
                kDeviceFirmwareVersionSize, 'deviceInfo.fwVersion'),
            clientRepeat: c.u8('deviceInfo.clientRepeat'),
            pathHashMode: c.u8('deviceInfo.pathHashMode'),
          ));

        case 0x0A: // RESP_CODE_NO_MORE_MESSAGES
          return const NoMoreMessagesFrame();

        case 0x15: // RESP_CODE_CUSTOM_VARS
          return CustomVarsFrame(_decodeCustomVars(c));

        case 0x10: // RESP_CODE_CONTACT_MSG_RECV_V3
          return ContactMessageFrame(_decodeContactMsg(c, v3: true));

        case 0x11: // RESP_CODE_CHANNEL_MSG_RECV_V3
          return ChannelMessageFrame(_decodeChannelMsg(c, v3: true));

        case 0x12: // RESP_CODE_CHANNEL_INFO
          return ChannelInfoFrame(ChannelInfo(
            channelIdx: c.u8('channelInfo.idx'),
            name: c.fixedCString(kChannelNameSize, 'channelInfo.name'),
            psk: c.bytes(kChannelPskSize, 'channelInfo.psk'),
          ));

        case 0x83: // PUSH_CODE_MSGS_WAITING
          final int? n = c.remaining >= 1 ? c.u8('msgsWaiting.count') : null;
          return MessagesWaitingFrame(n);

        case 0x80: // PUSH_CODE_ADVERTISEMENT
          return AdvertFrame(_decodeAdvert(c));

        case 0x88: // PUSH_CODE_LOG_RX_DATA
          final double snr = c.i8('rfLog.snr') / 4.0;
          final int rssi = c.i8('rfLog.rssi');
          final Uint8List raw =
              c.atEnd ? Uint8List(0) : c.bytes(c.remaining, 'rfLog.raw');
          return RfLogFrame(RfLog(snrDb: snr, rssi: rssi, raw: raw));

        default:
          return UnsupportedFrame(op, Uint8List.fromList(frame));
      }
    } on FrameTruncated catch (e) {
      return DecodeFailure(
        MeshcoreDecodeError(DecodeErrorKind.truncated, e.toString(),
            opcode: op),
      );
    }
  }

  /// `RESP_CODE_CUSTOM_VARS` payload: comma-separated `name:value`
  /// pairs (ASCII, no NUL — frame length is the terminator). Empty
  /// payload → empty map. Malformed entries (no `:` separator) are
  /// silently dropped to match the firmware's permissive parser.
  static Map<String, String> _decodeCustomVars(ByteCursor c) {
    if (c.atEnd) return const <String, String>{};
    final String payload = c.utf8ToEnd('customVars.payload');
    final Map<String, String> out = <String, String>{};
    for (final String entry in payload.split(',')) {
      final int sep = entry.indexOf(':');
      if (sep <= 0) continue;
      out[entry.substring(0, sep)] = entry.substring(sep + 1);
    }
    return out;
  }

  static SelfInfo _decodeSelfInfo(ByteCursor c) {
    final int advType = c.u8('selfInfo.advType');
    final int txPower = c.u8('selfInfo.txPower');
    final int maxTxPower = c.u8('selfInfo.maxTxPower');
    final Uint8List pubKey = c.bytes(kPubKeySize, 'selfInfo.pubKey');
    final double lat = c.i32('selfInfo.lat') / 1e6;
    final double lon = c.i32('selfInfo.lon') / 1e6;
    final int multiAcks = c.u8('selfInfo.multiAcks');
    final int locPolicy = c.u8('selfInfo.advertLocPolicy');
    final int telemetry = c.u8('selfInfo.telemetryMode');
    final bool manualAdd = c.u8('selfInfo.manualAddContacts') != 0;
    final double freq = c.u32('selfInfo.frequency') / 1000.0;
    final double bw = c.u32('selfInfo.bandwidth') / 1000.0;
    final int sf = c.u8('selfInfo.sf');
    final int cr = c.u8('selfInfo.cr');
    final String name = c.atEnd ? '' : c.utf8ToEnd('selfInfo.name');
    return SelfInfo(
      advType: advType,
      txPowerDbm: txPower,
      maxTxPowerDbm: maxTxPower,
      publicKey: pubKey,
      latitude: lat,
      longitude: lon,
      multiAcks: multiAcks,
      advertLocPolicy: locPolicy,
      telemetryModeRaw: telemetry,
      manualAddContacts: manualAdd,
      frequencyMhz: freq,
      bandwidthKhz: bw,
      spreadingFactor: sf,
      codingRate: cr,
      name: name,
    );
  }

  /// Decodes 0x08 (legacy) and 0x11 (V3) channel messages. The opcode
  /// byte has already been consumed.
  static ChannelMessage _decodeChannelMsg(ByteCursor c, {required bool v3}) {
    double? snr;
    if (v3) {
      snr = c.i8('channelMsg.snr') / 4.0;
      c.u8('channelMsg.reserved1');
      c.u8('channelMsg.reserved2');
    }
    final int channelIdx = c.u8('channelMsg.channelIdx');
    final int pathLen = c.u8('channelMsg.pathLen');
    final int txtType = c.u8('channelMsg.txtType');
    final int ts = c.u32('channelMsg.timestamp');
    final String text = c.atEnd ? '' : c.utf8ToEnd('channelMsg.text');
    return ChannelMessage(
      channelIdx: channelIdx,
      pathLen: pathLen,
      txtType: txtType,
      timestamp: ts,
      text: text,
      isV3: v3,
      snrDb: snr,
    );
  }

  /// Decodes 0x07 (legacy) and 0x10 (V3) contact messages. The opcode
  /// byte has already been consumed.
  static ContactMessage _decodeContactMsg(ByteCursor c, {required bool v3}) {
    double? snr;
    if (v3) {
      snr = c.i8('contactMsg.snr') / 4.0;
      c.u8('contactMsg.reserved1');
      c.u8('contactMsg.reserved2');
    }
    final Uint8List prefix = c.bytes(kPubKeyPrefixSize, 'contactMsg.prefix');
    final int pathLen = c.u8('contactMsg.pathLen');
    final int txtType = c.u8('contactMsg.txtType');
    final int ts = c.u32('contactMsg.timestamp');
    Uint8List? sig;
    if (txtType == kTxtTypeSignedPlain) {
      sig = c.bytes(kSignaturePrefixSize, 'contactMsg.sigPrefix');
    }
    final String text = c.atEnd ? '' : c.utf8ToEnd('contactMsg.text');
    return ContactMessage(
      pubKeyPrefix: prefix,
      pathLen: pathLen,
      txtType: txtType,
      timestamp: ts,
      text: text,
      isV3: v3,
      snrDb: snr,
      signaturePrefix: sig,
    );
  }

  /// Decodes `PUSH_CODE_ADVERTISEMENT` (0x80). The opcode byte has
  /// already been consumed by [c]; the remaining bytes are the advert
  /// payload, shared verbatim with the OTA `PAYLOAD_TYPE_ADVERT` body
  /// ([Advert.parse]).
  static Advert _decodeAdvert(ByteCursor c) {
    final Uint8List payload =
        c.atEnd ? Uint8List(0) : c.bytes(c.remaining, 'advert.payload');
    return Advert.parse(payload);
  }

  static Contact _decodeContact(ByteCursor c) {
    final Uint8List pubKey = c.bytes(kPubKeySize, 'contact.pubKey');
    final int type = c.u8('contact.type');
    final int flags = c.u8('contact.flags');
    final int pathLen = c.u8('contact.outPathLen');
    final Uint8List path = c.bytes(kMaxPathSize, 'contact.outPath');
    final String name = c.fixedCString(kContactNameSize, 'contact.name');
    final int advertTs = c.u32('contact.lastAdvertTimestamp');
    final int latMicros = c.i32('contact.lat');
    final int lonMicros = c.i32('contact.lon');
    final int lastMod = c.u32('contact.lastMod');
    return Contact(
      publicKey: pubKey,
      type: type,
      flags: flags,
      outPathLen: pathLen,
      outPath: path,
      name: name,
      lastAdvertTimestamp: advertTs,
      latitudeMicros: latMicros,
      longitudeMicros: lonMicros,
      lastMod: lastMod,
    );
  }
}
