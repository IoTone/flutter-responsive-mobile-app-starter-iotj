// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

/// Decoded `RESP_CODE_CHANNEL_INFO` (0x12) — reply to GET_CHANNEL.
///
/// ```
/// [12][ch_idx][name 32B NUL-padded][secret 16B]
/// ```
/// Note: the companion link only conveys 16 bytes of the channel
/// secret (the AES-128 PSK). The firmware's full HMAC key is the
/// 32-byte `GroupChannel.secret`; see [kChannelSecretSize].
class ChannelInfo {
  const ChannelInfo({
    required this.channelIdx,
    required this.name,
    required this.psk,
  });

  final int channelIdx;
  final String name;

  /// The 16-byte channel pre-shared key (AES-128 key) as carried by
  /// the companion protocol.
  final Uint8List psk;

  @override
  String toString() => 'ChannelInfo(idx: $channelIdx, name: "$name")';
}

/// Decoded `RESP_CODE_SENT` (0x06) — send confirmation.
///
/// ```
/// [06][flood_flag][expected_ack u32 LE][est_timeout_ms u32 LE]
/// ```
class MsgSent {
  const MsgSent({
    required this.isFlood,
    required this.expectedAck,
    required this.estTimeoutMs,
  });

  /// True = flood routed, false = direct.
  final bool isFlood;

  /// Tag the device will report back in the matching ACK push.
  final int expectedAck;

  /// Estimated round-trip timeout in milliseconds.
  final int estTimeoutMs;

  @override
  String toString() =>
      'MsgSent(${isFlood ? 'flood' : 'direct'}, ack: $expectedAck, '
      'timeout: ${estTimeoutMs}ms)';
}
