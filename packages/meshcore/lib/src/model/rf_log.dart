import 'dart:typed_data';

import 'ota_packet.dart';

/// Decoded `PUSH_CODE_LOG_RX_DATA` (0x88).
///
/// Firmware (`MyMesh.cpp::logRxRaw`, pinned commit):
/// `[0x88][SNR×4 int8][RSSI int8][raw OTA packet …]`. The raw bytes
/// are the **full received over-the-air packet** (header + path +
/// encrypted payload) — the basis for the M6 interop fixtures that
/// close the channel-secret-tail open item.
class RfLog {
  const RfLog({
    required this.snrDb,
    required this.rssi,
    required this.raw,
  });

  final double snrDb;
  final int rssi;

  /// The full OTA packet bytes. Parse with [OtaPacket.parse].
  final Uint8List raw;

  OtaPacket? get packet => OtaPacket.parse(raw);

  @override
  String toString() =>
      'RfLog(snr: $snrDb, rssi: $rssi, raw: ${raw.length}B)';
}
