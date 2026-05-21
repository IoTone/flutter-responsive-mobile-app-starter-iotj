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

String _toHex(Uint8List b) =>
    b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _encodeByName(String name, Map<String, Object?> args) {
  switch (name) {
    case 'appStart':
      return MeshcoreFrameCodec.appStart(appName: args['appName']! as String);
    case 'getContacts':
      return MeshcoreFrameCodec.getContacts(since: args['since'] as int?);
    case 'getDeviceTime':
      return MeshcoreFrameCodec.getDeviceTime();
    case 'setDeviceTime':
      return MeshcoreFrameCodec.setDeviceTime(args['unixSeconds']! as int);
    case 'syncNextMessage':
      return MeshcoreFrameCodec.syncNextMessage();
    default:
      fail('unknown encoder "$name" in vectors');
  }
}

void main() {
  group('M1 conformance vectors (vectors/m1_frames.json)', () {
    final File f = File('test/vectors/m1_frames.json');
    final Map<String, Object?> doc =
        jsonDecode(f.readAsStringSync()) as Map<String, Object?>;

    final List<Object?> encodeCases = doc['encode']! as List<Object?>;
    for (final Object? raw in encodeCases) {
      final Map<String, Object?> c = raw! as Map<String, Object?>;
      test('encode: ${c['name']}', () {
        final Uint8List got = _encodeByName(
          c['encoder']! as String,
          (c['args'] as Map<String, Object?>?) ?? const <String, Object?>{},
        );
        expect(_toHex(got), c['hex']! as String);
      });
    }

    final List<Object?> decodeCases = doc['decode']! as List<Object?>;
    for (final Object? raw in decodeCases) {
      final Map<String, Object?> c = raw! as Map<String, Object?>;
      test('decode: ${c['name']}', () {
        final MeshcoreInbound got =
            MeshcoreFrameCodec.decode(_hex(c['hex']! as String));
        final Map<String, Object?> exp = c['expect']! as Map<String, Object?>;
        switch (exp['type']! as String) {
          case 'OkFrame':
            expect(got, isA<OkFrame>());
            expect((got as OkFrame).value, exp['value']);
          case 'ErrorFrame':
            expect(got, isA<ErrorFrame>());
            expect((got as ErrorFrame).code, exp['code']);
          case 'ContactsStartFrame':
            expect(got, isA<ContactsStartFrame>());
            expect((got as ContactsStartFrame).count, exp['count']);
          case 'EndOfContactsFrame':
            expect(got, isA<EndOfContactsFrame>());
            expect((got as EndOfContactsFrame).mostRecentLastMod,
                exp['mostRecentLastMod']);
          case 'CurrentTimeFrame':
            expect(got, isA<CurrentTimeFrame>());
            expect((got as CurrentTimeFrame).unixSeconds, exp['unixSeconds']);
          case 'NoMoreMessagesFrame':
            expect(got, isA<NoMoreMessagesFrame>());
          case 'UnsupportedFrame':
            expect(got, isA<UnsupportedFrame>());
            expect((got as UnsupportedFrame).opcode, exp['opcode']);
          default:
            fail('unhandled expected type ${exp['type']}');
        }
      });
    }
  });

  group('SELF_INFO (0x05) decode — programmatic golden', () {
    test('all fields, scaling, trailing name', () {
      final BytesBuilder b = BytesBuilder();
      b.addByte(0x05); // opcode
      b.addByte(0x01); // advType
      b.addByte(14); // txPower
      b.addByte(22); // maxTxPower
      b.add(Uint8List.fromList(List<int>.generate(32, (int i) => i))); // pubkey
      void le32(int v) =>
          b.add((ByteData(4)..setInt32(0, v, Endian.little)).buffer.asUint8List());
      le32(1000000); // lat raw -> 1.0
      le32(-2000000); // lon raw -> -2.0
      b.addByte(2); // multiAcks
      b.addByte(1); // advertLocPolicy
      b.addByte(0); // telemetry
      b.addByte(1); // manualAddContacts -> true
      void leu32(int v) =>
          b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
      leu32(915000); // frequency -> 915.0 MHz
      leu32(250000); // bandwidth -> 250.0 kHz
      b.addByte(7); // sf
      b.addByte(5); // cr
      b.add(utf8.encode('T1000-E')); // name

      final Uint8List frame = b.toBytes();
      // 1 + 3 + 32 + 4 + 4 + 4 + 4 + 2 = 58 header bytes, then name.
      expect(frame.length, 58 + 'T1000-E'.length);

      final MeshcoreInbound got = MeshcoreFrameCodec.decode(frame);
      expect(got, isA<SelfInfoFrame>());
      final SelfInfo s = (got as SelfInfoFrame).selfInfo;
      expect(s.advType, 1);
      expect(s.txPowerDbm, 14);
      expect(s.maxTxPowerDbm, 22);
      expect(s.publicKey, List<int>.generate(32, (int i) => i));
      expect(s.latitude, closeTo(1.0, 1e-9));
      expect(s.longitude, closeTo(-2.0, 1e-9));
      expect(s.multiAcks, 2);
      expect(s.advertLocPolicy, 1);
      expect(s.telemetryModeRaw, 0);
      expect(s.manualAddContacts, isTrue);
      expect(s.frequencyMhz, closeTo(915.0, 1e-9));
      expect(s.bandwidthKhz, closeTo(250.0, 1e-9));
      expect(s.spreadingFactor, 7);
      expect(s.codingRate, 5);
      expect(s.name, 'T1000-E');
    });
  });

  group('CONTACT (0x03) decode — programmatic golden', () {
    test('148-byte frame, fields, active path slice', () {
      final BytesBuilder b = BytesBuilder();
      b.addByte(0x03); // opcode
      b.add(Uint8List.fromList(
          List<int>.generate(32, (int i) => i + 1))); // pubkey
      b.addByte(2); // type
      b.addByte(0); // flags
      b.addByte(3); // outPathLen
      final Uint8List path = Uint8List(64);
      path[0] = 0xAA;
      path[1] = 0xBB;
      path[2] = 0xCC;
      b.add(path); // outPath (64)
      final Uint8List name = Uint8List(32);
      name.setRange(0, 'Repeater-1'.length, utf8.encode('Repeater-1'));
      b.add(name); // name (32, NUL-padded)
      void leu32(int v) =>
          b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
      void le32(int v) =>
          b.add((ByteData(4)..setInt32(0, v, Endian.little)).buffer.asUint8List());
      leu32(0x66000001); // lastAdvertTs
      le32(1000000); // lat -> 1.0
      le32(-2000000); // lon -> -2.0
      leu32(255); // lastMod

      final Uint8List frame = b.toBytes();
      expect(frame.length, 148, reason: 'CONTACT frame must be 148 bytes');

      final MeshcoreInbound got = MeshcoreFrameCodec.decode(frame);
      expect(got, isA<ContactFrame>());
      final Contact ct = (got as ContactFrame).contact;
      expect(ct.publicKey, List<int>.generate(32, (int i) => i + 1));
      expect(ct.type, 2);
      expect(ct.flags, 0);
      expect(ct.outPathLen, 3);
      expect(ct.outPath.length, 64);
      expect(ct.activePath, <int>[0xAA, 0xBB, 0xCC]);
      expect(ct.name, 'Repeater-1');
      expect(ct.lastAdvertTimestamp, 0x66000001);
      expect(ct.latitude, closeTo(1.0, 1e-9));
      expect(ct.longitude, closeTo(-2.0, 1e-9));
      expect(ct.lastMod, 255);
    });
  });

  group('decode is total (never throws)', () {
    test('empty frame -> DecodeFailure(empty)', () {
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(Uint8List(0));
      expect(got, isA<DecodeFailure>());
      expect((got as DecodeFailure).error.kind, DecodeErrorKind.empty);
    });

    test('truncated CONTACTS_START -> DecodeFailure(truncated)', () {
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(_hex('020100'));
      expect(got, isA<DecodeFailure>());
      final DecodeFailure df = got as DecodeFailure;
      expect(df.error.kind, DecodeErrorKind.truncated);
      expect(df.error.opcode, 0x02);
    });

    test('truncated SELF_INFO (missing name region) -> truncated', () {
      // opcode + advType only.
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(_hex('0501'));
      expect(got, isA<DecodeFailure>());
      expect((got as DecodeFailure).error.kind, DecodeErrorKind.truncated);
    });

    test('SELF_INFO with empty trailing name decodes (name = "")', () {
      final BytesBuilder b = BytesBuilder()..addByte(0x05);
      b.add(Uint8List(57)); // exactly the 57 fixed bytes after opcode
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(b.toBytes());
      expect(got, isA<SelfInfoFrame>());
      expect((got as SelfInfoFrame).selfInfo.name, '');
    });
  });

  group('MSGS_WAITING (0x83) decode', () {
    test('bare opcode -> MessagesWaitingFrame(count: null)', () {
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(_hex('83'));
      expect(got, isA<MessagesWaitingFrame>());
      expect((got as MessagesWaitingFrame).count, isNull);
    });

    test('opcode + count byte -> MessagesWaitingFrame(count)', () {
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(_hex('8303'));
      expect(got, isA<MessagesWaitingFrame>());
      expect((got as MessagesWaitingFrame).count, 3);
    });
  });
}
