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

  group('CUSTOM_VARS — encode + decode', () {
    test('CMD_GET_CUSTOM_VARS encodes as bare opcode 0x28', () {
      expect(_toHex(MeshcoreFrameCodec.getCustomVars()), '28');
    });

    test('CMD_SET_CUSTOM_VAR encodes [opcode][name]:[value] (UTF-8)', () {
      final Uint8List frame = MeshcoreFrameCodec.setCustomVar(
        name: 'gps',
        value: '1',
      );
      // 0x29 + ASCII "gps:1"
      expect(_toHex(frame), '29${_toHex(Uint8List.fromList(utf8.encode("gps:1")))}');
    });

    test('CMD_SET_CUSTOM_VAR with gps_interval', () {
      final Uint8List frame = MeshcoreFrameCodec.setCustomVar(
        name: 'gps_interval',
        value: '30',
      );
      expect(_toHex(frame),
          '29${_toHex(Uint8List.fromList(utf8.encode("gps_interval:30")))}');
    });

    test('RESP_CODE_CUSTOM_VARS (0x15) decodes comma-separated payload', () {
      final BytesBuilder b = BytesBuilder()
        ..addByte(0x15)
        ..add(utf8.encode('gps:1,gps_interval:30'));
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(b.toBytes());
      expect(got, isA<CustomVarsFrame>());
      final Map<String, String> m = (got as CustomVarsFrame).values;
      expect(m['gps'], '1');
      expect(m['gps_interval'], '30');
      expect(m.length, 2);
    });

    test('empty CUSTOM_VARS payload → empty map', () {
      final MeshcoreInbound got =
          MeshcoreFrameCodec.decode(Uint8List.fromList(<int>[0x15]));
      expect(got, isA<CustomVarsFrame>());
      expect((got as CustomVarsFrame).values, isEmpty);
    });

    test('malformed CUSTOM_VARS entries are silently dropped', () {
      final BytesBuilder b = BytesBuilder()
        ..addByte(0x15)
        ..add(utf8.encode('gps:1,no_colon_here,gps_interval:30'));
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(b.toBytes());
      final Map<String, String> m = (got as CustomVarsFrame).values;
      expect(m, <String, String>{'gps': '1', 'gps_interval': '30'});
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

  group('PUSH_CODE_ACK (0x82) decode', () {
    test('decodes the 4-byte ack CRC (u32 LE)', () {
      // 0x82 + ack 0x12345678 little-endian = 78 56 34 12.
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(_hex('8278563412'));
      expect(got, isA<AckFrame>());
      expect((got as AckFrame).ackCrc, 0x12345678);
    });

    test('matches the MsgSent expectedAck tag for correlation', () {
      // MSG_SENT (0x06) flood=0 ack=0x12345678 timeout=1000ms.
      final MeshcoreInbound sent =
          MeshcoreFrameCodec.decode(_hex('060078563412e8030000'));
      final MeshcoreInbound ack =
          MeshcoreFrameCodec.decode(_hex('8278563412'));
      expect((sent as MsgSentFrame).sent.expectedAck,
          (ack as AckFrame).ackCrc);
    });

    test('short/empty payload decodes to ack 0 (no throw)', () {
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(_hex('82'));
      expect(got, isA<AckFrame>());
      expect((got as AckFrame).ackCrc, 0);
    });
  });

  group('CMD_SEND_TELEMETRY_REQ (0x27) encode', () {
    test('self-telemetry: 4-byte frame with three zero-pad bytes', () {
      final Uint8List got = MeshcoreFrameCodec.sendTelemetryReq();
      expect(got.length, 4);
      expect(got[0], 0x27);
      expect(got[1], 0);
      expect(got[2], 0);
      expect(got[3], 0);
    });

    test('peer-telemetry: 36-byte frame ends with the 32B pubkey', () {
      final Uint8List pub = Uint8List.fromList(
          List<int>.generate(32, (int i) => i + 1));
      final Uint8List got =
          MeshcoreFrameCodec.sendTelemetryReq(peerPubKey: pub);
      expect(got.length, 36);
      expect(got.sublist(0, 4), <int>[0x27, 0, 0, 0]);
      expect(got.sublist(4), pub);
    });
  });

  group('PUSH_CODE_TELEMETRY_RESPONSE (0x8B) decode', () {
    test('self-telemetry payload with GPS triplet', () {
      // 0x8B [reserved=0] [6B pubkey-prefix] [11B LPP GPS entry]
      final Uint8List frame = _hex(
          '8B' // opcode
          '00' // reserved
          'AABBCCDDEEFF' // pubkey6
          '0188' '06765F' 'F2960A' '0003E8'); // ch=1 GPS, 42.3519/-87.9094/10m
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(frame);
      expect(got, isA<TelemetryResponseFrame>());
      final TelemetryResponseFrame t = got as TelemetryResponseFrame;
      expect(_toHex(t.pubKeyPrefix), 'aabbccddeeff');
      expect(t.lppPayload.length, 11);
      final List<LppEntry> entries = decodeCayenneLpp(t.lppPayload);
      expect(entries.single.gps?.altMeters, closeTo(10.0, 1e-2));
    });

    test('empty LPP payload (no telemetry available) decodes safely', () {
      // 0x8B [reserved] [6B pubkey6] — no payload at all
      final Uint8List frame = _hex('8B00AABBCCDDEEFF');
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(frame);
      expect(got, isA<TelemetryResponseFrame>());
      expect((got as TelemetryResponseFrame).lppPayload, isEmpty);
    });

    test('truncated (missing some of the 6-byte pubkey) -> DecodeFailure', () {
      final Uint8List frame = _hex('8B00AABB');
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(frame);
      expect(got, isA<DecodeFailure>());
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
