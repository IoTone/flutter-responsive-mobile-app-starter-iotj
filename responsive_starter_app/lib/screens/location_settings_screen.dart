// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/auto_publish_controller.dart';
import '../meshcore/meshcore_controller.dart';

/// R36 — App settings → Auto-publish location.
///
/// Master toggle, periodic interval picker, smart-broadcast
/// distance picker, plus a "last published" readout so the
/// user can confirm the loop is actually firing.
class LocationSettingsScreen extends StatelessWidget {
  const LocationSettingsScreen({super.key});

  static String _intervalLabel(AppLocalizations l, int sec) {
    if (sec == 0) return l.locOff;
    if (sec < 3600) return l.locIntervalMin(sec ~/ 60);
    return l.locIntervalHour(sec ~/ 3600);
  }

  static String _movementLabel(AppLocalizations l, int m) {
    if (m == 0) return l.locOff;
    if (m < 1000) return l.locMovementM(m);
    return l.locMovementKm(m ~/ 1000);
  }

  @override
  Widget build(BuildContext context) {
    final AutoPublishController ap =
        context.watch<AutoPublishController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final MeshcoreController mc = context.read<MeshcoreController>();

    return Scaffold(
      appBar: AppBar(title: Text(l.locTitle)),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              l.locHelp,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
          // Master toggle.
          SwitchListTile(
            title: Text(l.locMaster),
            subtitle: Text(
              ap.enabled ? l.locMasterOn : l.locMasterOff,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .6)),
            ),
            secondary: Icon(
                ap.enabled ? Icons.satellite_alt : Icons.satellite,
                color: ap.enabled ? cs.primary : cs.onSurfaceVariant),
            value: ap.enabled,
            onChanged: (bool v) => ap.setEnabled(v),
          ),
          const Divider(height: 1),
          // Periodic interval.
          ListTile(
            enabled: ap.enabled,
            leading: const Icon(Icons.timer_outlined),
            title: Text(l.locInterval),
            subtitle: Text(
              _intervalLabel(l, ap.intervalSec),
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .6)),
            ),
            onTap: !ap.enabled
                ? null
                : () => _pickInterval(context, ap, l),
          ),
          // Smart-broadcast distance.
          ListTile(
            enabled: ap.enabled,
            leading: const Icon(Icons.straighten),
            title: Text(l.locMovement),
            subtitle: Text(
              _movementLabel(l, ap.minMovementMeters),
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .6)),
            ),
            onTap: !ap.enabled
                ? null
                : () => _pickMovement(context, ap, l),
          ),
          const Divider(height: 1),
          // "Publish now" — manual trigger so the user can verify.
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(l.locPublishNow),
            subtitle: Text(l.locPublishNowSub),
            enabled: ap.enabled && mc.isReady,
            onTap: !(ap.enabled && mc.isReady)
                ? null
                : () => ap.publishNow(),
          ),
          // Last-published readout.
          if (ap.lastPublishedAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: cs.outline.withValues(alpha: .35)),
                ),
                child: Text(
                  l.locLastPublished(
                    ap.lastLat!.toStringAsFixed(5),
                    ap.lastLon!.toStringAsFixed(5),
                    _hms(ap.lastPublishedAt!),
                    ap.lastTrigger,
                  ),
                  style: TextStyle(
                      color: cs.onSurface,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12),
                ),
              ),
            ),
          // Battery transparency footer.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Text(
              l.locBatteryHint,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  static String _hms(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  Future<void> _pickInterval(BuildContext ctx,
      AutoPublishController ap, AppLocalizations l) async {
    final int? picked = await showModalBottomSheet<int>(
      context: ctx,
      builder: (BuildContext _) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final int s in AutoPublishController.intervalOptions)
              ListTile(
                dense: true,
                leading: Icon(
                  ap.intervalSec == s
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_intervalLabel(l, s)),
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await ap.setIntervalSec(picked);
  }

  Future<void> _pickMovement(BuildContext ctx,
      AutoPublishController ap, AppLocalizations l) async {
    final int? picked = await showModalBottomSheet<int>(
      context: ctx,
      builder: (BuildContext _) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final int m
                in AutoPublishController.movementOptions)
              ListTile(
                dense: true,
                leading: Icon(
                  ap.minMovementMeters == m
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_movementLabel(l, m)),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await ap.setMinMovementMeters(picked);
  }
}
