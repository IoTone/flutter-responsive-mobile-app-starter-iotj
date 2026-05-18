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
  }) : at = at ?? DateTime.now();

  final int channelIdx;
  final String text;

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
}
