import 'dart:convert';
import 'dart:typed_data';

import 'package:meshcore/meshcore.dart';
import 'package:test/test.dart';

/// Build a GRP_TXT over-the-air packet (FLOOD route, 0 hops) carrying
/// `encryptThenMac(secret, plaintext)` under a chosen tail, then wrap
/// it in a 0x88 RF-log frame — a synthetic stand-in for a real device
/// capture, used to prove the codec + oracle logic.
Uint8List _rfLogGrpTxt(Uint8List secret32, Uint8List plaintext) {
  final int header = (kPayloadTypeGrpTxt << kPktPayloadTypeShift) |
      kRouteFlood; // ver 0
  // On-air channel hash is keyed on the 16-byte PSK only.
  final int channelHash = MeshcoreChannelCrypto.channelHashFromPsk(
      secret32.sublist(0, 16));
  final Uint8List macCt =
      MeshcoreChannelCrypto.encryptThenMac(secret32, plaintext);
  final List<int> ota = <int>[
    header,
    0x00, // path-len: 0 hops, 1-byte hash code
    channelHash,
    ...macCt,
  ];
  return Uint8List.fromList(<int>[
    0x88,
    7 * 4, // snr +7.0
    (-92) & 0xFF, // rssi -92
    ...ota,
  ]);
}

void main() {
  group('0x88 RF-log + OTA packet codec', () {
    test('decodes RfLogFrame and parses a GRP_TXT packet', () {
      final Uint8List secret = Uint8List(kChannelSecretSize)
        ..setRange(0, 16, kPublicChannelPsk); // zeros tail
      final Uint8List pt = Uint8List.fromList(utf8.encode('hello public'));
      final MeshcoreInbound f =
          MeshcoreFrameCodec.decode(_rfLogGrpTxt(secret, pt));

      expect(f, isA<RfLogFrame>());
      final RfLog log = (f as RfLogFrame).log;
      expect(log.snrDb, 7.0);
      expect(log.rssi, -92);

      final OtaPacket? pkt = log.packet;
      expect(pkt, isNotNull);
      expect(pkt!.isGrpTxt, isTrue);
      expect(pkt.hopCount, 0);
      final GrpTxtPayload? g = pkt.grpTxt;
      expect(g, isNotNull);
      expect(g!.channelHash,
          MeshcoreChannelCrypto.channelHashFromPsk(secret.sublist(0, 16)));
    });

    test('OtaPacket.parse skips transport codes + multi-byte path', () {
      // TRANSPORT_FLOOD route ⇒ 4 transport-code bytes; path-len with
      // 2 hops × 2-byte hashes ⇒ 4 path bytes.
      final int header =
          (kPayloadTypeAdvert << kPktPayloadTypeShift) | kRouteTransportFlood;
      final int pathLen = 2 | (1 << kPathHashSizeShift); // 2 hops, 2B
      final Uint8List raw = Uint8List.fromList(<int>[
        header,
        1, 2, 3, 4, // transport codes
        pathLen,
        9, 9, 9, 9, // 2×2 path
        0xAA, 0xBB, // payload
      ]);
      final OtaPacket? p = OtaPacket.parse(raw);
      expect(p, isNotNull);
      expect(p!.payloadType, kPayloadTypeAdvert);
      expect(p.hopCount, 2);
      expect(p.hashSize, 2);
      expect(p.payload, <int>[0xAA, 0xBB]);
    });

    test('truncated OTA packet → null (never throws)', () {
      // header only, no path-len byte ⇒ truncated ⇒ null.
      expect(OtaPacket.parse(Uint8List.fromList(<int>[0x15])), isNull);
      expect(OtaPacket.parse(Uint8List(0)), isNull);
      // header + path-len(0 hops) + empty payload ⇒ valid, no payload.
      final OtaPacket? p =
          OtaPacket.parse(Uint8List.fromList(<int>[0x15, 0x00]));
      expect(p, isNotNull);
      expect(p!.payload, isEmpty);
    });
  });

  group('channel-secret-tail oracle', () {
    final Uint8List pt = Uint8List.fromList(utf8.encode('Meshmore @ public'));

    test('resolves the ZEROS tail from a synthetic capture', () {
      final Uint8List secret = Uint8List(kChannelSecretSize)
        ..setRange(0, 16, kPublicChannelPsk);
      final RfLog log = (MeshcoreFrameCodec.decode(_rfLogGrpTxt(secret, pt))
              as RfLogFrame)
          .log;
      final ChannelTailResult r = resolveChannelTail(
        psk: Uint8List.fromList(kPublicChannelPsk),
        knownPlaintext: pt,
        grpTxt: log.packet!.grpTxt!,
      );
      expect(r.resolved, isTrue);
      expect(r.match, ChannelTailHypothesis.zeros);
      expect(r.recoveredPlaintext, pt);
      expect(r.channelHashOk, isTrue);
    });

    test('resolves the PSK-REPEAT tail when that is how it was built', () {
      final Uint8List secret = Uint8List(kChannelSecretSize)
        ..setRange(0, 16, kPublicChannelPsk)
        ..setRange(16, 32, kPublicChannelPsk);
      final RfLog log = (MeshcoreFrameCodec.decode(_rfLogGrpTxt(secret, pt))
              as RfLogFrame)
          .log;
      final ChannelTailResult r = resolveChannelTail(
        psk: Uint8List.fromList(kPublicChannelPsk),
        knownPlaintext: pt,
        grpTxt: log.packet!.grpTxt!,
      );
      expect(r.match, ChannelTailHypothesis.pskRepeat);
    });

    test('wrong PSK → unresolved (no false positive)', () {
      final Uint8List secret = Uint8List(kChannelSecretSize)
        ..setRange(0, 16, kPublicChannelPsk);
      final RfLog log = (MeshcoreFrameCodec.decode(_rfLogGrpTxt(secret, pt))
              as RfLogFrame)
          .log;
      final ChannelTailResult r = resolveChannelTail(
        psk: Uint8List(16), // all-zero PSK ≠ real
        knownPlaintext: pt,
        grpTxt: log.packet!.grpTxt!,
      );
      expect(r.resolved, isFalse);
      expect(r.match, isNull);
    });
  });
}
