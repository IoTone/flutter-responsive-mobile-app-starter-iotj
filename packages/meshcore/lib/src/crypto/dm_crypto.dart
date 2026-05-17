import 'dart:typed_data';

import 'channel_crypto.dart';
import 'identity_crypto.dart';

/// Direct-message payload crypto.
///
/// MeshCore encrypts DMs with the **same** `Utils::encryptThenMAC` /
/// `MACThenDecrypt` routine used for channels (`src/Mesh.cpp`, pinned
/// commit) — only the key differs: a 32-byte ECDH shared secret from
/// [MeshcoreIdentityCrypto.ed25519KeyExchange] instead of a channel
/// secret.
///
/// Unlike the channel case there is **no open tail question**: the DM
/// secret is a full 32 bytes, so the HMAC (keyed over all 32) is fully
/// determined here.
abstract final class MeshcoreDmCrypto {
  /// Derive the 32-byte DM shared secret with a contact.
  ///
  /// [privateKey64] = our orlp-style 64-byte private key;
  /// [theirPublicKey] = the contact's 32-byte Ed25519 public key.
  static Future<Uint8List> deriveSharedSecret(
    Uint8List privateKey64,
    Uint8List theirPublicKey,
  ) =>
      MeshcoreIdentityCrypto.ed25519KeyExchange(
          privateKey64, theirPublicKey);

  /// `[MAC(2)] ‖ ciphertext` for [plaintext] under [sharedSecret] (32B).
  static Uint8List encrypt(Uint8List sharedSecret, Uint8List plaintext) =>
      MeshcoreChannelCrypto.encryptThenMac(sharedSecret, plaintext);

  /// Inverse of [encrypt]; returns the (block-padded) plaintext or
  /// `null` if the MAC fails / the frame is too short.
  static Uint8List? decrypt(Uint8List sharedSecret, Uint8List frame) =>
      MeshcoreChannelCrypto.macThenDecrypt(sharedSecret, frame);
}
