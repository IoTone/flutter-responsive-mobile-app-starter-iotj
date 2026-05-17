import 'dart:convert';
import 'dart:typed_data';

import '../model/advert.dart';
import '../model/channel_info.dart';
import '../model/channel_message.dart';
import '../model/contact.dart';
import '../model/contact_message.dart';
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

        case 0x0A: // RESP_CODE_NO_MORE_MESSAGES
          return const NoMoreMessagesFrame();

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

        case 0x80: // PUSH_CODE_ADVERTISEMENT
          return AdvertFrame(_decodeAdvert(frame, c));

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
  /// already been consumed by [c].
  static Advert _decodeAdvert(Uint8List frame, ByteCursor c) {
    final Uint8List pubKey = c.bytes(kPubKeySize, 'advert.pubKey');
    final int ts = c.u32('advert.timestamp');
    final Uint8List sig = c.bytes(kSignatureSize, 'advert.signature');
    final Uint8List appData =
        c.atEnd ? Uint8List(0) : c.bytes(c.remaining, 'advert.appData');

    // The exact bytes the device signed: pub_key ‖ ts(4 LE) ‖ app_data.
    final FrameBuilder sm = FrameBuilder()
      ..raw(pubKey)
      ..u32(ts)
      ..raw(appData);
    final Uint8List signedMessage = sm.build();

    int flags = 0;
    int? latMicros;
    int? lonMicros;
    int? feat1;
    int? feat2;
    String? name;
    if (appData.isNotEmpty) {
      final ByteCursor a = ByteCursor(appData);
      flags = a.u8('advert.flags');
      if (flags & kAdvLatLonMask != 0) {
        latMicros = a.i32('advert.lat');
        lonMicros = a.i32('advert.lon');
      }
      if (flags & kAdvFeat1Mask != 0) feat1 = a.u16('advert.feat1');
      if (flags & kAdvFeat2Mask != 0) feat2 = a.u16('advert.feat2');
      if (flags & kAdvNameMask != 0 && !a.atEnd) {
        name = a.utf8ToEnd('advert.name');
      }
    }

    return Advert(
      publicKey: pubKey,
      timestamp: ts,
      signature: sig,
      appData: appData,
      signedMessage: signedMessage,
      flags: flags,
      latitude: latMicros == null ? null : latMicros / 1e6,
      longitude: lonMicros == null ? null : lonMicros / 1e6,
      feat1: feat1,
      feat2: feat2,
      name: name,
    );
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
