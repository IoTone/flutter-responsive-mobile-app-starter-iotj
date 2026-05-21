import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import '../util/geo.dart' as geo;

/// Nodes "in the area" — the hyperlocal-discovery view (R6/R8).
///
/// Discovery in MeshCore is **advert-driven**: a node appears here only
/// when this radio *hears that node's advert* (then auto-added as a
/// contact, pushed via `PUSH_CODE_ADVERTISEMENT`, or drained from the
/// queue). Channel/Public traffic does NOT create a node — you can
/// chat on Public with a peer that never shows up here. So discovery
/// is bilateral: **Advertise** makes this node findable by others;
/// **Scan area** broadcasts our advert *and* collects the adverts we
/// have heard.
class NodesScreen extends StatelessWidget {
  const NodesScreen({super.key});

  String _ago(int unix) {
    if (unix <= 0) return '—';
    final int s = DateTime.now().millisecondsSinceEpoch ~/ 1000 - unix;
    if (s < 0) return 'now';
    if (s < 60) return '${s}s';
    if (s < 3600) return '${s ~/ 60}m';
    if (s < 86400) return '${s ~/ 3600}h';
    return '${s ~/ 86400}d';
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool ready = mc.state == MeshcoreConnectionState.ready;
    // Favourites (= "contacts" in the UX sense) sort to the top of the
    // fabric. Within each group keep the controller's recency order.
    final Set<String> favs = mc.favorites;
    final List<DiscoveredNode> nodes = <DiscoveredNode>[...mc.nodes]
      ..sort((DiscoveredNode a, DiscoveredNode b) {
        final bool af = favs.contains(a.pubKeyHex);
        final bool bf = favs.contains(b.pubKeyHex);
        if (af != bf) return af ? -1 : 1;
        return 0;
      });

    final int inRange = nodes.where((DiscoveredNode n) => n.inRange).length;

    void advertise(bool flood) {
      mc.sendSelfAdvert(flood: flood);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(flood
              ? 'Flood advert sent — propagates across the whole mesh '
                  '(neighbours + repeaters). The other node must '
                  'Advertise too before it appears here.'
              : 'Zero-hop advert sent — direct neighbours only, not '
                  'rebroadcast by repeaters.'),
        ));
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  icon: mc.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.radar),
                  label: Text(mc.isScanning ? 'Scanning…' : 'Scan area'),
                  onPressed: ready && !mc.isScanning ? mc.scan : null,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.podcasts),
                label: const Text('Advertise'),
                onPressed: ready
                    ? () async {
                        final bool? flood =
                            await showModalBottomSheet<bool>(
                          context: context,
                          showDragHandle: true,
                          builder: (BuildContext _) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ListTile(
                                  leading:
                                      const Icon(Icons.travel_explore),
                                  title: const Text('Flood advert'),
                                  subtitle: const Text(
                                      'Whole mesh — neighbours + '
                                      'repeaters. Best for discovery.'),
                                  onTap: () =>
                                      Navigator.pop(context, true),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.podcasts),
                                  title: const Text('Zero-hop advert'),
                                  subtitle: const Text(
                                      'Direct neighbours only — not '
                                      'rebroadcast. Quieter on a busy '
                                      'mesh.'),
                                  onTap: () =>
                                      Navigator.pop(context, false),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (flood != null) advertise(flood);
                      }
                    : null,
              ),
              IconButton(
                tooltip: 'Sync contacts',
                icon: const Icon(Icons.sync),
                onPressed: ready ? () => mc.requestContacts() : null,
              ),
              IconButton(
                tooltip: 'Hyperlocal grid (R18)',
                icon: const Icon(Icons.radar),
                onPressed: () => context.push('/grid'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            ready
                ? '$inRange in range · ${nodes.length} in fabric · '
                    '${favs.length} contact${favs.length == 1 ? '' : 's'}'
                : 'Not connected — Settings → Diagnostics & connect',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: nodes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      ready
                          ? 'No nodes yet.\n\n'
                              'Discovery is advert-driven: a node shows '
                              'up only when its advert is heard. Chatting '
                              'on Public does NOT make a node appear.\n\n'
                              'Ask the other node to Advertise / Share '
                              '(or tap "Advertise" here so it can find '
                              'you), then "Scan area".\n\n'
                              'This view shows the mesh "fabric" '
                              '(what you\'ve seen). Star a node to '
                              'mark it as a contact.'
                          : 'Connect a radio to discover nearby nodes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: nodes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext c, int i) {
                    final DiscoveredNode n = nodes[i];
                    return ListTile(
                      onTap: () =>
                          context.push('/dm/${n.pubKeyHex}'),
                      leading: Icon(
                        n.inRange
                            ? Icons.sensors
                            : (n.viaAdvert
                                ? Icons.podcasts
                                : Icons.contacts),
                        color: n.inRange ? cs.primary : cs.onSurfaceVariant,
                      ),
                      title: Row(
                        children: <Widget>[
                          Flexible(
                              child: Text(
                                  n.name.isEmpty ? n.shortId : n.name)),
                          if (n.inRange)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text('IN RANGE',
                                  style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1,
                                      color: cs.primary)),
                            ),
                        ],
                      ),
                      subtitle: Builder(builder: (BuildContext _) {
                        // Compute distance only when both endpoints
                        // have lat/lon — microsecond cost per visible
                        // row, no background machinery needed.
                        String? distance;
                        if (n.hasLocation) {
                          distance = geo.formatDistance(
                              mc.distanceMetersTo(
                                  n.latitude!, n.longitude!));
                        }
                        return Text(<String>[
                          n.typeLabel,
                          if (n.signalLabel.isNotEmpty) n.signalLabel,
                          if (distance != null) distance,
                          if (n.hasLocation)
                            '${n.latitude!.toStringAsFixed(4)},'
                                '${n.longitude!.toStringAsFixed(4)}',
                          n.shortId,
                        ].join(' · '),
                            style:
                                TextStyle(color: cs.onSurfaceVariant));
                      }),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(_ago(n.lastHeardUnix),
                              style:
                                  TextStyle(color: cs.onSurfaceVariant)),
                          IconButton(
                            tooltip: mc.isFavorite(n.pubKeyHex)
                                ? 'Unfavourite (remove from contacts)'
                                : 'Favourite as contact',
                            iconSize: 20,
                            icon: Icon(
                              mc.isFavorite(n.pubKeyHex)
                                  ? Icons.star
                                  : Icons.star_border,
                              color: mc.isFavorite(n.pubKeyHex)
                                  ? cs.tertiary
                                  : cs.onSurfaceVariant,
                            ),
                            onPressed: () =>
                                mc.toggleFavorite(n.pubKeyHex),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
