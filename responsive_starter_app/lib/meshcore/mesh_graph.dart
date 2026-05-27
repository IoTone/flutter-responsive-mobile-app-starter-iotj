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
  const MeshGraphEdge(this.fromId, this.toId);
  final String fromId;
  final String toId;

  String get key => '$fromId|$toId';

  @override
  String toString() => 'MeshGraphEdge($fromId → $toId)';
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
  /// - Peers with `topologyChainFor == null` (advert-only-heard or
  ///   unresolved chain) are added as **disconnected** nodes — they
  ///   float in the layout, which honestly reflects "we know they
  ///   exist but not where in the tree they sit."
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
  static MeshGraph fromController(
    MeshcoreController mc, {
    List<DiscoveredNode>? filteredNodes,
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

    void addEdge(String from, String to) {
      final MeshGraphEdge e = MeshGraphEdge(from, to);
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
      addNode(peer);

      final List<DiscoveredNode>? chain =
          mc.topologyChainFor(peer.pubKeyHex);
      if (chain == null) {
        // Unknown route — leave the node disconnected. The layout
        // will float it out toward the rim where it can't pretend
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
