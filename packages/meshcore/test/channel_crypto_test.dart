import 'dart:convert';
import 'dart:typed_data';

import 'package:meshcore/meshcore.dart';
import 'package:test/test.dart';

Uint8List _hex(String s) {
  final Uint8List out = Uint8List(s.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _toHex(Uint8List b) =>
    b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  // --- Anchor the primitives to published standard test vectors. ---

  group('AES-128 ECB KAT (NIST FIPS-197 / SP800-38A F.1)', () {
    final Uint8List key = _hex('000102030405060708090a0b0c0d0e0f');
    final Uint8List pt = _hex('00112233445566778899aabbccddeeff');
    final Uint8List ct = _hex('69c4e0d86a7b0430d8cdb78070b4c55a');

    test('encrypt single block', () {
      expect(_toHex(MeshcoreChannelCrypto.aes128EcbEncrypt(key, pt)),
          _toHex(ct));
    });
    test('decrypt single block', () {
      expect(_toHex(MeshcoreChannelCrypto.aes128EcbDecrypt(key, ct)),
          _toHex(pt));
    });
    test('zero-pads a trailing partial block to 16', () {
      final Uint8List enc =
          MeshcoreChannelCrypto.aes128EcbEncrypt(key, _hex('0011'));
      expect(enc.length, 16);
      // Must equal encrypting the explicitly zero-padded block.
      final Uint8List padded = Uint8List(16)..setRange(0, 2, _hex('0011'));
      expect(_toHex(enc),
          _toHex(MeshcoreChannelCrypto.aes128EcbEncrypt(key, padded)));
    });
  });

  group('SHA-256 KAT (NIST)', () {
    test('"abc"', () {
      expect(
        _toHex(MeshcoreChannelCrypto.sha256(
            Uint8List.fromList(utf8.encode('abc')))),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });
    test('sha256Pair == sha256 of the concatenation', () {
      final Uint8List a = Uint8List.fromList(utf8.encode('ab'));
      final Uint8List b = Uint8List.fromList(utf8.encode('c'));
      expect(
        _toHex(MeshcoreChannelCrypto.sha256Pair(a, b)),
        _toHex(MeshcoreChannelCrypto.sha256(
            Uint8List.fromList(<int>[...a, ...b]))),
      );
    });
  });

  group('HMAC-SHA256 KAT (RFC 4231 test case 2)', () {
    test('key="Jefe"', () {
      final Uint8List key = Uint8List.fromList(utf8.encode('Jefe'));
      final Uint8List data =
          Uint8List.fromList(utf8.encode('what do ya want for nothing?'));
      expect(
        _toHex(MeshcoreChannelCrypto.hmacSha256(key, data)),
        '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
      );
    });
  });

  // --- MeshCore composition (Utils::encryptThenMAC / MACThenDecrypt). ---

  group('encryptThenMac / macThenDecrypt', () {
    final Uint8List secret =
        Uint8List.fromList(List<int>.generate(32, (int i) => i));
    final Uint8List plaintext =
        Uint8List.fromList(utf8.encode('MESHMORE-SNS hello'));

    test('frame == [HMAC(secret,ct)[:2]] ++ ct, ct = AES128ECB(key16, pt)',
        () {
      final Uint8List key = Uint8List.sublistView(secret, 0, kCipherKeySize);
      final Uint8List ct =
          MeshcoreChannelCrypto.aes128EcbEncrypt(key, plaintext);
      final Uint8List mac = MeshcoreChannelCrypto.hmacSha256(secret, ct);

      final Uint8List frame =
          MeshcoreChannelCrypto.encryptThenMac(secret, plaintext);

      expect(frame.length, kCipherMacSize + ct.length);
      expect(ct.length % kCipherBlockSize, 0);
      expect(frame.sublist(0, kCipherMacSize), mac.sublist(0, kCipherMacSize));
      expect(frame.sublist(kCipherMacSize), ct);
    });

    test('round-trips (decrypt yields zero-padded plaintext)', () {
      final Uint8List frame =
          MeshcoreChannelCrypto.encryptThenMac(secret, plaintext);
      final Uint8List? dec =
          MeshcoreChannelCrypto.macThenDecrypt(secret, frame);
      expect(dec, isNotNull);
      // Decrypted length is block-padded; the prefix is the plaintext.
      expect(dec!.length % kCipherBlockSize, 0);
      expect(dec.sublist(0, plaintext.length), plaintext);
      expect(dec.sublist(plaintext.length),
          List<int>.filled(dec.length - plaintext.length, 0));
    });

    test('exact block-multiple plaintext is not over-padded', () {
      final Uint8List pt16 = Uint8List(16)..setRange(0, 3, <int>[1, 2, 3]);
      final Uint8List frame =
          MeshcoreChannelCrypto.encryptThenMac(secret, pt16);
      expect(frame.length, kCipherMacSize + 16);
    });

    test('tampered MAC -> null', () {
      final Uint8List frame =
          MeshcoreChannelCrypto.encryptThenMac(secret, plaintext);
      frame[0] ^= 0xFF;
      expect(MeshcoreChannelCrypto.macThenDecrypt(secret, frame), isNull);
    });

    test('tampered ciphertext -> null (MAC fails)', () {
      final Uint8List frame =
          MeshcoreChannelCrypto.encryptThenMac(secret, plaintext);
      frame[frame.length - 1] ^= 0x01;
      expect(MeshcoreChannelCrypto.macThenDecrypt(secret, frame), isNull);
    });

    test('frame too short -> null', () {
      expect(MeshcoreChannelCrypto.macThenDecrypt(secret, _hex('00')), isNull);
      expect(MeshcoreChannelCrypto.macThenDecrypt(secret, _hex('0011')),
          isNull);
    });
  });

  group('channel hash + secret helpers', () {
    test('channelHash == SHA256(secret)[0]', () {
      final Uint8List secret =
          Uint8List.fromList(List<int>.generate(32, (int i) => i * 7 & 0xFF));
      expect(MeshcoreChannelCrypto.channelHash(secret),
          MeshcoreChannelCrypto.sha256(secret)[0]);
    });

    test('channelSecretFromPsk: 32 bytes, psk in [0:16], zeros in [16:32]',
        () {
      final List<int> psk = List<int>.generate(16, (int i) => i + 1);
      final Uint8List s = MeshcoreChannelCrypto.channelSecretFromPsk(psk);
      expect(s.length, kChannelSecretSize);
      expect(s.sublist(0, 16), psk);
      expect(s.sublist(16, 32), List<int>.filled(16, 0));
    });
  });
}
