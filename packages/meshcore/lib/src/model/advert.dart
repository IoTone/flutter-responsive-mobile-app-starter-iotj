// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import '../codec/byte_cursor.dart';
import '../codec/constants.dart';

/// A decoded advertisement (`PUSH_CODE_ADVERTISEMENT`, 0x80).
///
/// Packet payload (from `src/Mesh.cpp`, pinned commit):
/// ```
/// [pub_key 32][timestamp u32 LE][signature 64][app_data …]
/// ```
/// app_data (`AdvertDataHelpers`): `[flags]` then, conditionally,
/// `[lat i32][lon i32]` (ADV_LATLON 0x10), `[feat1 u16]` (0x20),
/// `[feat2 u16]` (0x40), `[name UTF-8]` (0x80). The low nibble of
/// `flags` is the advert type (0=none,1=chat,2=repeater,3=room,
/// 4=sensor).
///
/// The Ed25519-signed message is `pub_key ‖ timestamp ‖ app_data`,
/// exposed as [signedMessage] for verification (M3b).
class Advert {
  const Advert({
    required this.publicKey,
    required this.timestamp,
    required this.signature,
    required this.appData,
    required this.signedMessage,
    required this.flags,
    this.latitude,
    this.longitude,
    this.feat1,
    this.feat2,
    this.name,
  });

  /// 32-byte Ed25519 public key (full node identity).
  final Uint8List publicKey;

  /// Advert emission time (unix seconds).
  final int timestamp;

  /// 64-byte Ed25519 signature.
  final Uint8List signature;

  /// Raw app_data bytes (flags + optional fields).
  final Uint8List appData;

  /// `pub_key ‖ timestamp(4 LE) ‖ app_data` — the exact bytes the
  /// device signed; pass to Ed25519 verify with [publicKey].
  final Uint8List signedMessage;

  final int flags;

  /// Degrees (raw int32 ÷ 1e6), if ADV_LATLON was set.
  final double? latitude;
  final double? longitude;
  final int? feat1;
  final int? feat2;
  final String? name;

  /// Advert node type (`flags & 0x0F`).
  int get type => flags & 0x0F;

  /// Parse an advert payload — `pub_key(32) ‖ ts(4 LE) ‖ sig(64) ‖
  /// app_data`. Shared by the companion `0x80` decoder and
  /// [OtaPacket.advert] (the OTA `PAYLOAD_TYPE_ADVERT` body has the
  /// same layout). Throws [FrameTruncated] on a short/garbled
  /// payload; the callers turn that into a typed failure / null.
  static Advert parse(Uint8List payload) {
    final ByteCursor c = ByteCursor(payload);
    final Uint8List pubKey = c.bytes(kPubKeySize, 'advert.pubKey');
    final int ts = c.u32('advert.timestamp');
    final Uint8List sig = c.bytes(kSignatureSize, 'advert.signature');
    final Uint8List appData =
        c.atEnd ? Uint8List(0) : c.bytes(c.remaining, 'advert.appData');

    final Uint8List signedMessage = (FrameBuilder()
          ..raw(pubKey)
          ..u32(ts)
          ..raw(appData))
        .build();

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

  /// Total variant — null instead of throwing.
  static Advert? tryParse(Uint8List payload) {
    try {
      return parse(payload);
    } on FrameTruncated {
      return null;
    }
  }

  @override
  String toString() => 'Advert(type: $type, name: ${name ?? '-'}, '
      'ts: $timestamp, hasLoc: ${latitude != null})';
}
