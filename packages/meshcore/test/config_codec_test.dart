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

Uint8List _encode(String n, Map<String, Object?> a) {
  switch (n) {
    case 'setRadioParams':
      return MeshcoreFrameCodec.setRadioParams(RadioParams(
        frequencyMhz: (a['freq']! as num).toDouble(),
        bandwidthKhz: (a['bw']! as num).toDouble(),
        spreadingFactor: a['sf']! as int,
        codingRate: a['cr']! as int,
        repeat: a['repeat'] as int?,
      ));
    case 'setRadioTxPower':
      return MeshcoreFrameCodec.setRadioTxPower(a['dbm']! as int);
    case 'setAdvertLatLon':
      return MeshcoreFrameCodec.setAdvertLatLon(
        latitudeMicros: a['latMicros']! as int,
        longitudeMicros: a['lonMicros']! as int,
        altitudeMicros: a['altMicros'] as int?,
      );
    case 'setOtherParams':
      return MeshcoreFrameCodec.setOtherParams(
        manualAddContacts: a['manualAddContacts']! as int,
        telemetryModePacked: a['telemetryModePacked']! as int,
        advertLocPolicy: a['advertLocPolicy'] as int?,
        multiAcks: a['multiAcks'] as int?,
      );
    case 'setTuningParams':
      return MeshcoreFrameCodec.setTuningParams(
        rxDelayBaseSeconds: (a['rxDelayBaseSeconds']! as num).toDouble(),
        airtimeFactor: (a['airtimeFactor']! as num).toDouble(),
      );
    case 'deviceQuery':
      return MeshcoreFrameCodec.deviceQuery(
          appTargetVer: a['appTargetVer']! as int);
    case 'getBatteryStorage':
      return MeshcoreFrameCodec.getBatteryStorage();
    default:
      fail('unknown encoder "$n"');
  }
}

void main() {
  group('M4 config vectors (vectors/m4_config_frames.json)', () {
    final Map<String, Object?> doc = jsonDecode(
            File('test/vectors/m4_config_frames.json').readAsStringSync())
        as Map<String, Object?>;

    for (final Object? raw in doc['encode']! as List<Object?>) {
      final Map<String, Object?> c = raw! as Map<String, Object?>;
      test('encode: ${c['name']}', () {
        final Uint8List got = _encode(c['encoder']! as String,
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
        expect(got, isA<BatteryStorageFrame>());
        final BatteryStorage b = (got as BatteryStorageFrame).battery;
        expect(b.batteryMillivolts, e['batteryMillivolts']);
        expect(b.storageUsedKb, e['storageUsedKb']);
        expect(b.storageTotalKb, e['storageTotalKb']);
      });
    }
  });

  group('DEVICE_INFO (0x0D) decode — programmatic golden', () {
    test('82-byte frame, fixed string fields, max_contacts ×2', () {
      Uint8List cstr(String s, int n) {
        final Uint8List buf = Uint8List(n);
        buf.setRange(0, s.length, utf8.encode(s));
        return buf;
      }

      final BytesBuilder b = BytesBuilder()
        ..addByte(0x0D)
        ..addByte(10) // fw ver code
        ..addByte(50) // max_contacts / 2  -> 100
        ..addByte(8) // max group channels
        ..add((ByteData(4)..setUint32(0, 123456, Endian.little))
            .buffer
            .asUint8List())
        ..add(cstr('2026-05-01', 12))
        ..add(cstr('IoTone Japan', 40))
        ..add(cstr('1.15.0', 20))
        ..addByte(0) // client_repeat
        ..addByte(1); // path_hash_mode

      final Uint8List frame = b.toBytes();
      expect(frame.length, 82, reason: '1+1+1+1+4+12+40+20+1+1');

      final MeshcoreInbound got = MeshcoreFrameCodec.decode(frame);
      expect(got, isA<DeviceInfoFrame>());
      final DeviceInfo d = (got as DeviceInfoFrame).info;
      expect(d.firmwareVerCode, 10);
      expect(d.maxContacts, 100);
      expect(d.maxGroupChannels, 8);
      expect(d.blePin, 123456);
      expect(d.firmwareBuildDate, '2026-05-01');
      expect(d.manufacturer, 'IoTone Japan');
      expect(d.firmwareVersion, '1.15.0');
      expect(d.clientRepeat, 0);
      expect(d.pathHashMode, 1);
    });
  });

  group('config decode totality', () {
    test('truncated BATT_AND_STORAGE -> DecodeFailure(truncated)', () {
      final MeshcoreInbound got = MeshcoreFrameCodec.decode(_hex('0c0410'));
      expect(got, isA<DecodeFailure>());
      expect((got as DecodeFailure).error.kind, DecodeErrorKind.truncated);
    });

    test('truncated DEVICE_INFO -> DecodeFailure(truncated)', () {
      final MeshcoreInbound got =
          MeshcoreFrameCodec.decode(_hex('0d0a3208'));
      expect(got, isA<DecodeFailure>());
      expect((got as DecodeFailure).error.kind, DecodeErrorKind.truncated);
    });
  });

  group('SET_RADIO_PARAMS scaling round-trips against SELF_INFO', () {
    test('encoded freq/bw decode back via the SELF_INFO scale', () {
      final Uint8List f = MeshcoreFrameCodec.setRadioParams(const RadioParams(
        frequencyMhz: 868.5,
        bandwidthKhz: 125.0,
        spreadingFactor: 9,
        codingRate: 6,
      ));
      // [0B][freq u32][bw u32][sf][cr]
      final ByteData d = ByteData.sublistView(f);
      final int freqRaw = d.getUint32(1, Endian.little);
      final int bwRaw = d.getUint32(5, Endian.little);
      expect(freqRaw / 1000.0, closeTo(868.5, 1e-9));
      expect(bwRaw / 1000.0, closeTo(125.0, 1e-9));
      expect(f[9], 9);
      expect(f[10], 6);
    });
  });
}
