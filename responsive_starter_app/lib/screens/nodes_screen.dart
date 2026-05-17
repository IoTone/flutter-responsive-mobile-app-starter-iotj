import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';

/// Nodes "in the area" — Meshcore devices discovered from the radio's
/// contact list (`GET_CONTACTS`) and over-the-air adverts
/// (`PUSH_CODE_ADVERTISEMENT`). The hyperlocal-discovery view (R6/R8).
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
    final List<DiscoveredNode> nodes = mc.nodes;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  ready
                      ? '${nodes.length} node(s) in range'
                      : 'Not connected — Settings → Diagnostics & connect',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              IconButton(
                tooltip: 'Get contacts',
                icon: const Icon(Icons.sync),
                onPressed: ready ? () => mc.requestContacts() : null,
              ),
              IconButton(
                tooltip: 'Broadcast self-advert',
                icon: const Icon(Icons.podcasts),
                onPressed: ready ? () => mc.sendSelfAdvert() : null,
              ),
            ],
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
                          ? 'No nodes yet.\nTap ⟳ to sync contacts, or '
                              'wait for adverts.'
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
                      leading: Icon(
                        n.viaAdvert ? Icons.podcasts : Icons.contacts,
                        color: cs.primary,
                      ),
                      title: Text(n.name.isEmpty ? n.shortId : n.name),
                      subtitle: Text(<String>[
                        n.typeLabel,
                        if (n.hasLocation)
                          '${n.latitude!.toStringAsFixed(4)},'
                              '${n.longitude!.toStringAsFixed(4)}',
                        if (n.snrDb != null)
                          'SNR ${n.snrDb!.toStringAsFixed(1)}',
                        n.shortId,
                      ].join(' · '),
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      trailing: Text(_ago(n.lastHeardUnix),
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
