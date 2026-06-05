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
import '../meshcore/region_presets.dart';
import 'device_manager_sheet.dart';

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
    final int inRange = mc.nodes.where((DiscoveredNode n) {
      final NodeProximity p = mc.proximityFor(n);
      return p == NodeProximity.near || p == NodeProximity.recent;
    }).length;
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
              // R41 — Device chip. Single tap target for disconnect /
              // reconnect / forget / pick-a-different-radio. The
              // existing inline Connect/Retry stays for one-tap
              // recovery; this sits next to it for everything else.
              IconButton(
                tooltip: l.dashboardDevice,
                icon: Icon(Icons.bluetooth,
                    color: st.alert ? cs.onError : cs.primary,
                    size: 20),
                onPressed: () => DeviceManagerSheet.show(context),
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
        if (selfInfo == null)
          Text(l.dashboardAwaitingDevice,
              style: TextStyle(
                  color: cs.onSurface,
                  fontFamily: 'JetBrains Mono',
                  height: 1.5))
        else ...<Widget>[
          // R52 — the device name is editable right here. Tap to
          // rename; setAdvertName re-advertises + refreshes SelfInfo,
          // so the change takes effect without digging into Device
          // config.
          InkWell(
            onTap: mc.isReady
                ? () => _showRenameDialog(context, mc, selfInfo.name)
                : null,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      selfInfo.name.isEmpty
                          ? l.dashboardUnnamed
                          : selfInfo.name,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w600,
                          fontSize: 16),
                    ),
                  ),
                  if (mc.isReady) ...<Widget>[
                    const SizedBox(width: 6),
                    Icon(Icons.edit_outlined, size: 14, color: cs.primary),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${selfInfo.frequencyMhz}MHz  '
            'SF${selfInfo.spreadingFactor}  '
            'CR${selfInfo.codingRate}  '
            '${selfInfo.txPowerDbm}dBm',
            style: TextStyle(
                color: cs.onSurface,
                fontFamily: 'JetBrains Mono',
                height: 1.5),
          ),
        ],
        // R39 — region preset readout. The answer to "what region am
        // I on?" should be visible from the dashboard, not buried in
        // Device Config. Matched against the device's live tuple;
        // shows "Custom" when no shipped preset matches.
        if (selfInfo != null) ...<Widget>[
          const SizedBox(height: 4),
          Builder(builder: (BuildContext _) {
            final RegionPreset? p = matchPresetByRadioParams(
              frequencyMhz: selfInfo.frequencyMhz,
              bandwidthKhz: selfInfo.bandwidthKhz,
              spreadingFactor: selfInfo.spreadingFactor,
              codingRate: selfInfo.codingRate,
            );
            final bool isCustom = p == null;
            return InkWell(
              onTap: () => context.push('/settings/device'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: <Widget>[
                    Icon(isCustom ? Icons.tune : Icons.public,
                        size: 14,
                        color: isCustom ? cs.tertiary : cs.primary),
                    const SizedBox(width: 6),
                    Text(
                        p == null
                            ? l.deviceRegionCustom
                            : localizedPresetLabel(l, p.id),
                        style: TextStyle(
                            color: isCustom ? cs.tertiary : cs.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }),
        ],
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
          InkWell(
            onTap: () => context.push('/settings/battery'),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(l.dashboardBattery,
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                              letterSpacing: 4)),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right,
                          size: 16, color: cs.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _batteryLine(mc, l),
                    style: TextStyle(
                        color: mc.charging == true
                            ? cs.tertiary
                            : cs.onSurface,
                        fontFamily: 'JetBrains Mono'),
                  ),
                ],
              ),
            ),
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
                            fontFamily: 'JetBrains Mono',
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
        Row(
          children: <Widget>[
            Expanded(
              child: Text(l.dashboardLocation,
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      letterSpacing: 4)),
            ),
            // Manual refresh — the periodic 30 s SelfInfo poll
            // handles most cases, but if the user just moved
            // significantly and doesn't want to wait, this button
            // forces an immediate re-query.
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: l.dashboardLocationRefresh,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                  minWidth: 32, minHeight: 32),
              onPressed: mc.isReady ? () => mc.refreshSelfInfo() : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (loc != null) ...<Widget>[
          Text(
            '${loc.latitude.toStringAsFixed(5)}, '
            '${loc.longitude.toStringAsFixed(5)}'
            '${loc.altitudeMeters == null ? '' : '  '
                '· ${l.dashboardLocationAltitude(loc.altitudeMeters!.round())}'}'
            '\n'
            '${l.dashboardLocationSourceLabel(loc.sourceLabel)}',
            style: TextStyle(
                color: cs.onSurface,
                fontFamily: 'JetBrains Mono',
                height: 1.5),
          ),
          // Diagnostic readout — shows the raw selfInfo lat/lon,
          // the device's advertLocPolicy, and the phoneFix value
          // (if any). Lets us tell at a glance whether the device
          // is reporting fresh GPS or whether ownLocation is
          // falling through to a cached phone fix.
          const SizedBox(height: 4),
          _LocationDebugLine(mc: mc, cs: cs),
        ]
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

/// Small dev-style readout under the formatted Location value.
/// Shows the **raw** values our controller currently sees:
/// - `dev: lat, lon` — `mc.selfInfo.latitude/longitude` straight
///   off the wire. Frozen at (0, 0) → the firmware reports "no
///   GPS." Frozen at a non-zero pair across multiple refreshes →
///   the firmware is caching and not re-reading GPS.
/// - `pol: N` — `mc.selfInfo.advertLocPolicy` (0=None, 1=Pinned,
///   2=Device GPS). If the user thinks they set "Device GPS" but
///   this isn't 2, the policy didn't actually stick on the
///   device.
/// - `phone: lat, lon` — the one-shot phone fix `mc.phoneLocationFix`.
///   Only present if the user has tapped "Use phone location" or
///   the dashboard requested a fix. `ownLocation` falls back to
///   this when the device reports (0, 0).
class _LocationDebugLine extends StatelessWidget {
  const _LocationDebugLine({required this.mc, required this.cs});
  final MeshcoreController mc;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final SelfInfo? si = mc.selfInfo;
    final OwnLocation? phone = mc.phoneLocationFix;
    final List<String> parts = <String>[
      if (si != null)
        'dev: ${si.latitude.toStringAsFixed(5)}, '
            '${si.longitude.toStringAsFixed(5)} '
            'pol:${si.advertLocPolicy}'
      else
        'dev: —',
      if (phone != null)
        'phone: ${phone.latitude.toStringAsFixed(5)}, '
            '${phone.longitude.toStringAsFixed(5)}'
            '${phone.altitudeMeters == null ? '' : ' '
                'alt:${phone.altitudeMeters!.round()}m'}'
      else
        'phone: —',
    ];
    return Text(
      parts.join('\n'),
      style: TextStyle(
        color: cs.onSurfaceVariant.withValues(alpha: .7),
        fontFamily: 'JetBrains Mono',
        fontSize: 10,
        height: 1.35,
      ),
    );
  }
}

/// Dashboard battery line: voltage + the **model's** state-of-charge
/// estimate (OCV-curve, more accurate than the raw linear percent),
/// with a compact time-to-empty when the estimator has one. Charging
/// supersedes the runtime (it's paused while charging).
String _batteryLine(MeshcoreController mc, AppLocalizations l) {
  final est = mc.batteryEstimate;
  final int percent =
      est.socPercent.isNaN ? (mc.batteryPercent ?? 0) : est.socPercent.round();
  final StringBuffer b = StringBuffer(l.dashboardBatteryReadout(
    mc.batteryVolts!.toStringAsFixed(2),
    percent,
  ));
  if (mc.charging == true) {
    b.write('  ⚡ ${l.dashboardCharging}');
  } else if (est.timeToEmpty != null) {
    b.write(' · ${l.dashboardBatteryLeft(_fmtBatteryDur(est.timeToEmpty!, l))}');
  }
  return b.toString();
}

String _fmtBatteryDur(Duration d, AppLocalizations l) {
  if (d.inDays > 0) return l.batteryDurDH(d.inDays, d.inHours % 24);
  if (d.inHours > 0) return l.batteryDurHM(d.inHours, d.inMinutes % 60);
  return l.batteryDurM(d.inMinutes);
}

/// R52 — quick device rename from the dashboard. Opens a small dialog,
/// then writes the new advert name (which re-advertises + refreshes
/// SelfInfo via [MeshcoreController.setAdvertName]).
Future<void> _showRenameDialog(
    BuildContext context, MeshcoreController mc, String current) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final String? result = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDeviceDialog(initial: current),
  );
  if (result == null) return; // cancelled
  final String n = result.trim();
  if (n.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l.deviceToastNameEmpty)));
    return;
  }
  await mc.setAdvertName(n);
  messenger.showSnackBar(SnackBar(content: Text(l.deviceToastNameSet)));
}

class _RenameDeviceDialog extends StatefulWidget {
  const _RenameDeviceDialog({required this.initial});
  final String initial;
  @override
  State<_RenameDeviceDialog> createState() => _RenameDeviceDialogState();
}

class _RenameDeviceDialogState extends State<_RenameDeviceDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.dashboardRenameTitle),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: 31, // kMaxAdvertName
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: l.deviceAdvertName),
        onSubmitted: (_) => Navigator.pop(context, _c.text),
      ),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.actionCancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _c.text),
            child: Text(l.deviceSetName)),
      ],
    );
  }
}
