// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

/// A received direct (contact) text message.
///
/// Unifies `RESP_CODE_CONTACT_MSG_RECV` (0x07) and its V3 variant
/// (0x10). [snrDb] is null for the legacy 0x07 frame.
///
/// Layouts (from `examples/companion_radio/MyMesh.cpp`, pinned commit):
/// ```
/// 0x07: [07][pubkey_prefix 6][path_len][txt_type][ts u32 LE]
///       [sig_prefix 4 IF txt_type==2][text…]
/// 0x10: [10][snr*4 i8][rsvd][rsvd][pubkey_prefix 6][path_len]
///       [txt_type][ts u32 LE][sig_prefix 4 IF txt_type==2][text…]
/// ```
/// The sender is identified by a 6-byte public-key prefix.
/// `txt_type == 2` (`TXT_TYPE_SIGNED_PLAIN`) carries a 4-byte
/// signature prefix.
class ContactMessage {
  const ContactMessage({
    required this.pubKeyPrefix,
    required this.pathLen,
    required this.txtType,
    required this.timestamp,
    required this.text,
    required this.isV3,
    this.snrDb,
    this.signaturePrefix,
  });

  /// First 6 bytes of the sender's public key.
  final Uint8List pubKeyPrefix;

  /// Raw hop count, or `0xFF` for flood (see [isFlood]).
  final int pathLen;
  final int txtType;

  /// Sender timestamp (unix seconds).
  final int timestamp;
  final String text;
  final bool isV3;

  /// Signal-to-noise in dB (V3 only).
  final double? snrDb;

  /// 4-byte signature prefix, present iff `txtType == 2`.
  final Uint8List? signaturePrefix;

  bool get isFlood => pathLen == 0xFF;
  bool get isSigned => signaturePrefix != null;

  DateTime get timestampUtc =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

  @override
  String toString() => 'ContactMessage(from: '
      '${pubKeyPrefix.map((int b) => b.toRadixString(16).padLeft(2, '0')).join()}'
      ', ${isFlood ? 'flood' : 'path:$pathLen'}, txt_type: $txtType, '
      'v3: $isV3, signed: $isSigned, text: "$text")';
}
