// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
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
class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key});

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _starredOnly = false;
  bool _inRangeOnly = false;
  // null = any; otherwise hide nodes whose lastHeard is older than this.
  Duration? _maxAge;
  // null = any; otherwise hide GPS-positioned nodes farther than this
  // (in metres). Nodes without distance pass through regardless.
  double? _maxDistanceMeters;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _ago(int unix) {
    if (unix <= 0) return '—';
    final int s = DateTime.now().millisecondsSinceEpoch ~/ 1000 - unix;
    if (s < 0) return 'now';
    if (s < 60) return '${s}s';
    if (s < 3600) return '${s ~/ 60}m';
    if (s < 86400) return '${s ~/ 3600}h';
    return '${s ~/ 86400}d';
  }

  bool _passesFilters(
      DiscoveredNode n, MeshcoreController mc, Set<String> favs) {
    if (_query.isNotEmpty) {
      final String q = _query.toLowerCase();
      final bool nameHit = n.name.toLowerCase().contains(q);
      final bool idHit = n.shortId.toLowerCase().contains(q);
      final bool pkHit = n.pubKeyHex.toLowerCase().contains(q);
      if (!nameHit && !idHit && !pkHit) return false;
    }
    if (_starredOnly && !favs.contains(n.pubKeyHex)) return false;
    if (_inRangeOnly && !n.inRange) return false;
    if (_maxAge != null) {
      final int s =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 - n.lastHeardUnix;
      if (s > _maxAge!.inSeconds) return false;
    }
    if (_maxDistanceMeters != null && n.hasLocation) {
      final double? d = mc.distanceMetersTo(n.latitude!, n.longitude!);
      if (d != null && d > _maxDistanceMeters!) return false;
    }
    return true;
  }

  String _ageLabel() {
    if (_maxAge == null) return 'Any';
    if (_maxAge!.inHours < 24) return '${_maxAge!.inHours}h';
    return '${_maxAge!.inDays}d';
  }

  String _distLabel() {
    if (_maxDistanceMeters == null) return 'Any';
    final double m = _maxDistanceMeters!;
    if (m < 1000) return '${m.round()}m';
    return '${(m / 1000).toStringAsFixed(0)}km';
  }

  bool get _anyFilterActive =>
      _query.isNotEmpty ||
      _starredOnly ||
      _inRangeOnly ||
      _maxAge != null ||
      _maxDistanceMeters != null;

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _query = '';
      _starredOnly = false;
      _inRangeOnly = false;
      _maxAge = null;
      _maxDistanceMeters = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool ready = mc.state == MeshcoreConnectionState.ready;
    final Set<String> favs = mc.favorites;
    // Self gets excluded — we never want to DM ourselves and we're
    // already on the dashboard, not in the discovered-fabric list.
    final String? selfPk = mc.ownPubKeyHex;
    final List<DiscoveredNode> nodes = <DiscoveredNode>[
      for (final DiscoveredNode n in mc.nodes)
        if (n.pubKeyHex != selfPk && _passesFilters(n, mc, favs)) n
    ]..sort((DiscoveredNode a, DiscoveredNode b) {
        final bool af = favs.contains(a.pubKeyHex);
        final bool bf = favs.contains(b.pubKeyHex);
        if (af != bf) return af ? -1 : 1;
        return 0;
      });

    final int inRange = nodes.where((DiscoveredNode n) => n.inRange).length;
    final int totalFabric = mc.nodes
        .where((DiscoveredNode n) => n.pubKeyHex != selfPk)
        .length;

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
        // Filter bar — search by name / shortId / pubkey prefix +
        // chip toggles for Starred / In range + popup menus for
        // last-seen and max-distance cutoffs. Compose with the
        // sort-favourites-to-top behaviour below.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (String v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              hintText: 'Search by name, shortId, or pubkey…',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                // No avatar icon: the chip's selected/unselected state
                // colours the label clearly enough, and skipping the
                // star/sensors avatars keeps the row's icon lookup
                // unambiguous (the per-row trailing star icon stays
                // the only star_border / star instance on screen).
                child: FilterChip(
                  label: const Text('Starred'),
                  selected: _starredOnly,
                  onSelected: (bool v) =>
                      setState(() => _starredOnly = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: const Text('In range'),
                  selected: _inRangeOnly,
                  onSelected: (bool v) =>
                      setState(() => _inRangeOnly = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.schedule, size: 16),
                  label: Text('Last seen · ${_ageLabel()}'),
                  onPressed: () async {
                    final Duration? picked = await showMenu<Duration?>(
                      context: context,
                      position: const RelativeRect.fromLTRB(
                          16, 200, 16, 100),
                      items: <PopupMenuEntry<Duration?>>[
                        const PopupMenuItem<Duration?>(
                            value: null, child: Text('Any')),
                        const PopupMenuItem<Duration?>(
                            value: Duration(hours: 1),
                            child: Text('Last hour')),
                        const PopupMenuItem<Duration?>(
                            value: Duration(hours: 24),
                            child: Text('Last 24 h')),
                        const PopupMenuItem<Duration?>(
                            value: Duration(days: 7),
                            child: Text('Last 7 d')),
                      ],
                    );
                    if (!mounted) return;
                    setState(() => _maxAge = picked);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.straighten, size: 16),
                  label: Text('Within · ${_distLabel()}'),
                  onPressed: () async {
                    final double? picked = await showMenu<double?>(
                      context: context,
                      position: const RelativeRect.fromLTRB(
                          16, 200, 16, 100),
                      items: <PopupMenuEntry<double?>>[
                        const PopupMenuItem<double?>(
                            value: null, child: Text('Any')),
                        const PopupMenuItem<double?>(
                            value: 100, child: Text('≤ 100 m')),
                        const PopupMenuItem<double?>(
                            value: 500, child: Text('≤ 500 m')),
                        const PopupMenuItem<double?>(
                            value: 5000, child: Text('≤ 5 km')),
                        const PopupMenuItem<double?>(
                            value: 25000, child: Text('≤ 25 km')),
                      ],
                    );
                    if (!mounted) return;
                    setState(() => _maxDistanceMeters = picked);
                  },
                ),
              ),
              if (_anyFilterActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    avatar: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear'),
                    onPressed: _clearFilters,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text(
            ready
                ? '${nodes.length} of $totalFabric in fabric · '
                    '$inRange in range · '
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
                      _anyFilterActive
                          ? 'No nodes match this filter.\n\n'
                              'Tap Clear to widen, or change the chip '
                              'cutoffs above.'
                          : ready
                              ? 'No nodes yet.\n\n'
                                  'Discovery is advert-driven: a node '
                                  'shows up only when its advert is '
                                  'heard. Chatting on Public does NOT '
                                  'make a node appear.\n\n'
                                  'Ask the other node to Advertise / '
                                  'Share (or tap "Advertise" here so it '
                                  'can find you), then "Scan area".\n\n'
                                  'This view shows the mesh "fabric" '
                                  '(what you\'ve seen). Star a node to '
                                  'mark it as a contact.'
                              : 'Connect a radio to discover nearby '
                                  'nodes.',
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
