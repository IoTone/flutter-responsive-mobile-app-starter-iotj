import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

class _ChatScreenState extends State<ChatScreen> {
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
    final TtsController tts = context.watch<TtsController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool ready = mc.state == MeshcoreConnectionState.ready;
    final int active = mc.activeChannel;
    final List<ChatMessage> msgs = mc.messagesFor(active);
    _autoScroll(msgs.length);

    final bool muted = tts.isChannelMuted(active);
    final bool speaks = tts.channelSpeaks(active);

    return Column(
      children: <Widget>[
        // Header: active channel + per-channel TTS toggle + collapse.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'CHANNEL · ${mc.activeChannelName.toUpperCase()}',
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      letterSpacing: 3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Manage channels',
                onPressed: () => context.push('/settings/channels'),
                icon: const Icon(Icons.tag),
              ),
              IconButton(
                tooltip: !tts.enabled
                    ? 'Enable TTS in App settings'
                    : muted
                        ? 'TTS muted for this channel'
                        : 'TTS reading this channel',
                onPressed: tts.enabled
                    ? () => tts.toggleChannelMute(active)
                    : null,
                icon: Icon(
                  !tts.enabled
                      ? Icons.volume_off_outlined
                      : speaks
                          ? Icons.volume_up
                          : Icons.volume_off,
                  color: speaks ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: _stripCollapsed
                    ? 'Show channels'
                    : 'Hide channels',
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
                for (final MapEntry<int, String> ch in mc.channels)
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
                  child: Text('— no messages on this channel —',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (BuildContext _, int i) =>
                      _MessageRow(msgs[i]),
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
                          ? 'Message ${mc.activeChannelName}'
                          : 'Connect a radio to send',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Send',
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
  const _MessageRow(this.m);
  final ChatMessage m;

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text('$time $tag',
                style: TextStyle(
                    color: m.outgoing ? cs.primary : cs.onSurfaceVariant,
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
        ],
      ),
    );
  }
}
