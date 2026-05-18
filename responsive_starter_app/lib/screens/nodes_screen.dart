import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';

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
    final List<DiscoveredNode> nodes = mc.nodes;

    final int inRange = nodes.where((DiscoveredNode n) => n.inRange).length;

    void advertise() {
      mc.sendSelfAdvert(flood: true);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Advert broadcast — others can discover this '
              'node now. The other node must Advertise too before it '
              'appears here.'),
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
                onPressed: ready ? advertise : null,
              ),
              IconButton(
                tooltip: 'Sync contacts',
                icon: const Icon(Icons.sync),
                onPressed: ready ? () => mc.requestContacts() : null,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            ready
                ? '$inRange in range · ${nodes.length} known'
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
                              'you), then "Scan area".'
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
                      subtitle: Text(<String>[
                        n.typeLabel,
                        if (n.signalLabel.isNotEmpty) n.signalLabel,
                        if (n.hasLocation)
                          '${n.latitude!.toStringAsFixed(4)},'
                              '${n.longitude!.toStringAsFixed(4)}',
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
