import 'dart:typed_data';

import '../model/contact.dart';
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

        case 0x09: // RESP_CODE_CURR_TIME
          return CurrentTimeFrame(c.u32('currentTime.unix'));

        case 0x0A: // RESP_CODE_NO_MORE_MESSAGES
          return const NoMoreMessagesFrame();

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

  static Contact _decodeContact(ByteCursor c) {
    final Uint8List pubKey = c.bytes(kPubKeySize, 'contact.pubKey');
    final int type = c.u8('contact.type');
    final int flags = c.u8('contact.flags');
    final int pathLen = c.u8('contact.outPathLen');
    final Uint8List path = c.bytes(kMaxPathSize, 'contact.outPath');
    final String name = c.fixedCString(kContactNameSize, 'contact.name');
    final int advertTs = c.u32('contact.lastAdvertTimestamp');
    final double lat = c.i32('contact.lat') / 1e6;
    final double lon = c.i32('contact.lon') / 1e6;
    final int lastMod = c.u32('contact.lastMod');
    return Contact(
      publicKey: pubKey,
      type: type,
      flags: flags,
      outPathLen: pathLen,
      outPath: path,
      name: name,
      lastAdvertTimestamp: advertTs,
      latitude: lat,
      longitude: lon,
      lastMod: lastMod,
    );
  }
}
