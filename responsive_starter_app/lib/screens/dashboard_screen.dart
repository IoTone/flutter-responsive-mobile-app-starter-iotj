// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/mesh_event.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import '../meshcore/own_location.dart';

/// R8 home — "SEELE Monolith" dashboard: one dominant numeral
/// (peers in range), a full-width status slab that colour-inverts on
/// alert, a terse radio readout, and the recent-activity feed. Pure
/// token styling so every theme preset re-skins it.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  ({String label, bool alert, bool busy}) _status(
      MeshcoreController mc, AppLocalizations l) {
    return switch (mc.state) {
      MeshcoreConnectionState.ready =>
        (label: l.statusLinked, alert: false, busy: false),
      MeshcoreConnectionState.handshaking =>
        (label: l.statusHandshaking, alert: false, busy: true),
      MeshcoreConnectionState.reconnecting =>
        (label: l.statusReconnecting, alert: true, busy: true),
      MeshcoreConnectionState.failed =>
        (label: l.statusLinkLost, alert: true, busy: false),
      MeshcoreConnectionState.disconnected => (
          label: mc.isConnecting ? l.statusConnecting : l.statusOffline,
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
    final AppLocalizations l = AppLocalizations.of(context);
    final int inRange =
        mc.nodes.where((DiscoveredNode n) => n.inRange).length;
    final ({String label, bool alert, bool busy}) st = _status(mc, l);
    final SelfInfo? selfInfo = mc.selfInfo;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: <Widget>[
        // Dominant numeral.
        Text(l.dashboardPeersInRange,
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
        Text(l.dashboardKnownCount(mc.nodes.length),
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
              // Inline "SYNCING…" when the post-handshake drain is in
              // flight. Surfaces the BLE round-trip work that runs for
              // 1–3 s after a fresh link so it doesn't read as a
              // freeze. Static glyph (no spinner) so widget tests'
              // pumpAndSettle can still settle.
              if (mc.state == MeshcoreConnectionState.ready &&
                  mc.isDraining) ...<Widget>[
                Icon(Icons.sync, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Text(l.statusSyncing,
                    style: TextStyle(
                        color: cs.primary,
                        fontSize: 10,
                        letterSpacing: 2)),
                const SizedBox(width: 4),
              ],
              if (mc.state == MeshcoreConnectionState.disconnected &&
                  !mc.isConnecting)
                TextButton(
                  onPressed: () => mc.connect(),
                  child: Text(l.actionConnect),
                )
              else if (mc.state == MeshcoreConnectionState.failed)
                TextButton(
                  onPressed: () => mc.connect(),
                  child: Text(l.actionRetry),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Terse radio readout.
        Text(l.dashboardRadio,
            style: TextStyle(
                color: cs.onSurfaceVariant, fontSize: 12, letterSpacing: 4)),
        const SizedBox(height: 4),
        Text(
          selfInfo == null
              ? l.dashboardAwaitingDevice
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
          Text(l.dashboardPaired(mc.pairedName!),
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
        // Location surface (Phase A) — pulled from the device's
        // SelfInfo when present, otherwise flagged as unset with a
        // "Configure" CTA into Device config (manual lat/lon entry).
        const SizedBox(height: 18),
        _LocationTile(mc: mc),
        if (mc.batteryMillivolts != null) ...<Widget>[
          const SizedBox(height: 18),
          Text(l.dashboardBattery,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  letterSpacing: 4)),
          const SizedBox(height: 4),
          Text(
            l.dashboardBatteryReadout(
                  mc.batteryVolts!.toStringAsFixed(2),
                  mc.batteryPercent ?? 0,
                ) +
                (mc.charging == true ? '  ⚡ ${l.dashboardCharging}' : ''),
            style: TextStyle(
                color: mc.charging == true ? cs.tertiary : cs.onSurface,
                fontFamily: 'monospace'),
          ),
        ],
        const SizedBox(height: 24),

        // Recent activity.
        Text(l.dashboardRecent,
            style: TextStyle(
                color: cs.onSurfaceVariant, fontSize: 12, letterSpacing: 4)),
        const SizedBox(height: 6),
        if (mc.recentEvents.isEmpty)
          Text(l.dashboardNoActivity,
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
                      child: Text(_eventLine(l, e),
                          style: TextStyle(color: cs.onSurface)),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}

/// Localise a single RECENT-feed event line. The controller emits
/// a discriminated `kind` + an args map; this function picks the
/// matching arb format and substitutes the args, so every event
/// row reads in the user's chosen locale.
String _eventLine(AppLocalizations l, MeshEvent e) {
  final Map<String, String> a = e.args;
  return switch (e.kind) {
    MeshEventKind.advert => l.eventAdvert(a['name'] ?? '?'),
    MeshEventKind.channelMsg => l.eventChannelMsg(
        a['channel'] ?? '?', a['text'] ?? ''),
    MeshEventKind.dm => l.eventDm(a['text'] ?? ''),
    MeshEventKind.contact => l.eventContact(a['name'] ?? '?'),
    MeshEventKind.battery => l.eventBattery(a['volts'] ?? '?'),
    MeshEventKind.deviceError => l.eventDeviceError(a['code'] ?? '?'),
    MeshEventKind.deviceClockSynced => l.eventDeviceClockSynced,
    MeshEventKind.deviceClockSkew =>
      l.eventDeviceClockSkew(a['seconds'] ?? '?'),
    MeshEventKind.msgSent => l.eventMsgSent(a['ack'] ?? '?'),
    MeshEventKind.deviceInfo => l.eventDeviceInfo(a['version'] ?? '?'),
    MeshEventKind.selfInfo => l.eventSelfInfo(a['name'] ?? '?'),
    MeshEventKind.queuedWaiting => a.containsKey('count')
        ? l.eventQueuedWaitingN(a['count']!)
        : l.eventQueuedWaiting,
  };
}

/// Dashboard "LOCATION" tile (Phase A). Three states:
///   - device reported a non-zero fix → green dot + coordinates +
///     source label ("device").
///   - device responded but lat/lon are (0,0) → "not set" with a
///     **Configure** CTA into Device config (manual entry).
///   - device hasn't reported SelfInfo yet → muted "awaiting".
class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.mc});
  final MeshcoreController mc;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final OwnLocation? loc = mc.ownLocation;
    final SelfInfo? si = mc.selfInfo;
    final bool awaitingSelf = si == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l.dashboardLocation,
            style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                letterSpacing: 4)),
        const SizedBox(height: 4),
        if (loc != null)
          Text(
            '${loc.latitude.toStringAsFixed(5)}, '
            '${loc.longitude.toStringAsFixed(5)}\n'
            '${l.dashboardLocationSourceLabel(loc.sourceLabel)}',
            style: TextStyle(
                color: cs.onSurface,
                fontFamily: 'monospace',
                height: 1.5),
          )
        else if (awaitingSelf)
          Text(l.dashboardAwaitingDeviceLocation,
              style: TextStyle(color: cs.onSurfaceVariant))
        else
          Row(
            children: <Widget>[
              Icon(Icons.location_off,
                  size: 18, color: cs.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.dashboardLocationNotSet,
                  style: TextStyle(color: cs.onSurface),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/settings/device'),
                child: Text(l.dashboardLocationConfigure),
              ),
            ],
          ),
      ],
    );
  }
}
