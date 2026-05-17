import 'dart:math';
import 'dart:typed_data';

import 'package:meshcore/meshcore.dart';
import 'package:test/test.dart';

/// TC2-final hardening: the decode/parse/crypto surface must be
/// **total** — every input yields a value or a *controlled* error,
/// never an uncaught exception, hang, or crash. Deterministic
/// (fixed-seed RNG) so the gate is reproducible.
void main() {
  const int iterations = 4000;

  Uint8List randomBytes(Random r, int maxLen) {
    final int n = r.nextInt(maxLen + 1);
    final Uint8List b = Uint8List(n);
    for (int i = 0; i < n; i++) {
      b[i] = r.nextInt(256);
    }
    return b;
  }

  test('MeshcoreFrameCodec.decode is total (random + structured)', () {
    final Random r = Random(0xC0FFEE);
    for (int i = 0; i < iterations; i++) {
      // Half pure-random, half "valid opcode + random tail" so we
      // exercise every typed decoder's truncation paths.
      Uint8List frame = randomBytes(r, 300);
      if (i.isEven && frame.isNotEmpty) {
        const List<int> ops = <int>[
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, //
          0x09, 0x0A, 0x0C, 0x0D, 0x10, 0x11, 0x12, 0x80, 0x88,
        ];
        frame = Uint8List.fromList(frame);
        frame[0] = ops[r.nextInt(ops.length)];
      }
      final MeshcoreInbound out = MeshcoreFrameCodec.decode(frame);
      expect(out, isA<MeshcoreInbound>());
      if (out is DecodeFailure) {
        // The only failure kinds are structural.
        expect(
          out.error.kind,
          anyOf(DecodeErrorKind.empty, DecodeErrorKind.truncated),
        );
      }
    }
  });

  test('OtaPacket.parse never throws (null or valid)', () {
    final Random r = Random(0xBEEF);
    for (int i = 0; i < iterations; i++) {
      final OtaPacket? p = OtaPacket.parse(randomBytes(r, 250));
      if (p != null) {
        expect(p.payload, isA<Uint8List>());
        expect(p.hopCount, inInclusiveRange(0, 63));
      }
    }
  });

  test('macThenDecrypt never throws on garbage (null or bytes)', () {
    final Random r = Random(0x5EED);
    for (int i = 0; i < iterations; i++) {
      final Uint8List secret = randomBytes(r, 32);
      final Uint8List padded = Uint8List(32)
        ..setRange(0, secret.length.clamp(0, 32),
            secret.sublist(0, secret.length.clamp(0, 32)));
      final Uint8List? d = MeshcoreChannelCrypto.macThenDecrypt(
          padded, randomBytes(r, 80));
      if (d != null) expect(d.length % 16, 0);
    }
  });

  test('resolveChannelTail never throws on random GRP_TXT', () {
    final Random r = Random(0xA11CE);
    for (int i = 0; i < 1000; i++) {
      final ChannelTailResult res = resolveChannelTail(
        psk: randomBytes(r, 16),
        knownPlaintext: randomBytes(r, 24),
        grpTxt: GrpTxtPayload(
          channelHash: r.nextInt(256),
          macAndCiphertext: randomBytes(r, 64),
        ),
      );
      expect(res.resolved, isA<bool>());
    }
  });

  test('edPublicKeyToMontgomeryU: 32B out or controlled ArgumentError',
      () {
    final Random r = Random(0xED2519);
    for (int i = 0; i < 1500; i++) {
      final Uint8List pub = Uint8List(32);
      for (int j = 0; j < 32; j++) {
        pub[j] = r.nextInt(256);
      }
      try {
        final Uint8List u =
            MeshcoreIdentityCrypto.edPublicKeyToMontgomeryU(pub);
        expect(u.length, 32);
      } on ArgumentError {
        // Acceptable: degenerate point — a *controlled* error.
      }
    }
  });

  group('decode error taxonomy invariants', () {
    test('empty → DecodeFailure(empty)', () {
      final MeshcoreInbound f = MeshcoreFrameCodec.decode(Uint8List(0));
      expect(f, isA<DecodeFailure>());
      expect((f as DecodeFailure).error.kind, DecodeErrorKind.empty);
    });

    test('truncated typed frame → DecodeFailure(truncated)', () {
      // CONTACTS_START needs a u32 count; give 2 bytes.
      final MeshcoreInbound f =
          MeshcoreFrameCodec.decode(Uint8List.fromList(<int>[0x02, 0x01]));
      expect(f, isA<DecodeFailure>());
      expect((f as DecodeFailure).error.kind, DecodeErrorKind.truncated);
    });

    test('unknown opcode → UnsupportedFrame (NOT a failure)', () {
      final MeshcoreInbound f = MeshcoreFrameCodec.decode(
          Uint8List.fromList(<int>[0x7E, 0xDE, 0xAD]));
      expect(f, isA<UnsupportedFrame>());
      expect((f as UnsupportedFrame).opcode, 0x7E);
      expect(f.raw, <int>[0x7E, 0xDE, 0xAD]);
    });
  });
}
