// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

/// Decoded `RESP_CODE_CONTACT` (0x03).
///
/// Fixed 148-byte frame, layout transcribed from
/// `examples/companion_radio/MyMesh.cpp` (pinned commit):
///
/// ```
/// [0]        0x03
/// [1..32]    pub_key            (32, PUB_KEY_SIZE)
/// [33]       type
/// [34]       flags
/// [35]       out_path_len
/// [36..99]   out_path           (64, MAX_PATH_SIZE)
/// [100..131] name               (32)
/// [132..135] last_advert_ts     (uint32 LE)
/// [136..139] gps_lat            (int32  LE, ÷1e6)
/// [140..143] gps_lon            (int32  LE, ÷1e6)
/// [144..147] lastmod            (uint32 LE)
/// ```
class Contact {
  const Contact({
    required this.publicKey,
    required this.type,
    required this.flags,
    required this.outPathLen,
    required this.outPath,
    required this.name,
    required this.lastAdvertTimestamp,
    required this.latitudeMicros,
    required this.longitudeMicros,
    required this.lastMod,
  });

  /// 32-byte Ed25519 public key (full contact identity).
  final Uint8List publicKey;
  final int type;
  final int flags;

  /// Number of valid hops in [outPath] (the buffer is always 64 bytes).
  final int outPathLen;
  final Uint8List outPath;

  final String name;

  /// Unix seconds of the contact's last advertisement.
  final int lastAdvertTimestamp;

  /// Raw signed micro-degrees (the on-wire int32). Kept raw so a
  /// decoded contact re-encodes byte-exactly via ADD_UPDATE_CONTACT.
  final int latitudeMicros;
  final int longitudeMicros;

  /// Degrees (raw ÷ 1e6).
  double get latitude => latitudeMicros / 1e6;
  double get longitude => longitudeMicros / 1e6;

  /// Server-side modification counter used for incremental contact sync.
  final int lastMod;

  /// The hops actually in use (`outPath[0..outPathLen)`).
  Uint8List get activePath =>
      Uint8List.sublistView(outPath, 0, outPathLen.clamp(0, outPath.length));

  // --- `flags` bit layout (MeshCore companion firmware) ---------------
  // The firmware reads telemetry permission as `cp = flags >> 1`, then
  // `cp & TELEM_PERM_{BASE=0x01,LOCATION=0x02,ENVIRONMENT=0x04}` — so the
  // permission bits live one position up from the LSB favourite bit.
  // (Source: examples/companion_radio/MyMesh.cpp onContactRequest +
  // src/helpers/SensorManager.h.)
  static const int flagFavourite = 0x01;
  static const int flagTelemBase = 0x02;
  static const int flagTelemLocation = 0x04;
  static const int flagTelemEnvironment = 0x08;

  /// This contact may request **base** (battery) telemetry from us when
  /// the device telemetry mode is "Contacts" (ALLOW_FLAGS).
  bool get allowsTelemBase => flags & flagTelemBase != 0;
  bool get allowsTelemLocation => flags & flagTelemLocation != 0;
  bool get allowsTelemEnvironment => flags & flagTelemEnvironment != 0;
  bool get isDeviceFavourite => flags & flagFavourite != 0;

  Contact copyWith({int? flags}) => Contact(
        publicKey: publicKey,
        type: type,
        flags: flags ?? this.flags,
        outPathLen: outPathLen,
        outPath: outPath,
        name: name,
        lastAdvertTimestamp: lastAdvertTimestamp,
        latitudeMicros: latitudeMicros,
        longitudeMicros: longitudeMicros,
        lastMod: lastMod,
      );

  @override
  String toString() =>
      'Contact(name: $name, type: $type, pathLen: $outPathLen, '
      'lastMod: $lastMod)';
}
