import 'dart:typed_data';

/// Decoded `RESP_CODE_SELF_INFO` (0x05) — also the reply to APP_START.
///
/// Layout transcribed from `examples/companion_radio/MyMesh.cpp`
/// (pinned commit). Scaling: lat/lon are signed int32 ÷ 1e6; frequency
/// and bandwidth are uint32 ÷ 1000.
class SelfInfo {
  const SelfInfo({
    required this.advType,
    required this.txPowerDbm,
    required this.maxTxPowerDbm,
    required this.publicKey,
    required this.latitude,
    required this.longitude,
    required this.multiAcks,
    required this.advertLocPolicy,
    required this.telemetryModeRaw,
    required this.manualAddContacts,
    required this.frequencyMhz,
    required this.bandwidthKhz,
    required this.spreadingFactor,
    required this.codingRate,
    required this.name,
  });

  final int advType;
  final int txPowerDbm;
  final int maxTxPowerDbm;

  /// 32-byte Ed25519 public key.
  final Uint8List publicKey;

  /// Degrees (raw int32 ÷ 1e6).
  final double latitude;
  final double longitude;

  final int multiAcks;
  final int advertLocPolicy;
  final int telemetryModeRaw;
  final bool manualAddContacts;

  /// MHz (raw uint32 ÷ 1000).
  final double frequencyMhz;

  /// kHz (raw uint32 ÷ 1000).
  final double bandwidthKhz;

  final int spreadingFactor;
  final int codingRate;

  /// Device/node name (trailing UTF-8).
  final String name;

  @override
  String toString() => 'SelfInfo(name: $name, freq: ${frequencyMhz}MHz, '
      'bw: ${bandwidthKhz}kHz, sf: $spreadingFactor, cr: $codingRate)';
}
