/// A human-readable line for the Dashboard's recent-activity feed,
/// derived from a decoded inbound frame.
class MeshEvent {
  MeshEvent(this.text) : at = DateTime.now();
  final String text;
  final DateTime at;
}
