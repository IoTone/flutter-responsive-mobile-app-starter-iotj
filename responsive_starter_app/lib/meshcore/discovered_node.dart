/// A Meshcore node discovered "in the area" — from a contact list
/// entry (`RESP_CODE_CONTACT`) or an over-the-air advertisement
/// (`PUSH_CODE_ADVERTISEMENT`). Keyed by full public key.
class DiscoveredNode {
  DiscoveredNode({
    required this.pubKeyHex,
    required this.name,
    required this.type,
    required this.lastHeardUnix,
    this.latitude,
    this.longitude,
    this.snrDb,
    required this.viaAdvert,
  });

  final String pubKeyHex;
  String name;
  int type; // advert/contact type: 1 chat, 2 repeater, 3 room, 4 sensor
  int lastHeardUnix;
  double? latitude;
  double? longitude;
  double? snrDb;

  /// True if last updated from an OTA advert (vs. a synced contact).
  bool viaAdvert;

  String get typeLabel => switch (type) {
        1 => 'Chat',
        2 => 'Repeater',
        3 => 'Room',
        4 => 'Sensor',
        _ => 'Node',
      };

  bool get hasLocation => latitude != null && longitude != null;

  String get shortId =>
      pubKeyHex.length >= 12 ? pubKeyHex.substring(0, 12) : pubKeyHex;
}
