// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/app_localizations.dart';
import '../../meshcore/meshcore_controller.dart';
import '../../theme/mm_skin.dart';
import '../../ui/mm_audio_toggle.dart';
import '../../ui/mm_components.dart';
import '../../ui/mm_scaffold.dart';
import '../device_manager_sheet.dart';
import 'dashboard_model.dart';

/// Concept A — **NERV Terminal** dashboard: an information-maximal
/// operations console. Chamfered HUD panels, hazard-stripe section
/// headers, dense mono readouts, a CRT scanline + corner brackets
/// (all from the active [MmSkin]). The same [DashboardModel] data the
/// SEELE monolith shows, re-imagined as a telemetry grid — proving a
/// skin can drive layout, not just colour.
class NervDashboard extends StatelessWidget {
  const NervDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final MmSkin skin = context.skin;
    final DashboardModel m = DashboardModel.gather(mc, l);
    final TextStyle mono = TextStyle(
        fontFamily: skin.type.monoFamily, color: skin.color.fg, fontSize: 12);

    return MmScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: <Widget>[
          // Brand bar + status pills.
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'MESHMORE // NERV',
                  style: TextStyle(
                    fontFamily:
                        skin.type.headingFamily ?? skin.type.monoFamily,
                    color: skin.color.accent,
                    fontSize: 15,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              MmStatusPill(m.channelLabel),
              const SizedBox(width: 6),
              MmStatusPill(
                m.statusLabel,
                alert: m.alert,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // LINK panel.
          MmPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MmSectionHeader(
                  l.dashNervLink,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Quick mute/unmute for alert sounds (default on).
                      MmAudioToggle(
                          dense: true, size: 18, color: skin.color.accent),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                        icon: Icon(Icons.bluetooth,
                            size: 18, color: skin.color.accent),
                        onPressed: () => DeviceManagerSheet.show(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                MmReadout(
                  label: 'BLE',
                  value: m.statusLabel,
                  valueColor: m.alert ? skin.color.alert : skin.color.ok,
                ),
                const SizedBox(height: 4),
                MmReadout(label: l.dashNervNode, value: m.nodeName ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // RADIO panel.
          MmPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MmSectionHeader(l.dashboardRadio),
                const SizedBox(height: 8),
                Text(m.radioLine ?? l.dashboardAwaitingDevice, style: mono),
                const SizedBox(height: 4),
                MmReadout(label: l.dashNervRegion, value: m.region),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // MESH panel — hazard-striped header (the "live fabric" band).
          MmPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MmSectionHeader(l.dashNervMesh),
                const SizedBox(height: 10),
                MmReadout(
                    label: l.dashboardPeersInRange,
                    value: '${m.peersInRange}',
                    emphasize: true),
                const SizedBox(height: 4),
                MmReadout(
                    label: l.dashNervKnown, value: '${m.knownCount}'),
                if (m.batteryLine != null) ...<Widget>[
                  const SizedBox(height: 4),
                  MmReadout(label: l.dashboardBattery, value: m.batteryLine!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // EVENTS log.
          MmPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MmSectionHeader(l.dashNervEvents),
                const SizedBox(height: 8),
                if (m.events.isEmpty)
                  Text(l.dashboardNoActivity,
                      style: mono.copyWith(color: skin.color.fgMuted))
                else
                  for (final ({String time, String text}) e in m.events)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(e.time,
                              style: mono.copyWith(
                                  color: skin.color.fgMuted, fontSize: 11)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.text, style: mono)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
