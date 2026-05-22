// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../chat/chat_actions.dart';
import '../gen/app_localizations.dart';
import '../meshcore/chat_message.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import '../tts/tts_controller.dart';

/// R6 — the channel chat. A channel-selector chip strip on top
/// (collapsible to reclaim vertical space), a scrollable message list
/// for the active channel, a composer, and a per-channel TTS toggle in
/// the header (R5; only meaningful while the global switch is on).
///
/// Lives inside [HomeShell]'s `PageView` (the shell owns the AppBar),
/// so this is a plain [Column], not a [Scaffold].
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin<ChatScreen> {
  // Keep state alive across PageView swipes — first build pays the
  // construction cost; returning to this tab is then near-free.
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<ChatMessage>? _incomingSub;
  bool _stripCollapsed = false;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    final MeshcoreController mc = context.read<MeshcoreController>();
    final TtsController tts = context.read<TtsController>();
    // Speak inbound channel messages (the gate — global on + channel
    // not muted — lives inside the controller).
    _incomingSub = mc.incomingChannelMessages.listen((ChatMessage m) {
      unawaited(tts.speakForChannel(m.channelIdx, m.text));
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(MeshcoreController mc) {
    final String t = _input.text;
    if (t.trim().isEmpty) return;
    unawaited(mc.sendChannelText(t));
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
    super.build(context); // for AutomaticKeepAliveClientMixin

    // Selectorised subscriptions — only rebuild this screen when one
    // of these specific slices changes. Avoids per-advert / per-
    // battery-sample / per-drain rebuilds that the previous
    // `context.watch<MeshcoreController>()` would cause.
    final bool ready = context.select<MeshcoreController, bool>(
        (MeshcoreController mc) =>
            mc.state == MeshcoreConnectionState.ready);
    final int active = context.select<MeshcoreController, int>(
        (MeshcoreController mc) => mc.activeChannel);
    final String activeName = context.select<MeshcoreController, String>(
        (MeshcoreController mc) => mc.activeChannelName);
    final List<MapEntry<int, String>> channels =
        context.select<MeshcoreController, List<MapEntry<int, String>>>(
            (MeshcoreController mc) => mc.channels);
    final List<ChatMessage> msgs =
        context.select<MeshcoreController, List<ChatMessage>>(
            (MeshcoreController mc) => mc.messagesFor(active));
    final bool ttsEnabled = context.select<TtsController, bool>(
        (TtsController t) => t.enabled);
    final bool muted = context.select<TtsController, bool>(
        (TtsController t) => t.isChannelMuted(active));
    final bool speaks = context.select<TtsController, bool>(
        (TtsController t) => t.channelSpeaks(active));

    // Read (no listen) for action callbacks + values we deliberately
    // didn't list above (channel name + chip list are derived from
    // cached state, so they update via the slices we *do* watch).
    final MeshcoreController mc = context.read<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    _autoScroll(msgs.length);
    final AppLocalizations l = AppLocalizations.of(context);

    return Column(
      children: <Widget>[
        // Header: active channel + per-channel TTS toggle + collapse.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.chatChannelHeader(activeName.toUpperCase()),
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      letterSpacing: 3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: l.chatManageChannels,
                onPressed: () => context.push('/settings/channels'),
                icon: const Icon(Icons.tag),
              ),
              IconButton(
                tooltip: !ttsEnabled
                    ? l.chatTtsDisabledHint
                    : muted
                        ? l.chatTtsMuted
                        : l.chatTtsActive,
                onPressed: ttsEnabled
                    ? () => context
                        .read<TtsController>()
                        .toggleChannelMute(active)
                    : null,
                icon: Icon(
                  !ttsEnabled
                      ? Icons.volume_off_outlined
                      : speaks
                          ? Icons.volume_up
                          : Icons.volume_off,
                  color: speaks ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: _stripCollapsed
                    ? l.chatShowChannels
                    : l.chatHideChannels,
                onPressed: () => setState(
                    () => _stripCollapsed = !_stripCollapsed),
                icon: Icon(_stripCollapsed
                    ? Icons.unfold_more
                    : Icons.unfold_less),
              ),
            ],
          ),
        ),

        // Channel selector chip strip (collapsible).
        if (!_stripCollapsed)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                for (final MapEntry<int, String> ch in channels)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(ch.value),
                      selected: ch.key == active,
                      onSelected: (_) => mc.setActiveChannel(ch.key),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),

        // Message list (active channel).
        Expanded(
          child: msgs.isEmpty
              ? Center(
                  child: Text(l.chatEmpty,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (BuildContext _, int i) => _MessageRow(
                    msgs[i],
                    onAction: () => _onAction(mc, msgs[i]),
                  ),
                ),
        ),

        // Composer.
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
                          ? l.chatComposerHint(activeName)
                          : l.chatComposerOffline,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.chatSend,
                  onPressed: ready ? () => _send(mc) : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow(this.m, {required this.onAction});
  final ChatMessage m;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String time = '${m.at.hour.toString().padLeft(2, '0')}:'
        '${m.at.minute.toString().padLeft(2, '0')}';
    final String tag = m.outgoing ? '»' : '«';
    final List<String> meta = <String>[
      if (m.isFlood) 'flood',
      if (m.snrDb != null) 'SNR ${m.snrDb!.toStringAsFixed(1)}',
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
