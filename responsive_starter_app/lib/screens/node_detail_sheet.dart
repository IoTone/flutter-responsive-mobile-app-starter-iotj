// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen/app_localizations.dart';
import '../meshcore/chat_message.dart';
import '../meshcore/discovered_node.dart';
import '../util/geo.dart' as geo;

/// R18 polish — modal bottom sheet shown when the user taps a node
/// on the /grid view. Shows summary stats (signal, last heard,
/// distance, lat/lon) and gives the three primary node actions:
/// **Message**, **Favourite/Unfavourite**, and a placeholder for
/// **Show on geocoded map** (R25, deferred).
class NodeDetailSheet extends StatefulWidget {
  const NodeDetailSheet({
    super.key,
    required this.node,
    required this.distanceMeters,
    required this.isFavourite,
    required this.isKnown,
    required this.onToggleFavourite,
    this.tags = const <String>[],
    this.tagSuggestions = const <String>[],
    this.onAddTag,
    this.onRemoveTag,
    this.isSelf = false,
    this.recentDms = const <ChatMessage>[],
  });

  final DiscoveredNode node;
  final double? distanceMeters;
  final bool isFavourite;
  final bool isKnown;
  final VoidCallback onToggleFavourite;

  /// R28 — current free-text tags for this node.
  final List<String> tags;

  /// R28 — autocomplete pool: every tag previously used anywhere in
  /// the app. Empty list disables autocomplete.
  final List<String> tagSuggestions;

  /// R28 — add a tag (controller-side persistence). When null, the
  /// add affordance is hidden (e.g. a sheet used in a read-only
  /// context).
  final ValueChanged<String>? onAddTag;

  /// R28 — remove a tag. When null, tag chips render without the
  /// delete X.
  final ValueChanged<String>? onRemoveTag;

  /// Most-recent DMs exchanged with this peer, oldest → newest. The
  /// sheet renders the last few of these as a "RECENT DMS" excerpt
  /// (Option D inbox surfacing).
  final List<ChatMessage> recentDms;

  /// True when [node] is *our own* pubkey — suppress Message + the
  /// favourite affordance because "DM yourself" / "favourite yourself"
  /// are meaningless. Belt-and-suspenders: /grid already filters our
  /// own pubkey out of the visible fleet, but this guards against
  /// future code paths that might land here directly.
  final bool isSelf;

  @override
  State<NodeDetailSheet> createState() => _NodeDetailSheetState();
}

class _NodeDetailSheetState extends State<NodeDetailSheet> {
  late bool _fav = widget.isFavourite;

  /// Local mirror so the chips refresh between rebuilds — the
  /// controller path is async (persist → notifyListeners) and the
  /// sheet is shown via showModalBottomSheet, so we may not get a
  /// re-build from the provider before the user removes another.
  late List<String> _localTags = List<String>.from(widget.tags);

  void _toggle() {
    widget.onToggleFavourite();
    setState(() => _fav = !_fav);
  }

  Future<void> _promptAddTag(AppLocalizations l) async {
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _AddTagDialog(
        existing: _localTags,
        suggestions: widget.tagSuggestions,
        l: l,
      ),
    );
    if (picked == null || picked.isEmpty) return;
    if (_localTags.any(
        (String e) => e.toLowerCase() == picked.toLowerCase())) {
      return;
    }
    setState(() => _localTags = <String>[..._localTags, picked]);
    widget.onAddTag?.call(picked);
  }

  void _removeTag(String tag) {
    setState(() => _localTags = <String>[
          for (final String t in _localTags)
            if (t.toLowerCase() != tag.toLowerCase()) t,
        ]);
    widget.onRemoveTag?.call(tag);
  }

  String _ago(int unixSec, AppLocalizations l) {
    final int delta =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - unixSec;
    if (delta < 60) return l.nodeDetailAgoSeconds(delta);
    if (delta < 3600) return l.nodeDetailAgoMinutes((delta / 60).floor());
    if (delta < 86400) {
      return l.nodeDetailAgoHours((delta / 3600).floor());
    }
    return l.nodeDetailAgoDays((delta / 86400).floor());
  }

  @override
  Widget build(BuildContext context) {
    final DiscoveredNode n = widget.node;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final String name = n.name.isEmpty ? n.shortId : n.name;
    final String? distance =
        geo.formatDistance(widget.distanceMeters);

    Widget chip(IconData icon, String label, Color colour) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colour.withValues(alpha: .45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 12, color: colour),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: colour, fontSize: 11, letterSpacing: 1)),
            ],
          ),
        );

    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 84,
                child: Text(k,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 12)),
              ),
              Expanded(
                child: Text(v,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.35)),
              ),
            ],
          ),
        );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (n.inRange)
                  chip(Icons.sensors, l.nodeDetailInRange, cs.primary),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                chip(Icons.cell_tower, n.typeLabel, cs.onSurfaceVariant),
                if (widget.isKnown)
                  chip(Icons.chat_bubble, l.nodeDetailKnown, cs.primary),
                if (_fav)
                  chip(Icons.star, l.nodeDetailContactBadge, cs.tertiary),
              ],
            ),
            const SizedBox(height: 14),
            kv(l.nodeDetailShortIdKv, n.shortId),
            kv(
                l.nodeDetailPubkeyKv,
                n.pubKeyHex.length > 24
                    ? '${n.pubKeyHex.substring(0, 24)}…'
                    : n.pubKeyHex),
            if (n.signalLabel.isNotEmpty)
              kv(l.nodeDetailSignalKv, n.signalLabel),
            kv(l.nodeDetailLastHeardKv, _ago(n.lastHeardUnix, l)),
            if (distance != null)
              kv(l.nodeDetailDistanceKv, distance),
            if (n.hasLocation)
              kv(l.nodeDetailLatLonKv,
                  '${n.latitude!.toStringAsFixed(5)}, '
                      '${n.longitude!.toStringAsFixed(5)}'),
            if (widget.isSelf) ...<Widget>[
              const SizedBox(height: 8),
              Text(l.nodeDetailSelf,
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      fontSize: 12)),
            ],
            // Option D — RECENT DMS excerpt. Suppressed for own node.
            if (!widget.isSelf && widget.recentDms.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(l.nodeDetailRecentDms,
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 3)),
              const SizedBox(height: 6),
              for (final ChatMessage m
                  in widget.recentDms.length > 3
                      ? widget.recentDms.sublist(
                          widget.recentDms.length - 3)
                      : widget.recentDms)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 56,
                        child: Text(
                          '${m.at.hour.toString().padLeft(2, '0')}:'
                          '${m.at.minute.toString().padLeft(2, '0')} '
                          '${m.outgoing ? '»' : '«'}',
                          style: TextStyle(
                              color: m.outgoing
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              fontFamily: 'monospace',
                              fontSize: 11),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          m.text.length > 64
                              ? '${m.text.substring(0, 64)}…'
                              : m.text,
                          style: TextStyle(
                              color: cs.onSurface, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            // R28 — Tags row. Renders an existing-chip strip + a
            // "+ tag" input chip. Hidden entirely when no tags AND
            // no onAddTag — keeps the sheet quiet in read-only
            // contexts (e.g. peer-summary embeds we might add later).
            if (_localTags.isNotEmpty || widget.onAddTag != null) ...<Widget>[
              const SizedBox(height: 14),
              Text(l.nodeDetailTags,
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 2)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final String t in _localTags)
                    InputChip(
                      label: Text(t),
                      onDeleted: widget.onRemoveTag == null
                          ? null
                          : () => _removeTag(t),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.onAddTag != null)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: Text(l.nodeDetailAddTag),
                      onPressed: () => _promptAddTag(l),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (!widget.isSelf)
              Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.send),
                    label: Text(l.nodeDetailMessage),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/dm/${n.pubKeyHex}');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(_fav ? Icons.star : Icons.star_border),
                    label: Text(_fav
                        ? l.nodeDetailContact
                        : l.nodeDetailFavourite),
                    onPressed: _toggle,
                  ),
                ),
              ],
            ),
            // "Show on map" — opens the platform's mapping app
            // (Apple Maps on iOS, Google Maps web URL elsewhere)
            // pinned at the node's lat/lon. Disabled if the node
            // doesn't have a known location yet.
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: Text(l.nodeDetailShowOnMap),
              onPressed: n.hasLocation
                  ? () => _openInMaps(context, n, l)
                  : null,
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l.nodeDetailCopyPubkey),
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: n.pubKeyHex));
                if (!context.mounted) return;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(l.nodeDetailPubkeyCopied),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Open the platform's mapping app at the node's pin. iOS goes
  /// to Apple Maps natively (`maps.apple.com/?ll=LAT,LON&q=NAME`),
  /// everything else gets Google Maps via web URL (works whether
  /// or not the Google Maps app is installed — the OS resolves
  /// it).
  Future<void> _openInMaps(
      BuildContext context, DiscoveredNode n, AppLocalizations l) async {
    final String lat = n.latitude!.toStringAsFixed(6);
    final String lon = n.longitude!.toStringAsFixed(6);
    final String label = Uri.encodeQueryComponent(
        n.name.isEmpty ? n.shortId : n.name);
    final bool isApple =
        !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    final Uri uri = isApple
        ? Uri.parse('https://maps.apple.com/?ll=$lat,$lon&q=$label')
        : Uri.parse('https://www.google.com/maps?q=$lat,$lon');
    final bool ok =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l.nodeDetailShowOnMapFailed),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// R28 — modal text-entry dialog with previously-used tags as chip
/// suggestions. Returning [Navigator.pop]'s argument is the new tag
/// (or null on cancel).
class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog({
    required this.existing,
    required this.suggestions,
    required this.l,
  });
  final List<String> existing;
  final List<String> suggestions;
  final AppLocalizations l;

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool _isExisting(String s) => widget.existing
      .any((String e) => e.toLowerCase() == s.trim().toLowerCase());

  void _submit() {
    final String t = _input.text.trim();
    if (t.isEmpty) return;
    if (_isExisting(t)) {
      Navigator.pop(context); // already attached — nothing to do
      return;
    }
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = widget.l;
    // Filter suggestions: don't suggest tags already on the node.
    final List<String> unusedSuggestions = <String>[
      for (final String s in widget.suggestions)
        if (!_isExisting(s)) s,
    ];
    return AlertDialog(
      title: Text(l.nodeDetailAddTagTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _input,
            autofocus: true,
            decoration: InputDecoration(
                hintText: l.nodeDetailAddTagHint,
                isDense: true),
            onSubmitted: (_) => _submit(),
            maxLength: 32,
          ),
          if (unusedSuggestions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(l.nodeDetailAddTagSuggestions,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String s in unusedSuggestions)
                  ActionChip(
                    label: Text(s),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context, s),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l.nodeDetailAddTagApply),
        ),
      ],
    );
  }
}
