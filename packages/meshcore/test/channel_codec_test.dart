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

String _toHex(Uint8List b) =>
    b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _encodeByName(String name, Map<String, Object?> a) {
  switch (name) {
    case 'sendChannelTextMessage':
      return MeshcoreFrameCodec.sendChannelTextMessage(
        channelIdx: a['channelIdx']! as int,
        timestamp: a['timestamp']! as int,
        text: a['text']! as String,
      );
    case 'getChannel':
      return MeshcoreFrameCodec.getChannel(a['channelIdx']! as int);
    default:
      fail('unknown encoder "$name"');
  }
}

void main() {
  group('M2 channel vectors (vectors/m2_channel_frames.json)', () {
    final Map<String, Object?> doc = jsonDecode(
            File('test/vectors/m2_channel_frames.json').readAsStringSync())
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
        switch (e['type']! as String) {
          case 'MsgSentFrame':
            expect(got, isA<MsgSentFrame>());
            final MsgSent m = (got as MsgSentFrame).sent;
            expect(m.isFlood, e['isFlood']);
            expect(m.expectedAck, e['expectedAck']);
            expect(m.estTimeoutMs, e['estTimeoutMs']);
          case 'ChannelMessageFrame':
            expect(got, isA<ChannelMessageFrame>());
            final ChannelMessage m = (got as ChannelMessageFrame).message;
            expect(m.channelIdx, e['channelIdx']);
            expect(m.pathLen, e['pathLen']);
            expect(m.isFlood, e['isFlood']);
            expect(m.txtType, e['txtType']);
            expect(m.timestamp, e['timestamp']);
            expect(m.text, e['text']);
            expect(m.isV3, e['isV3']);
            expect(m.snrDb, e['snrDb']);
          default:
            fail('unhandled expected type ${e['type']}');
        }
      });
    }
  });

  group('SET_CHANNEL (0x20) encode — programmatic golden', () {
    test('50-byte frame: idx + name(32) + psk(16)', () {
      final List<int> psk = List<int>.generate(16, (int i) => i);
      final Uint8List f = MeshcoreFrameCodec.setChannel(
        channelIdx: 1,
        name: 'public',
        psk: psk,
      );
      expect(f.length, 50, reason: '1+1+32+16');
      expect(f[0], 0x20);
      expect(f[1], 1);
      // name region: "public" then NUL padding to 32.
      expect(utf8.decode(f.sublist(2, 2 + 6)), 'public');
      expect(f.sublist(2 + 6, 2 + 32), List<int>.filled(26, 0));
      // psk region.
      expect(f.sublist(34, 50), psk);
    });

    test('over-long name truncates, short psk zero-pads', () {
      final Uint8List f = MeshcoreFrameCodec.setChannel(
        channelIdx: 0,
        name: 'X' * 40,
        psk: <int>[1, 2, 3],
      );
      expect(f.length, 50);
      expect(f.sublist(2, 34), List<int>.filled(32, 0x58)); // 'X'
      expect(f.sublist(34, 50), <int>[1, 2, 3, ...List<int>.filled(13, 0)]);
    });
  });

  group('CHANNEL_INFO (0x12) decode — programmatic golden', () {
    test('idx + name + 16-byte psk', () {
      final List<int> psk = List<int>.generate(16, (int i) => i + 1);
      final BytesBuilder b = BytesBuilder()
        ..addByte(0x12)
        ..addByte(7);
      final Uint8List name = Uint8List(32);
      name.setRange(0, 6, utf8.encode('public'));
      b.add(name);
      b.add(Uint8List.fromList(psk));
      final Uint8List frame = b.toBytes();
      expect(frame.length, 50);

      final MeshcoreInbound got = MeshcoreFrameCodec.decode(frame);
      expect(got, isA<ChannelInfoFrame>());
      final ChannelInfo ci = (got as ChannelInfoFrame).info;
      expect(ci.channelIdx, 7);
      expect(ci.name, 'public');
      expect(ci.psk, psk);
    });
  });

  group('channel decode totality', () {
    test('truncated MSG_SENT -> DecodeFailure(truncated)', () {
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(_hex('060178'));
      expect(got, isA<DecodeFailure>());
      expect((got as DecodeFailure).error.kind, DecodeErrorKind.truncated);
    });

    test('truncated V3 channel msg -> DecodeFailure(truncated)', () {
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(_hex('111e00'));
      expect(got, isA<DecodeFailure>());
      expect((got as DecodeFailure).error.kind, DecodeErrorKind.truncated);
    });

    test('empty-text channel msg decodes with text ""', () {
      // [08][ch0][path0][txt0][ts 0] and nothing after.
      final MeshcoreInbound got =
          MeshcoreFrameCodec.decode(_hex('0800000000000000'));
      expect(got, isA<ChannelMessageFrame>());
      expect((got as ChannelMessageFrame).message.text, '');
    });
  });
}
