// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../docs/doc_section.dart';
import '../docs/docs_repository.dart';
import '../docs/markdown_view.dart';
import '../gen/app_localizations.dart';
import '../meshcore/meshcore_controller.dart';

/// R53 — reads one [DocSection]. Shows the cached-or-bundled copy
/// immediately (offline-first), then quietly refreshes from upstream;
/// the app-bar action forces a refresh and reports the outcome.
class DocReaderScreen extends StatefulWidget {
  const DocReaderScreen({super.key, required this.section});

  final DocSection section;

  @override
  State<DocReaderScreen> createState() => _DocReaderScreenState();
}

class _DocReaderScreenState extends State<DocReaderScreen> {
  DocContent? _content;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadThenRefresh());
  }

  String? get _fwVersion => widget.section == DocSection.firmware
      ? context.read<MeshcoreController>().deviceInfo?.firmwareVersion
      : null;

  Future<void> _loadThenRefresh() async {
    final DocsRepository repo = context.read<DocsRepository>();
    final DocContent loaded = await repo.load(widget.section);
    if (!mounted) return;
    setState(() => _content = loaded);

    // Opportunistic, silent refresh — no spinner, no snackbar.
    final DocContent? updated =
        await repo.refresh(widget.section, firmwareVersion: _fwVersion);
    if (!mounted || updated == null) return;
    setState(() => _content = updated);
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;
    final AppLocalizations l = AppLocalizations.of(context);
    final DocsRepository repo = context.read<DocsRepository>();
    setState(() => _refreshing = true);
    final DocContent? updated =
        await repo.refresh(widget.section, firmwareVersion: _fwVersion);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (updated != null) _content = updated;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(updated != null ? l.docsUpdated : l.docsUpToDate),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final DocContent? c = _content;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(l), style: const TextStyle(letterSpacing: 2)),
        actions: <Widget>[
          if (DocSpec.of(widget.section).remoteUrls().isNotEmpty)
            IconButton(
              tooltip: l.docsRefresh,
              onPressed: _refreshing ? null : _manualRefresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
            ),
        ],
      ),
      body: c == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ProvenanceStrip(content: c, fwVersion: _fwVersion),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    child: MarkdownView(c.markdown),
                  ),
                ),
              ],
            ),
    );
  }

  String _title(AppLocalizations l) => switch (widget.section) {
        DocSection.protocol => l.docsProtocolTitle,
        DocSection.firmware => l.docsFirmwareTitle,
        DocSection.app => l.docsAppTitle,
      };
}

/// A thin strip under the app bar telling the reader where this copy
/// came from (a baked snapshot vs an upstream copy fetched on $date),
/// and — for firmware — which device version it's matched to.
class _ProvenanceStrip extends StatelessWidget {
  const _ProvenanceStrip({required this.content, required this.fwVersion});

  final DocContent content;
  final String? fwVersion;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool cached = content.origin == DocOrigin.cached;
    final String origin = cached
        ? l.docsOriginUpdated(_ago(content.fetchedAt, l))
        : l.docsOriginBundled;
    final List<String> bits = <String>[
      origin,
      if (content.section == DocSection.firmware)
        (fwVersion == null || fwVersion!.isEmpty)
            ? l.docsFirmwareNoDevice
            : l.docsFirmwareForVersion(fwVersion!),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cs.surfaceContainerHighest.withValues(alpha: .3),
      child: Row(
        children: <Widget>[
          Icon(cached ? Icons.cloud_done_outlined : Icons.inventory_2_outlined,
              size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bits.join('  ·  '),
              style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  letterSpacing: .5,
                  color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime? at, AppLocalizations l) {
    if (at == null) return l.docsAgoJustNow;
    final int s = DateTime.now().difference(at).inSeconds;
    if (s < 60) return l.docsAgoJustNow;
    if (s < 3600) return l.docsAgoMinutes(s ~/ 60);
    if (s < 86400) return l.docsAgoHours(s ~/ 3600);
    return l.docsAgoDays(s ~/ 86400);
  }
}
