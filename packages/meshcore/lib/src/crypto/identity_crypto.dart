import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/digests/sha512.dart';

import '../codec/constants.dart';
import '../model/advert.dart';

/// Ed25519 identity + the MeshCore `ed25519_key_exchange` ECDH.
///
/// MeshCore (`src/Identity.cpp`, pinned commit) uses the **orlp/ed25519**
/// C library: 32-byte public key, 64-byte private key (= clamped
/// `SHA512(seed)`), 64-byte signatures. `ed25519_key_exchange` derives a
/// 32-byte shared secret by converting the peer's Ed25519 public key to
/// its Montgomery u-coordinate and running X25519 with the clamped
/// private scalar (the raw scalar-mult output — it is NOT hashed).
///
/// Implementation split (see spec → Crypto layer):
///  * Ed25519 verify + X25519 scalar-mult: `package:cryptography`
///    (pure-Dart `DartEd25519`/`DartX25519`, RFC 8032 / RFC 7748).
///  * The Ed25519→Montgomery-u birational map `u = (1+y)/(1-y) mod p`
///    is implemented here (BigInt field math) — the one piece neither
///    library exposes.
///
/// orlp clamp `e[0]&=248; e[31]&=63; e[31]|=64` is bit-identical to and
/// idempotent under RFC 7748 clamp (`DartX25519` re-applies it), so a
/// 64-byte orlp private key's first 32 bytes are fed directly as the
/// X25519 seed.
///
/// Anchored by: RFC 8032 §7.1 (Ed25519 verify), RFC 7748 §5.2 (X25519),
/// and offline **libsodium** KATs for the conversion + full key
/// exchange (`test/vectors/m3b_x25519_kat.json`). The exact-bytes match
/// to a real device is still an M6 interop-fixture confirmation.
abstract final class MeshcoreIdentityCrypto {
  static final Ed25519 _ed = Ed25519();
  static final X25519 _x = X25519();

  /// p = 2^255 - 19.
  static final BigInt _p =
      (BigInt.one << 255) - BigInt.from(19);

  /// Verify an Ed25519 [signature] (64 bytes) over [message] for the
  /// 32-byte [publicKey].
  static Future<bool> verifySignature(
    Uint8List publicKey,
    Uint8List message,
    Uint8List signature,
  ) {
    return _ed.verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey,
            type: KeyPairType.ed25519),
      ),
    );
  }

  /// Verify an advert's Ed25519 signature over
  /// `pub_key ‖ timestamp ‖ app_data` ([Advert.signedMessage]).
  static Future<bool> verifyAdvert(Advert advert) => verifySignature(
        advert.publicKey,
        advert.signedMessage,
        advert.signature,
      );

  /// Map an Ed25519 public key to its Montgomery u-coordinate:
  /// `u = (1 + y) / (1 - y) mod p`, where `y` is the compressed point's
  /// low 255 bits (sign bit cleared). Returns 32 bytes little-endian.
  static Uint8List edPublicKeyToMontgomeryU(Uint8List edPublicKey) {
    if (edPublicKey.length != kPubKeySize) {
      throw ArgumentError('ed public key must be 32 bytes');
    }
    // Decode y little-endian, clear the x-sign bit (bit 255).
    BigInt y = BigInt.zero;
    for (int i = kPubKeySize - 1; i >= 0; i--) {
      y = (y << 8) | BigInt.from(edPublicKey[i]);
    }
    y = y & ((BigInt.one << 255) - BigInt.one); // clear bit 255
    y = y % _p;

    final BigInt one = BigInt.one;
    final BigInt num = (one + y) % _p;
    final BigInt den = (one - y) % _p;
    final BigInt denInv = den.modInverse(_p);
    final BigInt u = (num * denInv) % _p;

    final Uint8List out = Uint8List(32);
    BigInt t = u;
    for (int i = 0; i < 32; i++) {
      out[i] = (t & BigInt.from(0xff)).toInt();
      t = t >> 8;
    }
    return out;
  }

  /// MeshCore `ed25519_key_exchange(secret, theirPub, ourPrv64)`.
  ///
  /// [privateKey64] is the orlp-style 64-byte private key (only the
  /// first 32 bytes — the clamped scalar — are used). Returns the
  /// 32-byte shared secret (raw X25519 output, unhashed) suitable as
  /// the DM key for [MeshcoreChannelCrypto.encryptThenMac].
  static Future<Uint8List> ed25519KeyExchange(
    Uint8List privateKey64,
    Uint8List theirPublicKey,
  ) async {
    if (privateKey64.length != kPrivKeySize) {
      throw ArgumentError('private key must be 64 bytes (orlp expanded)');
    }
    final Uint8List scalar =
        Uint8List.sublistView(privateKey64, 0, 32);
    final Uint8List u = edPublicKeyToMontgomeryU(theirPublicKey);

    final SimpleKeyPair kp = await _x.newKeyPairFromSeed(scalar);
    final SecretKey shared = await _x.sharedSecretKey(
      keyPair: kp,
      remotePublicKey: SimplePublicKey(u, type: KeyPairType.x25519),
    );
    return Uint8List.fromList(await shared.extractBytes());
  }

  /// orlp-style expanded private key from a 32-byte seed:
  /// `SHA512(seed)` with the standard clamp applied. Matches the
  /// 64-byte `prv_key` MeshCore stores.
  static Uint8List expandedPrivateKeyFromSeed(Uint8List seed) {
    if (seed.length != 32) {
      throw ArgumentError('seed must be 32 bytes');
    }
    final Uint8List h = SHA512Digest().process(seed); // 64 bytes
    h[0] &= 248;
    h[31] &= 63;
    h[31] |= 64;
    return h;
  }

  /// The 32-byte Ed25519 public key for a 32-byte seed.
  static Future<Uint8List> ed25519PublicKeyFromSeed(Uint8List seed) async {
    final SimpleKeyPair kp = await _ed.newKeyPairFromSeed(seed);
    final SimplePublicKey pk = await kp.extractPublicKey();
    return Uint8List.fromList(pk.bytes);
  }
}
