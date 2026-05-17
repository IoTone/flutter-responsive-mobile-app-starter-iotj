import 'dart:typed_data';

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

  @override
  String toString() => 'Advert(type: $type, name: ${name ?? '-'}, '
      'ts: $timestamp, hasLoc: ${latitude != null})';
}
