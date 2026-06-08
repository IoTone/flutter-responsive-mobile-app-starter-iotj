// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../chat/chat_actions.dart';
import '../gen/app_localizations.dart';
import '../meshcore/chat_message.dart';
import 'delivery_status_icon.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import '../meshcore/message_heat.dart' show parseChannelSenderName;
import '../theme/mm_skin.dart';
import '../theme/mm_tokens.dart';
import '../tts/tts_controller.dart';
import '../ui/mm_scaffold.dart';
import '../ui/mm_shape.dart';

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

  /// R29 — number of new messages that have arrived while the user
  /// has scrolled away from the bottom. Drives the "↓ N new" pill.
  /// Resets whenever the user returns to the bottom (manually or via
  /// the pill).
  int _unreadSinceScrollAway = 0;

  /// Cached "is the scroll near the bottom?" so the build can decide
  /// pill visibility + auto-scroll behaviour without re-querying
  /// `position` (which throws when there are no clients).
  bool _atBottom = true;

  /// Vertical slack in pixels — within this we treat the user as
  /// "at the bottom" and keep auto-following. Generous enough to
  /// survive a single new-message row appending below them without
  /// flipping state.
  static const double _bottomSlackPx = 64.0;

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
    // R29 — track scroll position so we know whether to follow the
    // newest message automatically or surface a jump-to-newest pill.
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final double maxExtent = _scroll.position.maxScrollExtent;
    final double pixels = _scroll.position.pixels;
    // "At bottom" with slack — survives a single new-row append
    // without flipping state. Empty / short lists report
    // maxScrollExtent==0 and pixels==0, also "at bottom".
    final bool nowAtBottom = (maxExtent - pixels) <= _bottomSlackPx;
    if (nowAtBottom == _atBottom) return;
    setState(() {
      _atBottom = nowAtBottom;
      if (nowAtBottom) _unreadSinceScrollAway = 0;
    });
  }

  void _jumpToNewest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    // _onScroll will null out the counter once we settle at bottom,
    // but flip the state synchronously so the pill disappears on tap
    // instead of after the animation.
    setState(() {
      _unreadSinceScrollAway = 0;
      _atBottom = true;
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _scroll.removeListener(_onScroll);
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

  /// R29 — only auto-follow new messages while the user IS at the
  /// bottom. If they've scrolled up to read history, count the new
  /// arrival(s) into [_unreadSinceScrollAway] instead so the
  /// jump-to-newest pill can offer them an explicit re-sync. The
  /// pre-R29 behaviour of yanking the viewport on every new row was
  /// hostile to anyone trying to scroll back.
  void _autoScroll(int count) {
    if (count == _lastCount) return;
    final int delta = count - _lastCount;
    _lastCount = count;
    if (_atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } else if (delta > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _unreadSinceScrollAway += delta);
      });
    }
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

    return MmScaffold(
      child: Column(
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
                // R29 — Icons.unfold_more/less reads as
                // "expand/collapse a list" generically; on a chip
                // strip it was confusing. Up/down arrows directly
                // depict "this horizontal row is hidden/showing".
                icon: Icon(_stripCollapsed
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up),
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
                      labelStyle: TextStyle(
                        color: ch.key == active
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: ch.key == active
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      onSelected: (_) => mc.setActiveChannel(ch.key),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),

        // Message list (active channel) + R29 jump-to-newest pill.
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: msgs.isEmpty
                    ? Center(
                        child: Text(l.chatEmpty,
                            style: TextStyle(
                                color: cs.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: msgs.length,
                        itemBuilder: (BuildContext ctx, int i) =>
                            _MessageRow(
                          msgs[i],
                          onAction: () => _onAction(mc, msgs[i]),
                          // The DR Pop name tag shows the cadence since this
                          // identity last spoke; only that mode reads it, so
                          // only compute it there.
                          sinceLast:
                              _chatModeFor(ctx.skin.preset) == _ChatMode.block
                                  ? _sinceLastFromSame(msgs, i)
                                  : null,
                        ),
                      ),
              ),
              // The pill only appears when the user is NOT at the
              // bottom (so they wouldn't otherwise see the newest
              // row) AND new messages have actually arrived since
              // they scrolled away. If the user scrolls up but no
              // new messages come in, no pill — silence is correct.
              if (!_atBottom && _unreadSinceScrollAway > 0)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _JumpToNewestPill(
                    count: _unreadSinceScrollAway,
                    onTap: _jumpToNewest,
                    label: l.chatJumpToNewest(_unreadSinceScrollAway),
                  ),
                ),
            ],
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
      ),
    );
  }
}

/// How a theme renders chat: a terminal **log** (SEELE / NERV / Recon
/// codec), chat **bubbles** (Hyperlocal / AG-HUD), or flat saturated
/// **blocks** (DR Pop). Per the UX brief's per-concept chat treatment.
enum _ChatMode { log, bubble, block }

_ChatMode _chatModeFor(MmThemePreset p) => switch (p) {
      MmThemePreset.hyperlocal || MmThemePreset.agHud => _ChatMode.bubble,
      MmThemePreset.drPop => _ChatMode.block,
      _ => _ChatMode.log, // seele, nerv, recon — terminal log
    };

class _MessageRow extends StatelessWidget {
  const _MessageRow(this.m, {required this.onAction, this.sinceLast});
  final ChatMessage m;
  final VoidCallback onAction;

  /// Time since the same identity last spoke on this channel (DR Pop name
  /// tag). Null = first message from them this session, or not block mode.
  final Duration? sinceLast;

  String get _time =>
      '${m.at.hour.toString().padLeft(2, '0')}:${m.at.minute.toString().padLeft(2, '0')}';

  List<String> get _meta => <String>[
        if (m.isFlood) 'flood',
        if (m.snrDb != null) 'SNR ${m.snrDb!.toStringAsFixed(1)}',
      ];

  /// Sender handle + body for incoming channel messages (`name: text`);
  /// our own outgoing messages carry no prefix.
  ({String? sender, String body}) _split() {
    if (m.outgoing) return (sender: null, body: m.text);
    final String? s = parseChannelSenderName(m.text);
    if (s == null) return (sender: null, body: m.text);
    final int i = m.text.indexOf(': ');
    return (sender: s, body: i >= 0 ? m.text.substring(i + 2) : m.text);
  }

  @override
  Widget build(BuildContext context) {
    final MmSkin skin = context.skin;
    return switch (_chatModeFor(skin.preset)) {
      _ChatMode.log => _log(context, skin),
      _ChatMode.bubble => _bubble(context, skin),
      _ChatMode.block => _block(context, skin),
    };
  }

  // --- terminal log (SEELE / NERV / Recon) ---------------------------
  Widget _log(BuildContext context, MmSkin skin) {
    final String mono = skin.type.monoFamily;
    final List<String> meta = _meta;
    return InkWell(
      onLongPress: onAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 56,
              child: Text('$_time ${m.outgoing ? '»' : '«'}',
                  style: TextStyle(
                      color: m.outgoing
                          ? skin.color.accent
                          : skin.color.fgMuted,
                      fontFamily: mono,
                      fontSize: 12)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(m.text,
                      style:
                          TextStyle(color: skin.color.fg, fontFamily: mono)),
                  _metaRow(skin, meta, mono),
                ],
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).chatMessageActions,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
              onPressed: onAction,
              icon: Icon(Icons.more_vert, color: skin.color.fgMuted),
            ),
          ],
        ),
      ),
    );
  }

  // --- chat bubbles (Hyperlocal / AG-HUD) ----------------------------
  Widget _bubble(BuildContext context, MmSkin skin) {
    final ({String? sender, String body}) s = _split();
    final Color fill = m.outgoing
        ? skin.color.accent.withValues(alpha: 0.16)
        : skin.color.surface;
    return _aligned(
      context: context,
      skin: skin,
      decoration: ShapeDecoration(
        color: fill,
        shape: mmShapeBorder(skin.shape,
            side: BorderSide(
                color: skin.color.line, width: skin.shape.borderWidth)),
      ),
      sender: s.sender,
      senderColor: skin.color.accent,
      body: s.body,
      bodyColor: skin.color.fg,
      bodyFamily: skin.type.bodyFamily,
      metaColor: skin.color.fgMuted,
    );
  }

  // --- saturated colour fields + name tags (DR Pop, Mondrian) --------
  // Each message is a flat colour field bordered like a Mondrian panel.
  // Incoming fields take the *name's* stable neon colour; in the free
  // space beside the field sits a name tag — a Space-Invader sprite
  // (unique per name, stable for the session) plus the cadence since that
  // name last spoke.
  Widget _block(BuildContext context, MmSkin skin) {
    final ({String? sender, String body}) s = _split();
    final Color base = skin.color.base;
    final String idKey = _identityKey(m);
    // A name is always the same colour for the life of the session
    // (deterministic from the handle); our own messages stay accent.
    final Color fill = m.outgoing
        ? skin.color.accent
        : _mondrianColorFor(idKey.isEmpty ? s.body : idKey);
    final Color ink = fill.computeLuminance() > 0.45 ? base : skin.color.fg;
    final List<String> meta = _meta;

    final Widget field = Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      // Mondrian black rule around every colour field.
      decoration: BoxDecoration(
          color: fill, border: Border.all(color: base, width: 3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (s.sender != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(s.sender!.toUpperCase(),
                  style: TextStyle(
                      color: ink.withValues(alpha: 0.85),
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800)),
            ),
          Text(s.body,
              style: TextStyle(
                  color: ink,
                  fontFamily: skin.type.bodyFamily,
                  fontWeight: FontWeight.w600,
                  height: 1.3)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (m.outgoing && m.delivery != null) ...<Widget>[
                DeliveryStatusIcon(m.delivery!),
                const SizedBox(width: 5),
              ],
              Text(<String>[_time, ...meta].join(' · '),
                  style: TextStyle(
                      color: ink.withValues(alpha: 0.65), fontSize: 10)),
            ],
          ),
        ],
      ),
    );

    final Widget? tag = idKey.isEmpty
        ? null
        : _NameTag(
            seedKey: idKey,
            color: fill,
            base: base,
            mono: skin.type.monoFamily,
            since: sinceLast == null
                ? null
                : _compactSince(AppLocalizations.of(context), sinceLast!),
          );

    final List<Widget> cells = <Widget>[
      Flexible(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6),
          child: field,
        ),
      ),
      if (tag != null) ...<Widget>[const SizedBox(width: 6), tag],
    ];

    return InkWell(
      onLongPress: onAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          // Incoming hugs the left (tag in the right free space); our own
          // messages hug the right (tag in the left free space).
          mainAxisAlignment:
              m.outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: m.outgoing ? cells.reversed.toList() : cells,
        ),
      ),
    );
  }

  /// Shared bubble/block scaffold: left/right aligned, optional sender
  /// header, body, and the meta/delivery footer.
  Widget _aligned({
    required BuildContext context,
    required MmSkin skin,
    required Decoration decoration,
    required String? sender,
    required Color senderColor,
    required String body,
    required Color bodyColor,
    String? bodyFamily,
    FontWeight? bodyWeight,
    required Color metaColor,
  }) {
    final List<String> meta = _meta;
    return Align(
      alignment: m.outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: InkWell(
          onLongPress: onAction,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: decoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (sender != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(sender,
                        style: TextStyle(
                            color: senderColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                Text(body,
                    style: TextStyle(
                        color: bodyColor,
                        fontFamily: bodyFamily,
                        fontWeight: bodyWeight,
                        height: 1.3)),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (m.outgoing && m.delivery != null) ...<Widget>[
                      DeliveryStatusIcon(m.delivery!),
                      const SizedBox(width: 5),
                    ],
                    Text(
                        <String>[_time, ...meta].join(' · '),
                        style: TextStyle(color: metaColor, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaRow(MmSkin skin, List<String> meta, String mono) {
    if (meta.isEmpty && !(m.outgoing && m.delivery != null)) {
      return const SizedBox.shrink();
    }
    return Row(
      children: <Widget>[
        if (m.outgoing && m.delivery != null) ...<Widget>[
          DeliveryStatusIcon(m.delivery!),
          const SizedBox(width: 5),
        ],
        if (meta.isNotEmpty)
          Text(meta.join(' · '),
              style: TextStyle(color: skin.color.fgMuted, fontSize: 11)),
      ],
    );
  }
}

// ---- DR Pop name tags (Mondrian block mode) -------------------------------

/// The identity a message is attributed to for the session: an incoming
/// channel sender's handle, or a sentinel for our own outgoing messages.
/// Empty = anonymous (no parseable `name:` prefix) → no tag.
String _identityKey(ChatMessage m) =>
    m.outgoing ? ' self' : (parseChannelSenderName(m.text) ?? '');

/// Time since the same identity last spoke before message [i] in [msgs]
/// (chronological). Null = first time we've heard this identity in-buffer.
Duration? _sinceLastFromSame(List<ChatMessage> msgs, int i) {
  final String key = _identityKey(msgs[i]);
  if (key.isEmpty) return null;
  for (int j = i - 1; j >= 0; j--) {
    if (_identityKey(msgs[j]) == key) {
      return msgs[i].at.difference(msgs[j].at);
    }
  }
  return null;
}

/// Stable 32-bit FNV-1a hash — gives each handle a deterministic colour +
/// sprite that's identical for the life of the session (and beyond), with
/// no per-session registry to maintain.
int _fnv1a(String s) {
  int h = 0x811c9dc5;
  for (final int u in s.codeUnits) {
    h = (h ^ u) & 0xffffffff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Mondrian-ish bold neon fields for DR Pop, picked deterministically per
/// identity so a name keeps its colour all session.
const List<Color> _mondrianPalette = <Color>[
  Color(0xFFFF2E88), // magenta
  Color(0xFF00C2FF), // cyan
  Color(0xFFD7FF00), // acid
  Color(0xFFFF6B2E), // orange
  Color(0xFF9B4DFF), // violet
  Color(0xFF2E7DEF), // blue
  Color(0xFFFFC400), // yellow
];

Color _mondrianColorFor(String key) =>
    _mondrianPalette[_fnv1a(key) % _mondrianPalette.length];

/// Compact "since they last spoke" — `now` / `5m` / `2h` / `3d`.
String _compactSince(AppLocalizations l, Duration d) {
  if (d.inSeconds < 60) return l.chatSinceNow;
  if (d.inMinutes < 60) return l.chatSinceMinutes(d.inMinutes);
  if (d.inHours < 24) return l.chatSinceHours(d.inHours);
  return l.chatSinceDays(d.inDays);
}

/// The free-space tag beside a DR Pop message: a Space-Invader sprite that's
/// unique to the identity, plus the cadence since they last spoke.
class _NameTag extends StatelessWidget {
  const _NameTag({
    required this.seedKey,
    required this.color,
    required this.base,
    required this.mono,
    this.since,
  });

  final String seedKey;
  final Color color;
  final Color base;
  final String mono;
  final String? since;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.all(5),
      decoration:
          BoxDecoration(color: base, border: Border.all(color: color, width: 3)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 36,
            height: 36,
            child: CustomPaint(
              painter:
                  _InvaderPainter(seed: _fnv1a(seedKey), color: color, bg: base),
            ),
          ),
          if (since != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(since!,
                maxLines: 1,
                style: TextStyle(
                    color: color,
                    fontFamily: mono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

/// A horizontally-symmetric "Space Invaders" sprite on a 5×5 grid, lit from
/// a deterministic bit stream so each seed yields a distinct little
/// creature. Mirror across the centre column gives the arcade look.
class _InvaderPainter extends CustomPainter {
  const _InvaderPainter({
    required this.seed,
    required this.color,
    required this.bg,
  });

  final int seed;
  final Color color;
  final Color bg;

  static const int _cols = 5;
  static const int _rows = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final double cw = size.width / _cols;
    final double ch = size.height / _rows;
    final Paint on = Paint()..color = color;
    final int half = (_cols + 1) ~/ 2; // 3: cols 0,1 + centre col 2
    int st = seed == 0 ? 0x9e3779b9 : seed;
    int bit() {
      st = (st * 1103515245 + 12345) & 0x7fffffff; // LCG
      return (st >> 16) & 1;
    }

    for (int y = 0; y < _rows; y++) {
      for (int x = 0; x < half; x++) {
        if (bit() == 0) continue;
        canvas.drawRect(
            Rect.fromLTWH(x * cw, y * ch, cw, ch).deflate(0.6), on);
        final int mx = _cols - 1 - x; // mirror
        if (mx != x) {
          canvas.drawRect(
              Rect.fromLTWH(mx * cw, y * ch, cw, ch).deflate(0.6), on);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_InvaderPainter old) =>
      old.seed != seed || old.color != color || old.bg != bg;
}

/// R29 — overlay pill nudging the user back to the newest message.
/// Renders only when the scroll position is away from the bottom
/// AND new messages have arrived since the user scrolled away.
class _JumpToNewestPill extends StatelessWidget {
  const _JumpToNewestPill({
    required this.count,
    required this.label,
    required this.onTap,
  });
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      elevation: 4,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.arrow_downward,
                  size: 16, color: cs.onPrimary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
