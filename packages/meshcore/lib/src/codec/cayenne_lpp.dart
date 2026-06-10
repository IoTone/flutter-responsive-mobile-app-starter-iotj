// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

/// CayenneLPP (Low Power Payload) decoder — big-endian, standard
/// type-code table per MyDevices spec. Used to interpret the payload
/// of MeshCore's `PUSH_CODE_TELEMETRY_RESPONSE` (0x8B), which carries
/// the bytes produced by `CayenneLPP::addGPS/addTemperature/...` on
/// the device side.
///
/// The MeshCore firmware uses the stock Adafruit_CayenneLPP library
/// (verified at companion-v1.15.0 commit dee3e26ac0); the wire format
/// is the same as anywhere else CayenneLPP shows up.

/// Standard CayenneLPP IPSO type codes — the full ElectronicCats
/// CayenneLPP table (the library MeshCore vendors: `electroniccats/
/// CayenneLPP @ 1.6.1`), not just the base MyDevices set. The extended
/// types matter in practice: the companion firmware's telemetry
/// response *leads* with `addVoltage` (0x74, battery), so a decoder
/// without the extended table stalls on entry #1 and drops everything
/// behind it (GPS, luminosity, temperature…).
abstract final class LppType {
  static const int digitalInput = 0x00;
  static const int digitalOutput = 0x01;
  static const int analogInput = 0x02;
  static const int analogOutput = 0x03;
  static const int genericSensor = 0x64; // 100
  static const int illuminance = 0x65; // 101 — LPP_LUMINOSITY
  static const int presence = 0x66; // 102
  static const int temperature = 0x67; // 103
  static const int humidity = 0x68; // 104
  static const int accelerometer = 0x71; // 113
  static const int barometer = 0x73; // 115
  static const int voltage = 0x74; // 116 — battery, leads telemetry
  static const int current = 0x75; // 117
  static const int frequency = 0x76; // 118
  static const int percentage = 0x78; // 120
  static const int altitude = 0x79; // 121
  static const int concentration = 0x7D; // 125
  static const int power = 0x80; // 128
  static const int distance = 0x82; // 130
  static const int energy = 0x83; // 131
  static const int direction = 0x84; // 132
  static const int unixTime = 0x85; // 133
  static const int gyrometer = 0x86; // 134
  static const int colour = 0x87; // 135
  static const int gpsLocation = 0x88; // 136
  static const int switchState = 0x8E; // 142
}

/// Payload size in bytes for each LPP type. The CayenneLPP wire format
/// has NO per-entry length prefix — to advance past an entry we have to
/// know its size from the type byte alone. An unknown type means we
/// can't safely skip it. (Sizes per ElectronicCats `LPP_*_SIZE`.)
const Map<int, int> _lppPayloadSize = <int, int>{
  LppType.digitalInput: 1,
  LppType.digitalOutput: 1,
  LppType.analogInput: 2,
  LppType.analogOutput: 2,
  LppType.genericSensor: 4,
  LppType.illuminance: 2,
  LppType.presence: 1,
  LppType.temperature: 2,
  LppType.humidity: 1,
  LppType.accelerometer: 6,
  LppType.barometer: 2,
  LppType.voltage: 2,
  LppType.current: 2,
  LppType.frequency: 4,
  LppType.percentage: 1,
  LppType.altitude: 2,
  LppType.concentration: 2,
  LppType.power: 2,
  LppType.distance: 4,
  LppType.energy: 4,
  LppType.direction: 2,
  LppType.unixTime: 4,
  LppType.gyrometer: 6,
  LppType.colour: 3,
  LppType.gpsLocation: 9,
  LppType.switchState: 1,
};

/// One decoded CayenneLPP entry — channel/type plus interpreted values.
///
/// [values] is the *physical-unit* form (after the type-specific
/// divisor); raw bytes are kept in [rawPayload] for callers that want
/// to compute their own interpretation. For unknown types [values] is
/// empty.
class LppEntry {
  const LppEntry({
    required this.channel,
    required this.type,
    required this.values,
    required this.rawPayload,
  });

  /// LPP channel byte (e.g. `TELEM_CHANNEL_SELF = 1`).
  final int channel;

  /// LPP type byte (e.g. `LppType.gpsLocation = 0x88`).
  final int type;

  /// Decoded values in physical units. Cardinality depends on type:
  /// GPS = [lat, lon, alt], accelerometer = [x, y, z], scalar types = [v].
  final List<double> values;

  /// Raw payload bytes (excluding the 2-byte channel/type header).
  final Uint8List rawPayload;

  /// GPS triplet helper. Returns `(lat, lon, altMeters)` if this entry
  /// is a GPS location, else null. Altitude can still be 0 for chips
  /// with no barometric/GPS-altitude data — caller decides how to
  /// treat that.
  ({double lat, double lon, double altMeters})? get gps {
    if (type != LppType.gpsLocation || values.length < 3) return null;
    return (lat: values[0], lon: values[1], altMeters: values[2]);
  }
}

/// Decode a CayenneLPP byte buffer into a list of [LppEntry] records.
///
/// Big-endian throughout. Stops cleanly at end-of-buffer. If an
/// unknown type byte is encountered or the buffer is truncated mid-
/// entry, parsing stops and the entries decoded so far are returned —
/// callers should treat the absence of an expected entry as "not
/// reported" rather than as a parse failure.
List<LppEntry> decodeCayenneLpp(Uint8List bytes) {
  final List<LppEntry> result = <LppEntry>[];
  int i = 0;
  while (i + 2 <= bytes.length) {
    final int channel = bytes[i];
    final int type = bytes[i + 1];
    final int? size = _lppPayloadSize[type];
    if (size == null) break; // unknown type — can't advance safely
    if (i + 2 + size > bytes.length) break; // truncated
    final Uint8List raw =
        Uint8List.sublistView(bytes, i + 2, i + 2 + size);
    result.add(LppEntry(
      channel: channel,
      type: type,
      values: _decodeValues(type, raw),
      rawPayload: raw,
    ));
    i += 2 + size;
  }
  return result;
}

List<double> _decodeValues(int type, Uint8List raw) {
  switch (type) {
    case LppType.digitalInput:
    case LppType.digitalOutput:
    case LppType.presence:
    case LppType.percentage:
    case LppType.switchState:
      return <double>[raw[0].toDouble()];
    case LppType.humidity:
      return <double>[raw[0] / 2.0];
    case LppType.analogInput:
    case LppType.analogOutput:
      return <double>[_s16be(raw, 0) / 100.0];
    case LppType.temperature:
      return <double>[_s16be(raw, 0) / 10.0];
    case LppType.altitude:
      return <double>[_s16be(raw, 0).toDouble()];
    case LppType.illuminance:
    case LppType.concentration:
    case LppType.power:
    case LppType.direction:
      return <double>[_u16be(raw, 0).toDouble()];
    case LppType.barometer:
      return <double>[_u16be(raw, 0) / 10.0];
    case LppType.voltage:
      return <double>[_u16be(raw, 0) / 100.0];
    case LppType.current:
      return <double>[_u16be(raw, 0) / 1000.0];
    case LppType.genericSensor:
    case LppType.frequency:
    case LppType.unixTime:
      return <double>[_u32be(raw, 0).toDouble()];
    case LppType.distance:
    case LppType.energy:
      return <double>[_u32be(raw, 0) / 1000.0];
    case LppType.colour:
      return <double>[
        raw[0].toDouble(),
        raw[1].toDouble(),
        raw[2].toDouble(),
      ];
    case LppType.accelerometer:
      return <double>[
        _s16be(raw, 0) / 1000.0,
        _s16be(raw, 2) / 1000.0,
        _s16be(raw, 4) / 1000.0,
      ];
    case LppType.gyrometer:
      return <double>[
        _s16be(raw, 0) / 100.0,
        _s16be(raw, 2) / 100.0,
        _s16be(raw, 4) / 100.0,
      ];
    case LppType.gpsLocation:
      return <double>[
        _s24be(raw, 0) / 10000.0, // lat
        _s24be(raw, 3) / 10000.0, // lon
        _s24be(raw, 6) / 100.0, // alt
      ];
    default:
      return const <double>[];
  }
}

int _u16be(Uint8List b, int off) => (b[off] << 8) | b[off + 1];

int _u32be(Uint8List b, int off) =>
    (b[off] << 24) | (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3];

int _s16be(Uint8List b, int off) {
  final int v = _u16be(b, off);
  return v >= 0x8000 ? v - 0x10000 : v;
}

int _s24be(Uint8List b, int off) {
  final int v = (b[off] << 16) | (b[off + 1] << 8) | b[off + 2];
  return v >= 0x800000 ? v - 0x1000000 : v;
}
