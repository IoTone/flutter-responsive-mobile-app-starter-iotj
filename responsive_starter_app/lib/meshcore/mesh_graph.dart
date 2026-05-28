// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'discovered_node.dart';
import 'meshcore_controller.dart';

/// R50 — node in the topology tree. Either our own node, a known
/// repeater, or a leaf peer. Identity is the full pubkey hex (or
/// the sentinel "self" string for the root).
class MeshGraphNode {
  const MeshGraphNode({
    required this.id,
    required this.label,
    required this.type,
    this.isSelf = false,
  });

  final String id;
  final String label;

  /// Advert type byte. 0 = "self" (sentinel). 1–4 match
  /// `kAdvTypeChat / kAdvTypeRepeater / kAdvTypeRoom / kAdvTypeSensor`.
  final int type;

  final bool isSelf;

  @override
  String toString() => 'MeshGraphNode($id, $label, t=$type)';
}

/// Directed edge in the topology tree, oriented from us → repeaters
/// → leaf peer (i.e. the way our device sends to that peer).
class MeshGraphEdge {
  const MeshGraphEdge(this.fromId, this.toId, {this.flood = false});
  final String fromId;
  final String toId;

  /// True for a "reachable via flood" link (self → flood-routed
  /// contact) — drawn dashed, since there's no fixed path. Normal
  /// (solid) edges are direct / repeater-chain hops.
  final bool flood;

  String get key => '$fromId|$toId';

  @override
  String toString() =>
      'MeshGraphEdge($fromId → $toId${flood ? ' flood' : ''})';
}

/// The full mesh topology tree we can derive from the controller.
class MeshGraph {
  const MeshGraph({required this.nodes, required this.edges});
  final List<MeshGraphNode> nodes;
  final List<MeshGraphEdge> edges;

  /// Build the graph from the controller's current node table.
  ///
  /// Sources:
  /// - Root is "self" (single pinned node).
  /// - Every `DiscoveredNode` with a resolved
  ///   `topologyChainFor(pubKey) == [r0, r1, ...]` contributes the
  ///   edge chain `self → r0 → r1 → ... → peer`.
  /// - **Flood-routed** peers (`viaFlood`, no fixed path) get a
  ///   dashed `self → peer` edge — reachable, but the route isn't
  ///   pinned. This mirrors the official app's "Flood" hop category.
  /// - Peers with `topologyChainFor == null` that are *not* flood
  ///   (advert-only-heard, unresolved chain) are added as
  ///   **disconnected** nodes — they float in the layout, which
  ///   honestly reflects "we know they exist but not where in the
  ///   tree they sit."
  /// - Peers with empty chain are direct neighbours: edge `self → peer`.
  ///
  /// Edge deduplication: many peers may share the same first hop;
  /// the same `repeater_A → repeater_B` edge only appears once.
  ///
  /// [filteredNodes] overrides which peers populate the graph (e.g.
  /// favourites-only). When null the controller's full node list is
  /// used. The path resolver still walks the controller's whole node
  /// table, so a repeater that's part of a peer's path but not in the
  /// filter still shows up as an intermediate hub.
  /// [maxHops] caps the resolved hop depth shown. A peer is included
  /// when its hop count (`outPathHashes.length`, 0 = direct) is
  /// `<= maxHops`. Peers with **unknown** routes (advert-only, no
  /// path info) are included only at the top of the range
  /// (`maxHops >= 6`), treated as the "show everything, including
  /// unknowns" setting. Default 6 keeps the unfiltered behaviour for
  /// callers that don't pass it.
  static MeshGraph fromController(
    MeshcoreController mc, {
    List<DiscoveredNode>? filteredNodes,
    int maxHops = 6,
  }) {
    const String selfId = 'self';
    final Map<String, MeshGraphNode> byId = <String, MeshGraphNode>{
      selfId: MeshGraphNode(
        id: selfId,
        label: mc.selfInfo?.name.isNotEmpty == true
            ? mc.selfInfo!.name
            : 'me',
        type: 0,
        isSelf: true,
      ),
    };
    final Set<String> seenEdges = <String>{};
    final List<MeshGraphEdge> edges = <MeshGraphEdge>[];

    void addEdge(String from, String to, {bool flood = false}) {
      final MeshGraphEdge e = MeshGraphEdge(from, to, flood: flood);
      if (seenEdges.add(e.key)) edges.add(e);
    }

    void addNode(DiscoveredNode n) {
      byId.putIfAbsent(
        n.pubKeyHex,
        () => MeshGraphNode(
          id: n.pubKeyHex,
          label: n.name.isEmpty ? n.shortId : n.name,
          type: n.type,
        ),
      );
    }

    final String? ownHex = mc.ownPubKeyHex;
    final List<DiscoveredNode> peers = filteredNodes ?? mc.nodes;
    for (final DiscoveredNode peer in peers) {
      if (peer.pubKeyHex == ownHex) continue; // don't double the root

      // Hop-depth filter. Known hop count = outPathHashes.length
      // (0 = direct). Unknown route (null) shows only at the top of
      // the range.
      final int? hops = peer.outPathHashes?.length;
      final bool passesHops =
          hops == null ? maxHops >= 6 : hops <= maxHops;
      if (!passesHops) continue;

      addNode(peer);

      final List<DiscoveredNode>? chain =
          mc.topologyChainFor(peer.pubKeyHex);
      if (chain == null) {
        if (peer.viaFlood) {
          // Reachable via flood — no fixed path, but it IS a contact
          // we can talk to. Tie it to self with a dashed edge so it
          // clusters near the root instead of floating off as if we'd
          // never reached it.
          addEdge(selfId, peer.pubKeyHex, flood: true);
        }
        // Otherwise unknown route (advert-only) — leave disconnected.
        // The layout floats it toward the rim where it can't pretend
        // to be a direct neighbour.
        continue;
      }
      String prev = selfId;
      for (final DiscoveredNode hop in chain) {
        addNode(hop);
        addEdge(prev, hop.pubKeyHex);
        prev = hop.pubKeyHex;
      }
      addEdge(prev, peer.pubKeyHex);
    }

    return MeshGraph(
      nodes: byId.values.toList(growable: false),
      edges: edges,
    );
  }
}
