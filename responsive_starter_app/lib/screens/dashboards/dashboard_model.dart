// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:meshcore/meshcore.dart';

import '../../gen/app_localizations.dart';
import '../../meshcore/discovered_node.dart';
import '../../meshcore/mesh_event.dart';
import '../../meshcore/meshcore_connection.dart';
import '../../meshcore/meshcore_controller.dart';
import '../../meshcore/region_presets.dart';

/// The dashboard's content as **skin-agnostic data** (the slot model).
/// Both the SEELE monolith and the NERV terminal render from this same
/// struct — the layout/identity differs, the data doesn't. Gathering
/// here keeps the per-skin layouts declarative.
class DashboardModel {
  const DashboardModel({
    required this.statusLabel,
    required this.alert,
    required this.busy,
    required this.peersInRange,
    required this.knownCount,
    required this.nodeName,
    required this.radioLine,
    required this.channelLabel,
    required this.region,
    required this.batteryLine,
    required this.events,
  });

  final String statusLabel;
  final bool alert;
  final bool busy;
  final int peersInRange;
  final int knownCount;

  /// Device advertised name, or null when SelfInfo isn't in yet.
  final String? nodeName;

  /// `915.0MHz SF7 CR5 22dBm`, or null awaiting SelfInfo.
  final String? radioLine;
  final String channelLabel;
  final String region;
  final String? batteryLine;

  final List<({String time, String text})> events;

  static DashboardModel gather(MeshcoreController mc, AppLocalizations l) {
    final ({String label, bool alert, bool busy}) st = switch (mc.state) {
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

    final int inRange = mc.nodes.where((DiscoveredNode n) {
      final NodeProximity p = mc.proximityFor(n);
      return p == NodeProximity.near || p == NodeProximity.recent;
    }).length;

    final SelfInfo? si = mc.selfInfo;
    final RegionPreset? rp = si == null
        ? null
        : matchPresetByRadioParams(
            frequencyMhz: si.frequencyMhz,
            bandwidthKhz: si.bandwidthKhz,
            spreadingFactor: si.spreadingFactor,
            codingRate: si.codingRate,
          );

    String? battery;
    if (mc.batteryVolts != null) {
      final int pct = mc.batteryEstimate.socPercent.isNaN
          ? (mc.batteryPercent ?? 0)
          : mc.batteryEstimate.socPercent.round();
      battery = '${mc.batteryVolts!.toStringAsFixed(2)}V  $pct%'
          '${mc.charging == true ? '  CHG' : ''}';
    }

    return DashboardModel(
      statusLabel: st.label,
      alert: st.alert,
      busy: st.busy,
      peersInRange: inRange,
      knownCount: mc.nodes.length,
      nodeName: si == null
          ? null
          : (si.name.isEmpty ? l.dashboardUnnamed : si.name),
      radioLine: si == null
          ? null
          : '${si.frequencyMhz}MHz  SF${si.spreadingFactor}  '
              'CR${si.codingRate}  ${si.txPowerDbm}dBm',
      channelLabel: 'CH${mc.activeChannel}',
      region: rp == null ? l.deviceRegionCustom : localizedPresetLabel(l, rp.id),
      batteryLine: battery,
      events: <({String time, String text})>[
        for (final MeshEvent e in mc.recentEvents.take(8))
          (
            time: '${e.at.hour.toString().padLeft(2, '0')}:'
                '${e.at.minute.toString().padLeft(2, '0')}:'
                '${e.at.second.toString().padLeft(2, '0')}',
            text: _eventLine(l, e),
          ),
      ],
    );
  }
}

String _eventLine(AppLocalizations l, MeshEvent e) {
  final Map<String, String> a = e.args;
  return switch (e.kind) {
    MeshEventKind.advert => l.eventAdvert(a['name'] ?? '?'),
    MeshEventKind.channelMsg =>
      l.eventChannelMsg(a['channel'] ?? '?', a['text'] ?? ''),
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
