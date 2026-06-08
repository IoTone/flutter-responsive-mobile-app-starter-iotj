// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/meshcore_controller.dart';
import '../sns/meshbook.dart';

/// Meshbook (MBk) — a daily readout of the current channel's social shape
/// (P1): how many messages, the reply rate, the top voices, and an hourly
/// volume histogram. Scoped to *today* (local midnight → now), recomputed
/// on build. Topics + daily-reset persistence + a refresh setting are P2/P3.
class MeshbookView extends StatelessWidget {
  const MeshbookView({super.key});

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    final int ch = mc.activeChannel;
    final DateTime now = DateTime.now();
    final DateTime dayStart = DateTime(now.year, now.month, now.day);
    final MbkDay day = MbkEngine.analyse(
      mc.messagesFor(ch),
      channelIdx: ch,
      dayStart: dayStart,
      now: now,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.menu_book_outlined, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('${l.meshbookTitle} · CH$ch · ${l.meshbookToday}',
                style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        if (day.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(l.meshbookEmpty,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          )
        else ...<Widget>[
          Text(
            l.meshbookStats(
                day.total, day.replies, day.replyPercent, day.voices),
            style: TextStyle(color: cs.onSurface, fontSize: 15),
          ),
          const SizedBox(height: 18),
          Text(l.meshbookByHour,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 6),
          _Hourly(day: day, nowHour: now.hour, cs: cs),
          const SizedBox(height: 18),
          Text(l.meshbookTopVoices,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 6),
          for (int i = 0; i < day.top.length; i++)
            _VoiceRow(
                rank: i + 1,
                sender: day.top[i],
                maxCount: day.top.first.count,
                cs: cs,
                l: l),
          if (day.topics.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Text(l.meshbookTopics,
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final MbkTopic t in day.topics)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('${t.term} ·${t.count}',
                        style: TextStyle(
                            color: cs.onSurface, fontSize: 13)),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _Hourly extends StatelessWidget {
  const _Hourly({required this.day, required this.nowHour, required this.cs});
  final MbkDay day;
  final int nowHour;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final int peak = day.peakHour;
    return Column(
      children: <Widget>[
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int h = 0; h < 24; h++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: peak == 0
                        ? 2
                        : 2 + (day.hourly[h] / peak) * 46,
                    decoration: BoxDecoration(
                      color: h == nowHour
                          ? cs.primary
                          : cs.primary.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Sparse hour ticks (00 · 06 · 12 · 18).
        Row(
          children: <Widget>[
            for (int h = 0; h < 24; h++)
              Expanded(
                child: Text(
                    (h % 6 == 0) ? h.toString().padLeft(2, '0') : '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 9,
                        fontFamily: 'JetBrains Mono')),
              ),
          ],
        ),
      ],
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.rank,
    required this.sender,
    required this.maxCount,
    required this.cs,
    required this.l,
  });

  final int rank;
  final MbkSender sender;
  final int maxCount;
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final double frac = maxCount == 0 ? 0 : sender.count / maxCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text('$rank',
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(sender.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: cs.onSurface, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 4,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('${sender.count}',
              style: TextStyle(
                  color: cs.onSurface,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          if (sender.replies > 0) ...<Widget>[
            const SizedBox(width: 6),
            Text('↩${sender.replies}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
