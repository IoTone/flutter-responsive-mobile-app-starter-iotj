import 'package:flutter/material.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../meshcore/discovered_node.dart';
import '../meshcore/mesh_event.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';

/// R8 home — "SEELE Monolith" dashboard: one dominant numeral
/// (peers in range), a full-width status slab that colour-inverts on
/// alert, a terse radio readout, and the recent-activity feed. Pure
/// token styling so every theme preset re-skins it.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  ({String label, bool alert, bool busy}) _status(MeshcoreController mc) {
    return switch (mc.state) {
      MeshcoreConnectionState.ready =>
        (label: 'LINKED · NO ALERTS', alert: false, busy: false),
      MeshcoreConnectionState.handshaking =>
        (label: 'SYNCING…', alert: false, busy: true),
      MeshcoreConnectionState.reconnecting =>
        (label: 'RECONNECTING…', alert: true, busy: true),
      MeshcoreConnectionState.failed =>
        (label: 'LINK LOST', alert: true, busy: false),
      MeshcoreConnectionState.disconnected => (
          label: mc.isConnecting ? 'CONNECTING…' : 'OFFLINE',
          alert: !mc.isConnecting,
          busy: mc.isConnecting,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final int inRange =
        mc.nodes.where((DiscoveredNode n) => n.inRange).length;
    final ({String label, bool alert, bool busy}) st = _status(mc);
    final SelfInfo? selfInfo = mc.selfInfo;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: <Widget>[
        // Dominant numeral.
        Text('PEERS IN RANGE',
            style: TextStyle(
                color: cs.onSurfaceVariant, fontSize: 12, letterSpacing: 4)),
        Text('$inRange',
            style: (tt.displayLarge ?? const TextStyle(fontSize: 72))
                .copyWith(
                    color: cs.onSurface,
                    fontSize: 88,
                    height: 1.0,
                    fontWeight: FontWeight.w300)),
        const SizedBox(height: 4),
        Text('${mc.nodes.length} known',
            style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 24),

        // Status slab — colour-inverts to error on alert.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: st.alert ? cs.error : cs.surfaceContainerHigh,
          child: Row(
            children: <Widget>[
              if (st.busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: st.alert ? cs.onError : cs.primary),
                )
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: st.alert ? cs.onError : cs.primary),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('▌ ${st.label}',
                    style: TextStyle(
                        color: st.alert ? cs.onError : cs.primary,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600)),
              ),
              if (mc.state == MeshcoreConnectionState.disconnected &&
                  !mc.isConnecting)
                TextButton(
                  onPressed: () => mc.connect(),
                  child: const Text('CONNECT'),
                )
              else if (mc.state == MeshcoreConnectionState.failed)
                TextButton(
                  onPressed: () => mc.connect(),
                  child: const Text('RETRY'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Terse radio readout.
        Text('RADIO',
            style: TextStyle(
                color: cs.onSurfaceVariant, fontSize: 12, letterSpacing: 4)),
        const SizedBox(height: 4),
        Text(
          selfInfo == null
              ? '— awaiting device —'
              : '${selfInfo.name}\n'
                  '${selfInfo.frequencyMhz}MHz  '
                  'SF${selfInfo.spreadingFactor}  '
                  'CR${selfInfo.codingRate}  '
                  '${selfInfo.txPowerDbm}dBm',
          style: TextStyle(
              color: cs.onSurface,
              fontFamily: 'monospace',
              height: 1.5),
        ),
        if (mc.pairedName != null) ...<Widget>[
          const SizedBox(height: 6),
          Text('paired: ${mc.pairedName}',
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
        if (mc.batteryMillivolts != null) ...<Widget>[
          const SizedBox(height: 18),
          Text('BATTERY',
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  letterSpacing: 4)),
          const SizedBox(height: 4),
          Text(
            '${mc.batteryVolts!.toStringAsFixed(2)}V · '
            '~${mc.batteryPercent}%'
            '${mc.charging == true ? '  ⚡ CHARGING' : ''}',
            style: TextStyle(
                color: mc.charging == true ? cs.tertiary : cs.onSurface,
                fontFamily: 'monospace'),
          ),
        ],
        const SizedBox(height: 24),

        // Recent activity.
        Text('RECENT',
            style: TextStyle(
                color: cs.onSurfaceVariant, fontSize: 12, letterSpacing: 4)),
        const SizedBox(height: 6),
        if (mc.recentEvents.isEmpty)
          Text('— no activity —',
              style: TextStyle(color: cs.onSurfaceVariant))
        else
          ...mc.recentEvents.take(12).map((MeshEvent e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${e.at.hour.toString().padLeft(2, '0')}:'
                        '${e.at.minute.toString().padLeft(2, '0')}:'
                        '${e.at.second.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontFamily: 'monospace',
                            fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(e.text,
                          style: TextStyle(color: cs.onSurface)),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}
