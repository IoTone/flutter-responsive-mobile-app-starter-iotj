/// One line in the channel chat (R6). Incoming lines are decoded from
/// `ChannelMessageFrame`; outgoing lines are appended optimistically
/// when we send (the radio performs the OTA encryption).
class ChatMessage {
  ChatMessage({
    required this.channelIdx,
    required this.text,
    required this.outgoing,
    DateTime? at,
    this.snrDb,
    this.isFlood = false,
    this.peerPubKeyHex,
  }) : at = at ?? DateTime.now();

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

  /// Compact JSON for local persistence (history survives restarts —
  /// the companion protocol has no history-fetch; the device queue is
  /// drained destructively).
  Map<String, Object?> toJson() => <String, Object?>{
        'c': channelIdx,
        't': text,
        'o': outgoing,
        'a': at.millisecondsSinceEpoch,
        if (snrDb != null) 's': snrDb,
        if (isFlood) 'f': true,
        if (peerPubKeyHex != null) 'p': peerPubKeyHex,
      };

  static ChatMessage fromJson(Map<String, Object?> j) => ChatMessage(
        channelIdx: (j['c'] as num?)?.toInt() ?? 0,
        text: j['t'] as String? ?? '',
        outgoing: j['o'] as bool? ?? false,
        at: DateTime.fromMillisecondsSinceEpoch(
            (j['a'] as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch),
        snrDb: (j['s'] as num?)?.toDouble(),
        isFlood: j['f'] as bool? ?? false,
        peerPubKeyHex: j['p'] as String?,
      );
}
