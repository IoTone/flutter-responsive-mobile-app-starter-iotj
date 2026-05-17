import 'dart:typed_data';

import '../codec/byte_cursor.dart';
import '../codec/constants.dart';
import 'advert.dart';

/// A parsed MeshCore over-the-air packet (as carried raw inside an
/// `RfLogFrame`). Layout from `docs/packet_format.md` (pinned commit):
///
/// ```
/// [header 1][transport codes 4?][path-len 1][path N][payload …]
/// header: bits0-1 route, bits2-5 payload type, bits6-7 version
/// path-len: bits0-5 hop count, bits6-7 hash-size code (0→1B,1→2B,2→3B)
/// transport codes present iff route is TRANSPORT_FLOOD/TRANSPORT_DIRECT
/// ```
class OtaPacket {
  const OtaPacket({
    required this.routeType,
    required this.payloadType,
    required this.version,
    required this.hopCount,
    required this.hashSize,
    required this.payload,
  });

  final int routeType;
  final int payloadType;
  final int version;
  final int hopCount;
  final int hashSize;

  /// Raw payload bytes (type-specific; see [grpTxt]).
  final Uint8List payload;

  bool get isGrpTxt => payloadType == kPayloadTypeGrpTxt;
  bool get isAdvert => payloadType == kPayloadTypeAdvert;
  bool get isTxtMsg => payloadType == kPayloadTypeTxtMsg;

  /// For `PAYLOAD_TYPE_GRP_TXT`, split the payload into the 1-byte
  /// channel hash and the `[MAC(2)]‖ciphertext` blob (exactly the
  /// output of `Utils::encryptThenMAC`). Null if not a GRP_TXT packet
  /// or too short.
  GrpTxtPayload? get grpTxt {
    if (!isGrpTxt || payload.length < 1 + kCipherMacSize) return null;
    return GrpTxtPayload(
      channelHash: payload[0],
      macAndCiphertext: Uint8List.sublistView(payload, 1),
    );
  }

  /// For `PAYLOAD_TYPE_ADVERT`, the decoded advert (same payload
  /// layout as the companion `0x80` push). Null if not an advert or
  /// malformed. Lets RF-log (`0x88`) captures yield adverts *with*
  /// SNR/RSSI for "what's in my area" scanning.
  Advert? get advert => isAdvert ? Advert.tryParse(payload) : null;

  /// Parse from the raw OTA bytes (everything after the
  /// `[0x88][snr][rssi]` RF-log prefix). Returns null on a malformed
  /// or truncated packet — never throws.
  static OtaPacket? parse(Uint8List raw) {
    try {
      final ByteCursor c = ByteCursor(raw);
      final int h = c.u8('pkt.header');
      final int route = h & kPktRouteTypeMask;
      final int ptype =
          (h & kPktPayloadTypeMask) >> kPktPayloadTypeShift;
      final int ver = (h & kPktVersionMask) >> 6;
      if (route == kRouteTransportFlood ||
          route == kRouteTransportDirect) {
        c.bytes(kTransportCodesSize, 'pkt.transportCodes');
      }
      final int pl = c.u8('pkt.pathLen');
      final int hop = pl & kPathHopMask;
      final int code = (pl >> kPathHashSizeShift) & 0x03;
      if (code == 3) return null; // reserved
      final int hashSize = code + 1; // 0→1,1→2,2→3
      c.bytes(hop * hashSize, 'pkt.path');
      final Uint8List payload =
          c.atEnd ? Uint8List(0) : c.bytes(c.remaining, 'pkt.payload');
      return OtaPacket(
        routeType: route,
        payloadType: ptype,
        version: ver,
        hopCount: hop,
        hashSize: hashSize,
        payload: payload,
      );
    } on FrameTruncated {
      return null;
    }
  }

  @override
  String toString() => 'OtaPacket(route: $routeType, type: $payloadType, '
      'v${version + 1}, hops: $hopCount, payload: ${payload.length}B)';
}

/// GRP_TXT payload split: `[channel_hash][MAC(2)‖ciphertext]`.
class GrpTxtPayload {
  const GrpTxtPayload({
    required this.channelHash,
    required this.macAndCiphertext,
  });

  /// First byte of `SHA256(channel secret)` — identifies the channel.
  final int channelHash;

  /// Exactly the `Utils::encryptThenMAC` output for the channel
  /// (`[MAC(2)]‖ciphertext`); feed to `macThenDecrypt`.
  final Uint8List macAndCiphertext;
}
