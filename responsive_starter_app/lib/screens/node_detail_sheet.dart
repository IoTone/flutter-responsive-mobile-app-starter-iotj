// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:meshcore/meshcore.dart' show Contact;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen/app_localizations.dart';
import '../meshcore/chat_message.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_controller.dart';
import '../meshcore/node_telemetry.dart';
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
    this.proximity = NodeProximity.unknown,
    this.tags = const <String>[],
    this.tagSuggestions = const <String>[],
    this.onAddTag,
    this.onRemoveTag,
    this.isSelf = false,
    this.recentDms = const <ChatMessage>[],
  });

  final DiscoveredNode node;
  final double? distanceMeters;

  /// Spatial-aware proximity classification for the IN RANGE / FAR
  /// header badge. Default `unknown` shows no badge — caller should
  /// pass `mc.proximityFor(node)` so the sheet matches the list view.
  final NodeProximity proximity;
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

  /// Confirm + move the user's data from the stale key to the live key.
  /// If we're currently viewing the stale (now-deleted) node, close the
  /// sheet afterwards since it no longer exists in the fabric.
  Future<void> _reconcile(
      MeshcoreController mc, IdentityMatch match, AppLocalizations l) async {
    final bool viewingStale =
        widget.node.pubKeyHex == match.stale.pubKeyHex;
    await mc.reconcileIdentity(
      fromPubKeyHex: match.stale.pubKeyHex,
      toPubKeyHex: match.fresh.pubKeyHex,
    );
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(l.nodeIdentityMoved(match.fresh.name)),
        duration: const Duration(seconds: 3),
      ),
    );
    if (viewingStale) Navigator.of(context).maybePop();
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
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final String name = n.name.isEmpty ? n.shortId : n.name;
    // R56 — "returning contact": a same-name node whose key changed (peer
    // deleted + re-added). Offer to move the user's data to the live key.
    final IdentityMatch? idMatch =
        widget.isSelf ? null : mc.identityMatchFor(n.pubKeyHex);
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
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        height: 1.35)),
              ),
            ],
          ),
        );

    return SafeArea(
      top: false,
      // The sheet content can exceed the sheet's height (e.g. a contact
      // with telemetry + share toggles + tags) — scroll it so it never
      // overflows the DraggableScrollableSheet.
      child: SingleChildScrollView(
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
                // R28+ spatial-aware: only show IN RANGE when we
                // actually believe they're close. Caller passes the
                // resolved enum via `proximity`. We fall back to
                // recently-heard (recent) for unknown-distance nodes
                // so the badge still appears for OTA-recent peers.
                if (widget.proximity == NodeProximity.near ||
                    widget.proximity == NodeProximity.recent)
                  chip(Icons.sensors, l.nodeDetailInRange, cs.primary),
                if (widget.proximity == NodeProximity.far)
                  chip(Icons.travel_explore, l.nodesFarBadge,
                      cs.onSurfaceVariant),
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
            if (idMatch != null) ...<Widget>[
              const SizedBox(height: 12),
              _ReconcileCard(
                match: idMatch,
                onMove: () => _reconcile(mc, idMatch, l),
              ),
            ],
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
            // R49+1 — hop value, matching the official app's
            // categories: Direct (0 hops) / N via repeaters / Flood
            // (reachable, no fixed path) / unknown (advert-only, not
            // a contact at all).
            if (!widget.isSelf)
              kv(
                l.nodeDetailHopsKv,
                n.outPathHashes != null
                    ? (n.outPathHashes!.isEmpty
                        ? l.nodeDetailHopsDirect
                        : l.nodeDetailHopsViaRepeaters(
                            n.outPathHashes!.length))
                    : n.viaFlood
                        ? l.nodeDetailHopsFlood
                        : l.nodeDetailHopsUnknown,
              ),
            // R47 — peer telemetry on tap. CMD_SEND_TELEMETRY_REQ goes
            // to the device, which unicasts to the peer over the air;
            // the peer's response arrives async and lands in the
            // controller's _telemetry cache (keyed by pubkey6).
            // Self-telemetry already polled on every ready, so no
            // button needed there.
            _TelemetrySection(node: n, isSelf: widget.isSelf, kv: kv),
            if (!widget.isSelf)
              _ContactTelemetryShareSection(node: n),
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
                              fontFamily: 'JetBrains Mono',
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

/// R54 follow-on — grant this *contact* permission to read our
/// telemetry. Only relevant when the device's telemetry mode is
/// "Contacts" (ALLOW_FLAGS); writes the per-contact flag bits via
/// ADD_UPDATE_CONTACT. Hidden for advert-only (non-contact) nodes,
/// since telemetry is contact-only.
class _ContactTelemetryShareSection extends StatelessWidget {
  const _ContactTelemetryShareSection({required this.node});

  final DiscoveredNode node;

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Contact? c = mc.contactRecordFor(node.pubKeyHex);
    if (c == null) return const SizedBox.shrink();

    Widget row(String label, bool value, void Function(bool) onChanged) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(label, style: const TextStyle(fontSize: 13)),
          value: value,
          onChanged: onChanged,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Text(l.nodeDetailShareTelemetryTitle,
            style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                letterSpacing: 1)),
        Text(l.nodeDetailShareTelemetryHelp,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
        row(l.otherTelemetryBase, c.allowsTelemBase,
            (bool v) => mc.setContactTelemetryPermissions(node.pubKeyHex,
                base: v)),
        row(l.otherTelemetryLoc, c.allowsTelemLocation,
            (bool v) => mc.setContactTelemetryPermissions(node.pubKeyHex,
                location: v)),
        row(l.otherTelemetryEnv, c.allowsTelemEnvironment,
            (bool v) => mc.setContactTelemetryPermissions(node.pubKeyHex,
                environment: v)),
      ],
    );
  }
}

/// R47 — telemetry section inside the node detail sheet. Reads the
/// controller's `_telemetry` cache via Provider so it rebuilds when a
/// 0x8B push lands. For non-self nodes also offers a button that
/// fires `CMD_SEND_TELEMETRY_REQ` over the air; that path is OTA
/// (seconds, not instant) so the section shows a spinner while
/// waiting.
class _TelemetrySection extends StatelessWidget {
  const _TelemetrySection({
    required this.node,
    required this.isSelf,
    required this.kv,
  });

  final DiscoveredNode node;
  final bool isSelf;
  final Widget Function(String, String) kv;

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final NodeTelemetry? t =
        mc.telemetryFor(node.pubKeyHex);
    final bool querying = mc.isQueryingTelemetry(node.pubKeyHex);

    // Compact age string ("2 min ago", "3 h ago", …) for the receipt
    // line. We reuse the same _ago bands as last-heard so the sheet
    // reads consistently.
    String ageOf(DateTime at) {
      final int delta =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 -
              at.millisecondsSinceEpoch ~/ 1000;
      if (delta < 60) return l.nodeDetailAgoSeconds(delta);
      if (delta < 3600) return l.nodeDetailAgoMinutes((delta / 60).floor());
      if (delta < 86400) {
        return l.nodeDetailAgoHours((delta / 3600).floor());
      }
      return l.nodeDetailAgoDays((delta / 86400).floor());
    }

    final List<Widget> children = <Widget>[];

    if (t?.altitudeMeters != null) {
      children.add(kv(
          l.nodeDetailAltitudeKv,
          l.nodeDetailAltitudeMeters(
              t!.altitudeMeters!.toStringAsFixed(1))));
    }

    // Environment sensors (BME280 etc.) — present only when the node
    // reports them in its telemetry.
    if (t?.temperatureC != null) {
      children.add(kv(l.nodeDetailTempKv,
          l.nodeDetailTempValue(t!.temperatureC!.toStringAsFixed(1))));
    }
    if (t?.humidityPct != null) {
      children.add(kv(l.nodeDetailHumidityKv,
          l.nodeDetailHumidityValue(t!.humidityPct!.toStringAsFixed(0))));
    }
    if (t?.pressureHpa != null) {
      children.add(kv(l.nodeDetailPressureKv,
          l.nodeDetailPressureValue(t!.pressureHpa!.toStringAsFixed(0))));
    }

    if (t != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Text(
          l.nodeDetailTelemetryAge(ageOf(t.receivedAt)),
          style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontStyle: FontStyle.italic),
        ),
      ));
    }

    if (!isSelf) {
      children.add(const SizedBox(height: 4));
      // Peer-telemetry requires the target to be a *synced contact*
      // on our device — the firmware does lookupContactByPubKey and
      // silently drops the request if the peer is only advert-heard.
      // outPathHashes != null is our reliable "is a contact" signal
      // (path info only arrives via ContactFrame). When it's null,
      // explain why the query can't fire instead of offering a
      // button that does nothing.
      final bool isContact = node.outPathHashes != null;
      if (!isContact) {
        children.add(Text(
          l.nodeDetailTelemetryNotContact,
          style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontStyle: FontStyle.italic),
        ));
      } else if (querying) {
        children.add(Row(
          children: <Widget>[
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text(l.nodeDetailTelemetryQuerying,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 12)),
          ],
        ));
      } else {
        children.add(OutlinedButton.icon(
          icon: const Icon(Icons.terrain, size: 18),
          label: Text(t == null
              ? l.nodeDetailQueryTelemetry
              : l.nodeDetailRefreshTelemetry),
          onPressed: mc.isReady
              ? () => unawaited(
                  mc.requestPeerTelemetry(node.pubKeyHex))
              : null,
        ));
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
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

/// R56 — the "returning contact" reconcile prompt. Shown in the node
/// sheet when a same-name node's key changed; moving is user-confirmed.
class _ReconcileCard extends StatelessWidget {
  const _ReconcileCard({required this.match, required this.onMove});

  final IdentityMatch match;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.tertiary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.tertiary.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.sync_problem, size: 16, color: cs.tertiary),
              const SizedBox(width: 6),
              Text(l.nodeIdentityTitle,
                  style: TextStyle(
                      color: cs.tertiary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.nodeIdentityBody(match.fresh.name, match.messageCount),
            style: TextStyle(color: cs.onSurface, height: 1.35, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            l.nodeIdentityOldKey(match.stale.shortId),
            style: TextStyle(
                color: cs.onSurfaceVariant,
                fontFamily: 'JetBrains Mono',
                fontSize: 11),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onMove,
              icon: const Icon(Icons.move_up, size: 18),
              label: Text(l.nodeIdentityAction),
            ),
          ),
        ],
      ),
    );
  }
}
