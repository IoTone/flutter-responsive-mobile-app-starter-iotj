// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/chat_actions.dart';
import '../gen/app_localizations.dart';
import '../meshcore/chat_message.dart';
import '../meshcore/discovered_node.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import 'node_detail_sheet.dart';

/// 1:1 direct-message thread with a peer (P2P). The MeshCore
/// companion protocol carries DMs over `CMD_SEND_TXT_MSG` (0x02)
/// addressed by the first 6 bytes of the peer's pubkey, and
/// `RESP_CODE_CONTACT_MSG_RECV` (0x07 / V3 0x10) on receive. We
/// thread by the peer's full pubkey when we can resolve it from the
/// fabric, else by the 12-hex prefix.
class DmScreen extends StatefulWidget {
  const DmScreen({super.key, required this.peerPubKeyHex});

  /// Full pubkey hex (64) or 12-hex prefix.
  final String peerPubKeyHex;

  @override
  State<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends State<DmScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<ChatMessage>? _sub;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    final MeshcoreController mc = context.read<MeshcoreController>();
    // No special live action needed — the controller's _ingestDm
    // already adds inbound DMs to the store and notifies. The
    // stream subscription is here only as a hook for future per-DM
    // TTS / haptic (R5/R12) without rebuilding the chat-screen
    // pattern.
    _sub = mc.incomingDirectMessages.listen((ChatMessage m) {
      // Stay caught up: any new inbound DM that lands while the
      // user is on this thread is read by definition.
      if (m.peerPubKeyHex != null) {
        mc.markDmRead(widget.peerPubKeyHex);
      }
    });
    // Opening the thread marks everything currently in it as read.
    mc.markDmRead(widget.peerPubKeyHex);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _peerName(MeshcoreController mc) {
    for (final DiscoveredNode n in mc.nodes) {
      if (n.pubKeyHex == widget.peerPubKeyHex ||
          n.pubKeyHex.startsWith(widget.peerPubKeyHex)) {
        return n.name.isEmpty ? n.shortId : n.name;
      }
    }
    return widget.peerPubKeyHex.length >= 12
        ? widget.peerPubKeyHex.substring(0, 12)
        : widget.peerPubKeyHex;
  }

  /// Find the matching [DiscoveredNode] in the fabric, by full pubkey
  /// or prefix. Null if the peer hasn't been heard from yet —
  /// shouldn't happen in practice (we got their pubkey from a DM)
  /// but we degrade gracefully.
  DiscoveredNode? _peerNode(MeshcoreController mc) {
    for (final DiscoveredNode n in mc.nodes) {
      if (n.pubKeyHex == widget.peerPubKeyHex ||
          n.pubKeyHex.startsWith(widget.peerPubKeyHex)) {
        return n;
      }
    }
    return null;
  }

  /// Open the peer's [NodeDetailSheet] — the same sheet you get
  /// from tapping a pin on /grid or /globe, scoped to this DM's
  /// peer. Gives DM users a path to favourite, tag, see distance,
  /// open-in-maps, etc. without leaving the thread.
  Future<void> _openPeerDetail(MeshcoreController mc) async {
    final DiscoveredNode? n = _peerNode(mc);
    if (n == null) {
      // The peer hasn't shown up on the fabric yet (e.g. we got a
      // DM but never heard their advert). Nothing to show; toast
      // explicitly so the user isn't left wondering why the button
      // did nothing.
      final AppLocalizations l = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l.dmPeerNotInFabric),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext _) => NodeDetailSheet(
        node: n,
        distanceMeters: n.hasLocation
            ? mc.distanceMetersTo(n.latitude!, n.longitude!)
            : null,
        isFavourite: mc.favorites.contains(n.pubKeyHex),
        isKnown: mc.known.contains(n.pubKeyHex),
        onToggleFavourite: () => mc.toggleFavorite(n.pubKeyHex),
        proximity: mc.proximityFor(n),
        recentDms: mc.dmHistoryFor(n.pubKeyHex),
        tags: mc.tagsFor(n.pubKeyHex),
        tagSuggestions: mc.allTags,
        onAddTag: (String t) => mc.addTagTo(n.pubKeyHex, t),
        onRemoveTag: (String t) => mc.removeTagFrom(n.pubKeyHex, t),
      ),
    );
  }

  void _send(MeshcoreController mc) {
    final String t = _input.text;
    if (t.trim().isEmpty) return;
    unawaited(mc.sendDirectText(widget.peerPubKeyHex, t));
    _input.clear();
  }

  Future<void> _onAction(MeshcoreController mc, ChatMessage m) async {
    final ChatAction? action = await showChatActions(context, m);
    if (action == null || !mounted) return;
    switch (action) {
      case ChatAction.reply:
        final String quote = buildReplyQuote(m);
        _input.text = quote + _input.text;
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
        break;
      case ChatAction.copy:
        await copyMessageToClipboard(context, m);
        break;
      case ChatAction.delete:
        if (!mounted) return;
        final bool ok = await confirmDeleteMessage(context, m);
        if (ok) mc.deleteMessageById(m.id);
        break;
    }
  }

  void _autoScroll(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool ready = mc.state == MeshcoreConnectionState.ready;
    final AppLocalizations l = AppLocalizations.of(context);
    final List<ChatMessage> msgs =
        mc.dmHistoryFor(widget.peerPubKeyHex);
    _autoScroll(msgs.length);
    final String pubkeyDisplay = widget.peerPubKeyHex.length >= 12
        ? '${widget.peerPubKeyHex.substring(0, 12)}…'
        : widget.peerPubKeyHex;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.dmTitle(_peerName(mc))),
        actions: <Widget>[
          IconButton(
            tooltip: l.dmOpenPeerDetail,
            icon: const Icon(Icons.info_outline),
            onPressed: () => _openPeerDetail(mc),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l.dmPubkeyLabel(pubkeyDisplay),
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 11),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: msgs.isEmpty
                ? Center(
                    child: Text(l.dmEmpty,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: msgs.length,
                    itemBuilder: (BuildContext _, int i) => _DmRow(
                      msgs[i],
                      onAction: () => _onAction(mc, msgs[i]),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: ready,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(mc),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: ready
                            ? l.dmComposerHint(_peerName(mc))
                            : l.chatComposerOffline,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.dmSend,
                    onPressed: ready ? () => _send(mc) : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DmRow extends StatelessWidget {
  const _DmRow(this.m, {required this.onAction});
  final ChatMessage m;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String time = '${m.at.hour.toString().padLeft(2, '0')}:'
        '${m.at.minute.toString().padLeft(2, '0')}';
    final String tag = m.outgoing ? '»' : '«';
    final List<String> meta = <String>[
      if (m.snrDb != null) 'SNR ${m.snrDb!.toStringAsFixed(1)}',
      if (m.isFlood) 'flood',
    ];
    return InkWell(
      onLongPress: onAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 56,
              child: Text('$time $tag',
                  style: TextStyle(
                      color:
                          m.outgoing ? cs.primary : cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: 12)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(m.text, style: TextStyle(color: cs.onSurface)),
                  if (meta.isNotEmpty)
                    Text(meta.join(' · '),
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).chatMessageActions,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                  minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
              onPressed: onAction,
              icon: Icon(Icons.more_vert,
                  color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
