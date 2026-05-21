// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meshcore/meshcore.dart';
import 'package:test/test.dart';

Uint8List _hex(String s) {
  final Uint8List out = Uint8List(s.length ~/ 2);
  for (int i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _toHex(List<int> b) =>
    b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('Ed25519 verify KAT (RFC 8032 §7.1)', () {
    // pub, msg, sig
    const List<List<String>> vectors = <List<String>>[
      <String>[
        'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
        '',
        'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155'
            '5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
      ],
      <String>[
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
        '72',
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da'
            '085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      ],
      <String>[
        'fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025',
        'af82',
        '6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac'
            '18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a',
      ],
    ];

    for (int i = 0; i < vectors.length; i++) {
      test('vector ${i + 1} verifies; tamper fails', () async {
        final Uint8List pub = _hex(vectors[i][0]);
        final Uint8List msg = _hex(vectors[i][1]);
        final Uint8List sig = _hex(vectors[i][2]);
        expect(
          await MeshcoreIdentityCrypto.verifySignature(pub, msg, sig),
          isTrue,
        );
        final Uint8List bad = Uint8List.fromList(sig)..[0] ^= 0xFF;
        expect(
          await MeshcoreIdentityCrypto.verifySignature(pub, msg, bad),
          isFalse,
        );
      });
    }
  });

  group('X25519 KAT (RFC 7748 §5.2, via cryptography)', () {
    test('scalar·u matches the published output', () async {
      final Uint8List scalar = _hex(
          'a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4');
      final Uint8List u = _hex(
          'e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c');
      const String expected =
          'c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552';
      final X25519 x = X25519();
      final SimpleKeyPair kp = await x.newKeyPairFromSeed(scalar);
      final SecretKey s = await x.sharedSecretKey(
        keyPair: kp,
        remotePublicKey: SimplePublicKey(u, type: KeyPairType.x25519),
      );
      expect(_toHex(await s.extractBytes()), expected);
    });
  });

  group('libsodium KAT (test/vectors/m3b_x25519_kat.json)', () {
    final Map<String, Object?> doc = jsonDecode(
            File('test/vectors/m3b_x25519_kat.json').readAsStringSync())
        as Map<String, Object?>;

    for (final Object? raw in doc['conversion']! as List<Object?>) {
      final Map<String, Object?> c = raw! as Map<String, Object?>;
      test('seed ${(c['seed']! as String).substring(0, 8)}… : '
          'ed→u, prv64, ed pub', () async {
        final Uint8List seed = _hex(c['seed']! as String);
        final Uint8List edPub = _hex(c['ed_pub']! as String);

        expect(
          _toHex(MeshcoreIdentityCrypto.edPublicKeyToMontgomeryU(edPub)),
          c['mont_u'],
        );
        expect(
          _toHex(MeshcoreIdentityCrypto.expandedPrivateKeyFromSeed(seed)),
          c['prv64'],
        );
        expect(
          _toHex(await MeshcoreIdentityCrypto.ed25519PublicKeyFromSeed(seed)),
          c['ed_pub'],
        );
      });
    }

    test('ed25519_key_exchange matches libsodium + is symmetric', () async {
      final Map<String, Object?> e = doc['ecdh']! as Map<String, Object?>;
      final Uint8List aPrv = _hex(e['alice_prv64']! as String);
      final Uint8List bPrv = _hex(e['bob_prv64']! as String);
      final Uint8List aPub = _hex(e['alice_ed_pub']! as String);
      final Uint8List bPub = _hex(e['bob_ed_pub']! as String);

      final Uint8List ab =
          await MeshcoreIdentityCrypto.ed25519KeyExchange(aPrv, bPub);
      final Uint8List ba =
          await MeshcoreIdentityCrypto.ed25519KeyExchange(bPrv, aPub);

      expect(_toHex(ab), e['shared']);
      expect(_toHex(ba), e['shared']); // DH symmetry
    });
  });

  group('DM crypto (ECDH + Utils::encryptThenMAC reuse)', () {
    test('derive → encrypt → decrypt round-trips both directions',
        () async {
      final Uint8List aSeed = Uint8List.fromList(List<int>.filled(32, 0x11));
      final Uint8List bSeed = Uint8List.fromList(List<int>.filled(32, 0x22));
      final Uint8List aPrv =
          MeshcoreIdentityCrypto.expandedPrivateKeyFromSeed(aSeed);
      final Uint8List bPrv =
          MeshcoreIdentityCrypto.expandedPrivateKeyFromSeed(bSeed);
      final Uint8List aPub =
          await MeshcoreIdentityCrypto.ed25519PublicKeyFromSeed(aSeed);
      final Uint8List bPub =
          await MeshcoreIdentityCrypto.ed25519PublicKeyFromSeed(bSeed);

      final Uint8List sa =
          await MeshcoreDmCrypto.deriveSharedSecret(aPrv, bPub);
      final Uint8List sb =
          await MeshcoreDmCrypto.deriveSharedSecret(bPrv, aPub);
      expect(_toHex(sa), _toHex(sb));
      expect(sa.length, 32);

      final Uint8List pt =
          Uint8List.fromList(utf8.encode('direct hello, Meshmore'));
      final Uint8List frame = MeshcoreDmCrypto.encrypt(sa, pt);
      // Delegates to the M2 channel routine.
      expect(_toHex(frame),
          _toHex(MeshcoreChannelCrypto.encryptThenMac(sb, pt)));

      final Uint8List? dec = MeshcoreDmCrypto.decrypt(sb, frame);
      expect(dec, isNotNull);
      expect(dec!.sublist(0, pt.length), pt);

      frame[0] ^= 0xFF;
      expect(MeshcoreDmCrypto.decrypt(sb, frame), isNull);
    });
  });

  group('verifyAdvert end-to-end (real Ed25519 signature)', () {
    test('valid advert verifies; mutated app_data fails', () async {
      final Ed25519 ed = Ed25519();
      final SimpleKeyPair kp = await ed.newKeyPairFromSeed(
          Uint8List.fromList(List<int>.generate(32, (int i) => i + 3)));
      final Uint8List pub =
          Uint8List.fromList((await kp.extractPublicKey()).bytes);

      // app_data: flags=ADV_TYPE_CHAT|ADV_NAME, then a name.
      final List<int> appData = <int>[
        kAdvTypeChat | kAdvNameMask,
        ...utf8.encode('node-Z'),
      ];
      const int ts = 0x01020304;
      final List<int> signed = <int>[
        ...pub,
        0x04, 0x03, 0x02, 0x01, // ts LE
        ...appData,
      ];
      final Signature s =
          await ed.sign(signed, keyPair: kp);

      final Advert good = Advert(
        publicKey: pub,
        timestamp: ts,
        signature: Uint8List.fromList(s.bytes),
        appData: Uint8List.fromList(appData),
        signedMessage: Uint8List.fromList(signed),
        flags: appData[0],
        name: 'node-Z',
      );
      expect(await MeshcoreIdentityCrypto.verifyAdvert(good), isTrue);

      final Advert tampered = Advert(
        publicKey: pub,
        timestamp: ts,
        signature: Uint8List.fromList(s.bytes),
        appData: good.appData,
        signedMessage: Uint8List.fromList(signed)..[pub.length + 4] ^= 0x01,
        flags: appData[0],
        name: 'node-Z',
      );
      expect(await MeshcoreIdentityCrypto.verifyAdvert(tampered), isFalse);
    });
  });
}
