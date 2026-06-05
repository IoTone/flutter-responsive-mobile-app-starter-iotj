// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/meshcore_controller.dart';

/// R53 — the Docs tab: a menu into the three offline-readable docs
/// (companion protocol, device firmware, and this app). Rendered in the
/// futuristic monospace style; each row opens a [DocReaderScreen].
class DocsHubScreen extends StatelessWidget {
  const DocsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final String? fw = mc.deviceInfo?.firmwareVersion;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: <Widget>[
        Text(
          l.docsHubTitle.toUpperCase(),
          style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 20,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
              color: cs.primary),
        ),
        const SizedBox(height: 4),
        Text(
          l.docsHubSubtitle,
          style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              height: 1.4,
              color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        _DocCard(
          icon: Icons.terminal,
          title: l.docsProtocolTitle,
          subtitle: l.docsProtocolSub,
          onTap: () => context.push('/docs/protocol'),
        ),
        _DocCard(
          icon: Icons.memory,
          title: l.docsFirmwareTitle,
          subtitle: (fw == null || fw.isEmpty)
              ? l.docsFirmwareSub
              : l.docsFirmwareSubVersion(fw),
          onTap: () => context.push('/docs/firmware'),
        ),
        _DocCard(
          icon: Icons.smartphone,
          title: l.docsAppTitle,
          subtitle: l.docsAppSub,
          onTap: () => context.push('/docs/app'),
        ),
        const SizedBox(height: 16),
        Text(
          l.docsHubFooter,
          style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10.5,
              height: 1.5,
              color: cs.onSurfaceVariant.withValues(alpha: .8)),
        ),
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outline.withValues(alpha: .4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title.toUpperCase(),
                        style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 14,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11.5,
                            height: 1.35,
                            color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
