// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';
import '../meshcore/node_telemetry.dart';
import 'node_detail_sheet.dart';

/// Mesh weather — a glanceable view of the environment telemetry
/// reported across the fabric: a summary band (how many nodes are
/// reporting + min/avg/max temperature) and a list of reporting nodes
/// sorted warmest-first, each with a colour-scaled temperature chip.
///
/// Data is whatever telemetry we already hold (self + any polled or
/// overheard contact) — the background poller fills this in over time.
/// Empty until at least one node reports a sensor reading.
class WeatherView extends StatelessWidget {
  const WeatherView({super.key, this.filteredNodes});

  final List<DiscoveredNode>? filteredNodes;

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    // Build (node, telemetry) pairs that actually report environment.
    final List<_Reading> readings = <_Reading>[];
    final String? ownHex = mc.ownPubKeyHex;
    final List<DiscoveredNode> source = filteredNodes ?? mc.nodes;
    for (final DiscoveredNode n in source) {
      final NodeTelemetry? t = mc.telemetryFor(n.pubKeyHex);
      if (t != null && t.hasEnvironment) {
        readings.add(_Reading(
            name: n.name.isEmpty ? n.shortId : n.name,
            isSelf: n.pubKeyHex == ownHex,
            pubKeyHex: n.pubKeyHex,
            t: t));
      }
    }
    // Self may not be in the node list — add it explicitly.
    final NodeTelemetry? self = mc.selfTelemetry;
    if (self != null &&
        self.hasEnvironment &&
        !readings.any((_Reading r) => r.isSelf)) {
      readings.add(_Reading(
          name: l.weatherSelf, isSelf: true, pubKeyHex: ownHex, t: self));
    }

    if (readings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(l.weatherEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
        ),
      );
    }

    // Temperatures present → summary stats.
    final List<double> temps = <double>[
      for (final _Reading r in readings)
        if (r.t.temperatureC != null) r.t.temperatureC!,
    ];
    readings.sort((_Reading a, _Reading b) =>
        (b.t.temperatureC ?? -999).compareTo(a.t.temperatureC ?? -999));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        if (temps.isNotEmpty)
          _SummaryCard(
            count: readings.length,
            minC: temps.reduce((double a, double b) => a < b ? a : b),
            maxC: temps.reduce((double a, double b) => a > b ? a : b),
            avgC: temps.reduce((double a, double b) => a + b) / temps.length,
            cs: cs,
            l: l,
          ),
        const SizedBox(height: 8),
        for (final _Reading r in readings) _ReadingTile(r: r, cs: cs, l: l),
      ],
    );
  }
}

class _Reading {
  const _Reading({
    required this.name,
    required this.isSelf,
    required this.pubKeyHex,
    required this.t,
  });
  final String name;
  final bool isSelf;
  final String? pubKeyHex;
  final NodeTelemetry t;
}

/// Map a temperature to a cold→hot colour ramp (blue → teal → amber →
/// red), clamped to a comfortable everyday range.
Color temperatureColor(double c) {
  const double lo = -10, hi = 40;
  final double f = ((c - lo) / (hi - lo)).clamp(0.0, 1.0);
  // Three-stop gradient: blue (cold) → amber (mild) → red (hot).
  if (f < 0.5) {
    return Color.lerp(
        const Color(0xFF2E7DEF), const Color(0xFFE0A02E), f / 0.5)!;
  }
  return Color.lerp(
      const Color(0xFFE0A02E), const Color(0xFFE0402E), (f - 0.5) / 0.5)!;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.count,
    required this.minC,
    required this.maxC,
    required this.avgC,
    required this.cs,
    required this.l,
  });
  final int count;
  final double minC;
  final double maxC;
  final double avgC;
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, double c) => Column(
          children: <Widget>[
            Text('${c.toStringAsFixed(1)}°',
                style: TextStyle(
                    color: temperatureColor(c),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace')),
            Text(label,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
          ],
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.weatherReporting(count),
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              stat(l.weatherMin, minC),
              stat(l.weatherAvg, avgC),
              stat(l.weatherMax, maxC),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.r, required this.cs, required this.l});
  final _Reading r;
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final double? c = r.t.temperatureC;
    final List<String> extra = <String>[
      if (r.t.humidityPct != null) '${r.t.humidityPct!.toStringAsFixed(0)}%',
      if (r.t.pressureHpa != null)
        '${r.t.pressureHpa!.toStringAsFixed(0)} hPa',
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: (c != null ? temperatureColor(c) : cs.onSurfaceVariant)
              .withValues(alpha: .18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          c != null ? '${c.toStringAsFixed(1)}°' : '—',
          style: TextStyle(
              color: c != null ? temperatureColor(c) : cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace'),
        ),
      ),
      title: Row(
        children: <Widget>[
          if (r.isSelf)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.my_location, size: 14, color: cs.primary),
            ),
          Flexible(
              child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
      subtitle: Text(
        <String>[if (extra.isNotEmpty) extra.join(' · '), _ago(r.t.receivedAt, l)]
            .where((String s) => s.isNotEmpty)
            .join('  ·  '),
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
      ),
      onTap: r.pubKeyHex == null
          ? null
          : () {
              final MeshcoreController mc =
                  context.read<MeshcoreController>();
              DiscoveredNode? node;
              for (final DiscoveredNode n in mc.nodes) {
                if (n.pubKeyHex == r.pubKeyHex) {
                  node = n;
                  break;
                }
              }
              if (node == null) return;
              final DiscoveredNode peer = node;
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => NodeDetailSheet(
                  node: peer,
                  distanceMeters: peer.hasLocation
                      ? mc.distanceMetersTo(peer.latitude!, peer.longitude!)
                      : null,
                  isFavourite: mc.favorites.contains(peer.pubKeyHex),
                  isKnown: mc.known.contains(peer.pubKeyHex),
                  onToggleFavourite: () => mc.toggleFavorite(peer.pubKeyHex),
                  proximity: mc.proximityFor(peer),
                  recentDms: mc.dmHistoryFor(peer.pubKeyHex),
                  tags: mc.tagsFor(peer.pubKeyHex),
                  tagSuggestions: mc.allTags,
                  onAddTag: (String t) => mc.addTagTo(peer.pubKeyHex, t),
                  onRemoveTag: (String t) =>
                      mc.removeTagFrom(peer.pubKeyHex, t),
                ),
              );
            },
    );
  }

  static String _ago(DateTime at, AppLocalizations l) {
    final int s = DateTime.now().difference(at).inSeconds;
    if (s < 60) return l.weatherAgoSeconds(s);
    if (s < 3600) return l.weatherAgoMinutes(s ~/ 60);
    return l.weatherAgoHours(s ~/ 3600);
  }
}
