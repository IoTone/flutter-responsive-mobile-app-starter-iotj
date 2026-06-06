// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/app_localizations.dart';
import '../../meshcore/meshcore_controller.dart';
import '../../theme/mm_skin.dart';
import '../../ui/mm_audio_toggle.dart';
import '../../ui/mm_scaffold.dart';
import '../device_manager_sheet.dart';
import 'dashboard_model.dart';

/// Concept E — **DR Pop** dashboard: Designers-Republic maximalism. Flat
/// saturated colour blocks, bold numerals, katakana run as graphics, and
/// a fake generated "sub-brand" per channel (the Wipeout team-livery idea
/// applied to mesh channels). Loud and graphic; the parity rules keep
/// colour from being a sole information carrier (every block carries a
/// label + value too). Same DashboardModel as every skin.
class DrPopDashboard extends StatelessWidget {
  const DrPopDashboard({super.key});

  // Wipeout-flavoured fake corp names + katakana, picked deterministically
  // per channel so a channel always wears the same livery.
  static const List<String> _brands = <String>[
    'AURICOM', 'FEISAR', 'QIREX', 'AG-SYS', 'PIRHANA', 'GOTEKI',
    'ASSEGAI', 'TIGRON',
  ];
  static const List<String> _kata = <String>[
    'ツウシン', 'ノード', 'メッシュ', 'デンパ', 'コウシン',
  ];

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final MmSkin skin = context.skin;
    final DashboardModel m = DashboardModel.gather(mc, l);

    final Color magenta = skin.color.accent;
    final Color acid = skin.color.ok;
    const Color cyan = Color(0xFF00C2FF);
    final List<Color> livery = <Color>[magenta, acid, cyan];

    final int ch = mc.activeChannel;
    final int hash = ch.abs();
    final String brand = _brands[hash % _brands.length];
    final Color brandColor = livery[hash % livery.length];
    final String kata = _kata[hash % _kata.length];
    final int act = mc.messagesFor(ch).length;

    return MmScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: <Widget>[
          // Brand bar — magenta slab + PHASE code.
          Row(
            children: <Widget>[
              Expanded(
                child: Text('MESHMORE™',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: skin.type.headingFamily,
                        color: magenta,
                        fontSize: 20,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800)),
              ),
              Text('PHASE_${ch.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      color: skin.color.fgMuted,
                      fontFamily: skin.type.monoFamily,
                      fontSize: 12,
                      letterSpacing: 1)),
              const MmAudioToggle(),
              IconButton(
                tooltip: 'BLE',
                icon: Icon(Icons.bluetooth,
                    size: 20,
                    color: m.alert ? skin.color.alert : magenta),
                onPressed: () => DeviceManagerSheet.show(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Hero row — PEERS (acid) + STATUS (magenta / alert).
          Row(
            children: <Widget>[
              Expanded(
                child: _Block(
                  skin: skin,
                  color: acid,
                  label: l.dashHyperPeers,
                  value: '${m.peersInRange}',
                  accent: 'ノード',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Block(
                  skin: skin,
                  color: m.alert ? skin.color.alert : magenta,
                  label: l.dashDrPopLink,
                  value: m.statusLabel,
                  valueSize: 18,
                  accent: 'ツウシン',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Channel sub-brand block — the generated livery.
          _SubBrandBlock(
            skin: skin,
            color: brandColor,
            brand: brand,
            channel: m.channelLabel,
            kata: kata,
            activity: act,
          ),
          const SizedBox(height: 8),
          // KNOWN + BATTERY row.
          Row(
            children: <Widget>[
              Expanded(
                child: _Block(
                  skin: skin,
                  color: cyan,
                  label: l.dashNervKnown,
                  value: '${m.knownCount}',
                  accent: 'メッシュ',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Block(
                  skin: skin,
                  color: skin.color.surfaceAlt,
                  label: l.dashboardBattery,
                  value: m.batteryLine ?? '—',
                  valueSize: 20,
                  outline: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Radio line as a thin coded strip.
          Container(
            width: double.infinity,
            color: skin.color.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text('通信 ${m.radioLine ?? '—'}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: skin.color.fg,
                    fontFamily: skin.type.monoFamily,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// A flat saturated colour block. Text colour flips to dark or light for
/// contrast against the block — never relying on colour alone (parity).
class _Block extends StatelessWidget {
  const _Block({
    required this.skin,
    required this.color,
    required this.label,
    required this.value,
    this.accent,
    this.valueSize = 40,
    this.outline = false,
  });

  final MmSkin skin;
  final Color color;
  final String label;
  final String value;
  final String? accent;
  final double valueSize;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final Color ink =
        color.computeLuminance() > 0.45 ? const Color(0xFF101014) : skin.color.fg;
    final Color sub = ink.withValues(alpha: 0.7);
    return Container(
      height: 116,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: outline ? skin.color.surface : color,
        border: outline ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: TextStyle(
                  color: outline ? skin.color.fgMuted : sub,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: outline ? skin.color.fg : ink,
                  fontFamily: skin.type.monoFamily,
                  fontSize: valueSize,
                  height: 1.0,
                  fontWeight: FontWeight.w700)),
          if (accent != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(accent!,
                style: TextStyle(
                    color: outline ? skin.color.fgMuted : sub,
                    fontSize: 13,
                    letterSpacing: 2)),
          ],
        ],
      ),
    );
  }
}

class _SubBrandBlock extends StatelessWidget {
  const _SubBrandBlock({
    required this.skin,
    required this.color,
    required this.brand,
    required this.channel,
    required this.kata,
    required this.activity,
  });

  final MmSkin skin;
  final Color color;
  final String brand;
  final String channel;
  final String kata;
  final int activity;

  @override
  Widget build(BuildContext context) {
    final Color ink =
        color.computeLuminance() > 0.45 ? const Color(0xFF101014) : skin.color.fg;
    final int filled = (activity.clamp(0, 5));
    final String bars =
        '${'▮' * filled}${'▯' * (5 - filled)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('[$brand·NET]',
                  style: TextStyle(
                      color: ink,
                      fontFamily: skin.type.monoFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const Spacer(),
              Text(kata,
                  style: TextStyle(
                      color: ink.withValues(alpha: 0.75),
                      fontSize: 14,
                      letterSpacing: 3)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(channel,
                  style: TextStyle(
                      color: ink,
                      fontFamily: skin.type.monoFamily,
                      fontSize: 30,
                      height: 1.0,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(bars,
                  style: TextStyle(
                      color: ink, fontSize: 18, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }
}
