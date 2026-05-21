// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
/// A received channel (group) text message.
///
/// Unifies `RESP_CODE_CHANNEL_MSG_RECV` (0x08) and its V3 variant
/// (0x11). [snrDb] is null for the legacy 0x08 frame and set for V3.
///
/// Layouts (from `examples/companion_radio/MyMesh.cpp`, pinned commit):
/// ```
/// 0x08: [08][ch_idx][path_len][txt_type][ts u32 LE][text…]
/// 0x11: [11][snr*4 i8][rsvd][rsvd][ch_idx][path_len][txt_type]
///       [ts u32 LE][text…]
/// ```
/// `path_len == 0xFF` means the message arrived via flood.
class ChannelMessage {
  const ChannelMessage({
    required this.channelIdx,
    required this.pathLen,
    required this.txtType,
    required this.timestamp,
    required this.text,
    required this.isV3,
    this.snrDb,
  });

  final int channelIdx;

  /// Raw hop count, or `0xFF` for flood (see [isFlood]).
  final int pathLen;
  final int txtType;

  /// Sender timestamp (unix seconds).
  final int timestamp;
  final String text;

  /// True if decoded from the V3 (0x11) frame.
  final bool isV3;

  /// Signal-to-noise in dB (V3 only; null for legacy 0x08).
  final double? snrDb;

  bool get isFlood => pathLen == 0xFF;

  DateTime get timestampUtc =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

  @override
  String toString() => 'ChannelMessage(ch: $channelIdx, '
      '${isFlood ? 'flood' : 'path:$pathLen'}, '
      'txt_type: $txtType, v3: $isV3, snr: $snrDb, text: "$text")';
}
