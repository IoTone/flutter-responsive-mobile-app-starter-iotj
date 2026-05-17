import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';

import '../codec/constants.dart';

/// MeshCore group/channel cipher — a faithful Dart port of
/// `Utils::encrypt/decrypt/encryptThenMAC/MACThenDecrypt` and the
/// channel hash, transcribed from `src/Utils.cpp` / `src/Mesh.h` /
/// `src/MeshCore.h` at the pinned commit.
///
/// Scheme (verbatim from firmware):
///  * Cipher: **AES-128 ECB**, 16-byte blocks, no IV. On encrypt, a
///    trailing partial block is zero-padded to 16 (ciphertext length is
///    always a multiple of 16). On decrypt, every block is decrypted
///    and the padded length returned — the *plaintext* length is
///    recovered from the inner message structure, not from padding.
///  * AES key = the first [kCipherKeySize] (16) bytes of the secret.
///  * MAC = HMAC-SHA256 keyed with the **full** secret
///    ([kChannelSecretSize] = 32 bytes), over the ciphertext, truncated
///    to [kCipherMacSize] (2) bytes.
///  * Frame body = `[MAC (2)] [ciphertext (16-aligned)]`.
///  * Channel hash = first byte of `SHA256(secret)`.
///
/// IMPORTANT — secret length. `mesh::GroupChannel.secret` is 32 bytes,
/// and the HMAC is keyed over all 32. The companion link only conveys
/// the first 16 (the AES PSK). The upper 16 bytes of a real channel's
/// HMAC key are therefore NOT known from the companion protocol alone;
/// [channelSecretFromPsk] makes the provisional choice of zero-filling
/// them, to be confirmed against a real device (M6 interop fixture).
abstract final class MeshcoreChannelCrypto {
  /// SHA-256 digest (32 bytes).
  static Uint8List sha256(Uint8List data) => SHA256Digest().process(data);

  /// SHA-256 over two fragments (mirrors the 2-arg `Utils::sha256`).
  static Uint8List sha256Pair(Uint8List a, Uint8List b) {
    final SHA256Digest d = SHA256Digest();
    d.update(a, 0, a.length);
    d.update(b, 0, b.length);
    final Uint8List out = Uint8List(32);
    d.doFinal(out, 0);
    return out;
  }

  /// Channel hash — the first byte of `SHA256(secret)`. Used on the air
  /// to identify which channel a packet belongs to.
  static int channelHash(Uint8List secret) => sha256(secret)[0];

  /// Build a 32-byte channel secret from the 16-byte companion PSK.
  ///
  /// PROVISIONAL: the upper 16 bytes are zero-filled because the
  /// companion protocol does not carry them. Validate against a real
  /// device before relying on the MAC for OTA frames (M6).
  static Uint8List channelSecretFromPsk(List<int> psk) {
    final Uint8List s = Uint8List(kChannelSecretSize);
    final int n = psk.length < kCipherKeySize ? psk.length : kCipherKeySize;
    s.setRange(0, n, psk);
    return s;
  }

  /// HMAC-SHA256(key, msg) — full 32-byte tag.
  static Uint8List hmacSha256(Uint8List key, Uint8List msg) {
    final HMac h = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
    return h.process(msg);
  }

  /// AES-128-ECB, zero-padding a trailing partial block. Mirrors
  /// `Utils::encrypt`. [key] must be [kCipherKeySize] bytes.
  static Uint8List aes128EcbEncrypt(Uint8List key, Uint8List src) {
    final AESEngine aes = AESEngine()..init(true, KeyParameter(key));
    final int full = src.length ~/ kCipherBlockSize;
    final int rem = src.length % kCipherBlockSize;
    final int outLen = (full + (rem > 0 ? 1 : 0)) * kCipherBlockSize;
    final Uint8List out = Uint8List(outLen);
    int off = 0;
    for (; off < full * kCipherBlockSize; off += kCipherBlockSize) {
      aes.processBlock(src, off, out, off);
    }
    if (rem > 0) {
      final Uint8List tmp = Uint8List(kCipherBlockSize);
      tmp.setRange(0, rem, src, off);
      aes.processBlock(tmp, 0, out, off);
    }
    return out;
  }

  /// AES-128-ECB decrypt. Mirrors `Utils::decrypt`: [src] length must be
  /// a multiple of [kCipherBlockSize]; returns the full (still padded)
  /// plaintext.
  static Uint8List aes128EcbDecrypt(Uint8List key, Uint8List src) {
    if (src.length % kCipherBlockSize != 0) {
      throw ArgumentError('ciphertext not block-aligned: ${src.length}');
    }
    final AESEngine aes = AESEngine()..init(false, KeyParameter(key));
    final Uint8List out = Uint8List(src.length);
    for (int off = 0; off < src.length; off += kCipherBlockSize) {
      aes.processBlock(src, off, out, off);
    }
    return out;
  }

  /// `Utils::encryptThenMAC` → `[MAC (2)] [ciphertext]`.
  /// [secret] is the 32-byte channel secret.
  static Uint8List encryptThenMac(Uint8List secret, Uint8List plaintext) {
    final Uint8List key = Uint8List.sublistView(secret, 0, kCipherKeySize);
    final Uint8List ct = aes128EcbEncrypt(key, plaintext);
    final Uint8List mac = hmacSha256(secret, ct);
    final Uint8List out = Uint8List(kCipherMacSize + ct.length);
    out.setRange(0, kCipherMacSize, mac);
    out.setRange(kCipherMacSize, out.length, ct);
    return out;
  }

  /// `Utils::MACThenDecrypt`. Returns the padded plaintext, or `null`
  /// if the frame is too short or the MAC does not verify.
  static Uint8List? macThenDecrypt(Uint8List secret, Uint8List frame) {
    if (frame.length <= kCipherMacSize) return null;
    final Uint8List ct =
        Uint8List.sublistView(frame, kCipherMacSize, frame.length);
    // MeshCore ciphertext is always block-aligned (encrypt zero-pads
    // the final block). A non-aligned or empty body cannot be a valid
    // frame — reject it rather than letting AES throw. Keeps this
    // entry point total (TC2).
    if (ct.isEmpty || ct.length % kCipherBlockSize != 0) return null;
    final Uint8List calc = hmacSha256(secret, ct);
    if (!_constantTimeEquals(frame, 0, calc, 0, kCipherMacSize)) return null;
    final Uint8List key = Uint8List.sublistView(secret, 0, kCipherKeySize);
    return aes128EcbDecrypt(key, ct);
  }

  static bool _constantTimeEquals(
      Uint8List a, int aOff, Uint8List b, int bOff, int len) {
    int diff = 0;
    for (int i = 0; i < len; i++) {
      diff |= a[aOff + i] ^ b[bOff + i];
    }
    return diff == 0;
  }
}
