// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT

/// Delivery lifecycle of an **outgoing** message. Null on incoming
/// lines (not applicable). Drives the per-bubble status glyph.
///
/// - [sending]   — handed to the radio over BLE; awaiting the device's
///                 send confirmation (`RESP_CODE_SENT`).
/// - [sent]      — device accepted it and transmitted into the mesh.
///                 Terminal success for channel/broadcast messages
///                 (flood-routed → no recipient receipt exists).
/// - [delivered] — a direct message's recipient ACK arrived
///                 (`PUSH_CODE_ACK` matched our expectedAck tag).
/// - [failed]    — the BLE send threw, or a direct message saw no ACK
///                 within the device's estimated timeout (no path /
///                 recipient unreachable).
enum MessageDelivery { sending, sent, delivered, failed }

/// One line in the channel chat (R6). Incoming lines are decoded from
/// `ChannelMessageFrame`; outgoing lines are appended optimistically
/// when we send (the radio performs the OTA encryption).
class ChatMessage {
  ChatMessage({
    String? id,
    required this.channelIdx,
    required this.text,
    required this.outgoing,
    DateTime? at,
    this.snrDb,
    this.isFlood = false,
    this.peerPubKeyHex,
    this.delivery,
    this.expectedAck,
  })  : id = id ?? _genId(),
        at = at ?? DateTime.now();

  /// Monotonic-ish per-process id so per-message actions (R20:
  /// Reply / Copy / Delete) can target a specific row even across
  /// JSON round-trips. Persisted in `toJson`; restored in `fromJson`.
  final String id;

  static int _seq = 0;
  static String _genId() {
    final int t = DateTime.now().microsecondsSinceEpoch;
    _seq = (_seq + 1) & 0xFFFFFF;
    return '${t.toRadixString(36)}.${_seq.toRadixString(36)}';
  }

  final int channelIdx;
  final String text;

  /// For **DMs (1:1 P2P)**: the peer's pubkey hex (64 chars) when we
  /// can resolve it from the fabric, or the 12-hex pubkey prefix
  /// when only the prefix arrived (legacy `CONTACT_MSG_RECV` carries
  /// 6 bytes). Null for channel messages (use [channelIdx] then).
  final String? peerPubKeyHex;

  /// True = we sent it; false = received over the mesh.
  final bool outgoing;

  /// Local send/receive time (the OTA timestamp is sender-clock and
  /// not trustworthy for ordering).
  final DateTime at;

  /// Signal-to-noise of the inbound message, when the radio reported
  /// it (V3 channel frame only).
  final double? snrDb;

  /// True when the inbound message arrived via flood (path_len 0xFF).
  final bool isFlood;

  /// Delivery state of an outgoing message; null for incoming. Mutable
  /// because the state evolves *after* the row is created, as the
  /// device's send confirmation and the recipient ACK arrive.
  MessageDelivery? delivery;

  /// The `MsgSent.expectedAck` tag the device returned for this
  /// outgoing message, used to match a later `PUSH_CODE_ACK`. Null
  /// until the device confirms the send (or for incoming messages).
  int? expectedAck;

  /// Compact JSON for local persistence (history survives restarts —
  /// the companion protocol has no history-fetch; the device queue is
  /// drained destructively).
  Map<String, Object?> toJson() => <String, Object?>{
        'i': id,
        'c': channelIdx,
        't': text,
        'o': outgoing,
        'a': at.millisecondsSinceEpoch,
        if (snrDb != null) 's': snrDb,
        if (isFlood) 'f': true,
        if (peerPubKeyHex != null) 'p': peerPubKeyHex,
        if (delivery != null) 'd': delivery!.index,
        if (expectedAck != null) 'k': expectedAck,
      };

  static ChatMessage fromJson(Map<String, Object?> j) {
    final int? dIdx = (j['d'] as num?)?.toInt();
    MessageDelivery? delivery = dIdx != null &&
            dIdx >= 0 &&
            dIdx < MessageDelivery.values.length
        ? MessageDelivery.values[dIdx]
        : null;
    // In-flight tracking (pending FIFO + ack timers) does not survive
    // a restart, so a persisted `sending` row would otherwise show a
    // permanent clock. Resolve it to `failed` — we never saw the
    // device confirm it before the app went away.
    if (delivery == MessageDelivery.sending) {
      delivery = MessageDelivery.failed;
    }
    return ChatMessage(
      id: j['i'] as String?,
      channelIdx: (j['c'] as num?)?.toInt() ?? 0,
      text: j['t'] as String? ?? '',
      outgoing: j['o'] as bool? ?? false,
      at: DateTime.fromMillisecondsSinceEpoch(
          (j['a'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch),
      snrDb: (j['s'] as num?)?.toDouble(),
      isFlood: j['f'] as bool? ?? false,
      peerPubKeyHex: j['p'] as String?,
      delivery: delivery,
      expectedAck: (j['k'] as num?)?.toInt(),
    );
  }
}
