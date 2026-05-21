// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:io';
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

String _toHex(List<int> b) =>
    b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _encodeByName(String n, Map<String, Object?> a) {
  switch (n) {
    case 'sendTextMessage':
      return MeshcoreFrameCodec.sendTextMessage(
        pubKeyPrefix: _hex(a['pubKeyPrefix']! as String),
        timestamp: a['timestamp']! as int,
        text: a['text']! as String,
      );
    case 'sendSelfAdvert':
      return MeshcoreFrameCodec.sendSelfAdvert(flood: a['flood']! as bool);
    case 'setAdvertName':
      return MeshcoreFrameCodec.setAdvertName(a['name']! as String);
    default:
      fail('unknown encoder "$n"');
  }
}

void main() {
  group('M3 contact/advert vectors', () {
    final Map<String, Object?> doc = jsonDecode(
            File('test/vectors/m3_contact_advert_frames.json')
                .readAsStringSync())
        as Map<String, Object?>;

    for (final Object? raw in doc['encode']! as List<Object?>) {
      final Map<String, Object?> c = raw! as Map<String, Object?>;
      test('encode: ${c['name']}', () {
        final Uint8List got = _encodeByName(c['encoder']! as String,
            (c['args'] as Map<String, Object?>?) ?? const <String, Object?>{});
        expect(_toHex(got), c['hex']! as String);
      });
    }

    for (final Object? raw in doc['decode']! as List<Object?>) {
      final Map<String, Object?> c = raw! as Map<String, Object?>;
      test('decode: ${c['name']}', () {
        final MeshcoreInbound got =
            MeshcoreFrameCodec.decode(_hex(c['hex']! as String));
        final Map<String, Object?> e = c['expect']! as Map<String, Object?>;
        expect(got, isA<ContactMessageFrame>());
        final ContactMessage m = (got as ContactMessageFrame).message;
        expect(_toHex(m.pubKeyPrefix), e['pubKeyPrefix']);
        expect(m.pathLen, e['pathLen']);
        expect(m.isFlood, e['isFlood']);
        expect(m.txtType, e['txtType']);
        expect(m.timestamp, e['timestamp']);
        expect(m.text, e['text']);
        expect(m.isV3, e['isV3']);
        expect(m.snrDb, e['snrDb']);
        expect(m.isSigned, e['isSigned']);
        if (e['signaturePrefix'] != null) {
          expect(_toHex(m.signaturePrefix!), e['signaturePrefix']);
        }
      });
    }
  });

  group('ADD_UPDATE_CONTACT (0x09) — round-trip via shared 148B layout', () {
    test('encode -> swap opcode to 0x03 -> decode equals original', () {
      final Contact c = Contact(
        publicKey: Uint8List.fromList(List<int>.generate(32, (int i) => i)),
        type: 1,
        flags: 0,
        outPathLen: 2,
        outPath: Uint8List(64)..setRange(0, 2, <int>[0xAA, 0xBB]),
        name: 'Repeater-7',
        lastAdvertTimestamp: 0x01020304,
        latitudeMicros: 1000000,
        longitudeMicros: -2000000,
        lastMod: 0xFF,
      );
      final Uint8List enc = MeshcoreFrameCodec.addUpdateContact(c);
      // Firmware offsets: opcode[0], pub_key[1..32] … lastmod[144..147].
      expect(enc.length, 148, reason: '1 opcode + 147-byte body');
      expect(enc[0], 0x09);

      // Reinterpret the 148-byte body via the RESP_CODE_CONTACT decoder.
      enc[0] = 0x03;
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(enc);
      expect(got, isA<ContactFrame>());
      final Contact d = (got as ContactFrame).contact;
      expect(d.publicKey, c.publicKey);
      expect(d.type, c.type);
      expect(d.flags, c.flags);
      expect(d.outPathLen, c.outPathLen);
      expect(d.activePath, <int>[0xAA, 0xBB]);
      expect(d.name, 'Repeater-7');
      expect(d.lastAdvertTimestamp, 0x01020304);
      expect(d.latitudeMicros, 1000000);
      expect(d.longitudeMicros, -2000000);
      expect(d.lastMod, 0xFF);
    });
  });

  group('ADVERT (0x80) — programmatic golden', () {
    test('pubkey/ts/sig + app_data (latlon+name), signedMessage exact', () {
      final List<int> pk = List<int>.generate(32, (int i) => i);
      final List<int> sig = List<int>.filled(64, 0x55);
      // flags: ADV_NAME(0x80) | ADV_LATLON(0x10) | type CHAT(1) = 0x91
      final List<int> appData = <int>[
        0x91,
        0x40, 0x42, 0x0f, 0x00, // lat 1000000 -> 1.0
        0x80, 0x7b, 0xe1, 0xff, // lon -2000000 -> -2.0
        ...utf8.encode('RPTR-1'),
      ];
      final List<int> frame = <int>[
        0x80,
        ...pk,
        0x04, 0x03, 0x02, 0x01, // ts 0x01020304
        ...sig,
        ...appData,
      ];

      final MeshcoreInbound got =
          MeshcoreFrameCodec.decode(Uint8List.fromList(frame));
      expect(got, isA<AdvertFrame>());
      final Advert a = (got as AdvertFrame).advert;
      expect(a.publicKey, pk);
      expect(a.timestamp, 0x01020304);
      expect(a.signature, sig);
      expect(a.flags, 0x91);
      expect(a.type, kAdvTypeChat);
      expect(a.latitude, closeTo(1.0, 1e-9));
      expect(a.longitude, closeTo(-2.0, 1e-9));
      expect(a.feat1, isNull);
      expect(a.feat2, isNull);
      expect(a.name, 'RPTR-1');
      // signedMessage = pub_key ‖ ts(4 LE) ‖ app_data
      expect(_toHex(a.signedMessage),
          _toHex(<int>[...pk, 0x04, 0x03, 0x02, 0x01, ...appData]));
    });

    test('advert with no app_data: flags 0, no optional fields', () {
      final List<int> frame = <int>[
        0x80,
        ...List<int>.filled(32, 7),
        0x00, 0x00, 0x00, 0x00,
        ...List<int>.filled(64, 9),
      ];
      final MeshcoreInbound got =
          MeshcoreFrameCodec.decode(Uint8List.fromList(frame));
      expect(got, isA<AdvertFrame>());
      final Advert a = (got as AdvertFrame).advert;
      expect(a.appData, isEmpty);
      expect(a.flags, 0);
      expect(a.name, isNull);
      expect(a.latitude, isNull);
    });

    test('truncated advert (short signature) -> DecodeFailure', () {
      final List<int> frame = <int>[
        0x80,
        ...List<int>.filled(32, 0),
        0, 0, 0, 0,
        ...List<int>.filled(10, 0), // sig should be 64
      ];
      final MeshcoreInbound got =
          MeshcoreFrameCodec.decode(Uint8List.fromList(frame));
      expect(got, isA<DecodeFailure>());
      expect((got as DecodeFailure).error.kind, DecodeErrorKind.truncated);
    });
  });

  group('public channel constants (docs/qr_codes.md, pinned)', () {
    test('name + 16-byte PSK', () {
      expect(kPublicChannelName, 'Public');
      expect(kPublicChannelPsk.length, 16);
      expect(_toHex(kPublicChannelPsk), '8b3387e9c5cdea6ac9e5edbaa115cd72');
    });

    test('channelSecretFromPsk(public) is 32B, hash is deterministic', () {
      final Uint8List secret = MeshcoreChannelCrypto.channelSecretFromPsk(
          kPublicChannelPsk);
      expect(secret.length, kChannelSecretSize);
      expect(secret.sublist(0, 16), kPublicChannelPsk);
      expect(secret.sublist(16), List<int>.filled(16, 0));
      // On-air channel hash is SHA256(psk16)[0] — keyed on the PSK,
      // NOT the 32-byte secret. Cross-checked vs docs: public → 0x11.
      expect(MeshcoreChannelCrypto.channelHashFromPsk(kPublicChannelPsk),
          MeshcoreChannelCrypto.sha256(
              Uint8List.fromList(kPublicChannelPsk))[0]);
      expect(MeshcoreChannelCrypto.channelHashFromPsk(kPublicChannelPsk),
          0x11);
    });
  });
}
