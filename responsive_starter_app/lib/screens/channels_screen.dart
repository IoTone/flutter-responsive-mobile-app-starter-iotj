// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../cryptokit/dice_roll_entropy.dart';
import '../gen/app_localizations.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import '../theme/theme_controller.dart';

/// Channel management (R6): list the device's channel slots, set the
/// active one, and create/overwrite a slot's name + PSK. A channel is
/// a slot (index) + name + 16-byte pre-shared key; **every node must
/// use the same name & PSK in the same slot** to talk. PSK sources:
/// the well-known Public key, a `#hashtag` (deterministic), or raw
/// hex.
class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key});

  /// Slots to expose (matches the controller's probe range).
  static const int _slots = 4;

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool ready = mc.state == MeshcoreConnectionState.ready;
    final Map<int, String> known = <int, String>{
      for (final MapEntry<int, String> e in mc.channels) e.key: e.value,
    };

    Future<void> edit(int idx) async {
      final _ChannelEdit? r = await showDialog<_ChannelEdit>(
        context: context,
        builder: (BuildContext _) =>
            _EditChannelDialog(
                idx: idx,
                initialName: known[idx] ?? '',
                currentPsk: mc.channelPsk(idx)),
      );
      if (r == null) return;
      if (!context.mounted) return;
      // Clear-slot sentinel — the dialog already showed its own
      // confirm; we just need to call the controller + snack.
      if (r.name == '__clear__') {
        await mc.clearChannel(idx);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
                content: Text(l.channelsClearSnack(idx))));
        }
        return;
      }
      // Slot-0 overwrite warning. Writing a non-Public PSK to slot 0
      // means we lose the shared Public channel — surface that as an
      // explicit confirm rather than letting it happen silently.
      if (idx == 0 && !_pskMatchesPublic(r.psk)) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text(l.channelsSlot0WarnTitle),
            content: Text(l.channelsSlot0WarnBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.channelsSlot0WarnCancel),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.errorContainer,
                  foregroundColor: cs.onErrorContainer,
                ),
                child: Text(l.channelsSlot0WarnContinue),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
      await mc.setChannel(idx: r.idx, name: r.name, psk: r.psk);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
              content: Text(l.channelsSetSnack(idx, r.name))));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.channelsTitle)),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              l.channelsHelp,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: cs.outline.withValues(alpha: .35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.lock_outline,
                      size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.channelsHelpEncryption,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 12,
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!ready)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Text(l.channelsOfflineHint,
                  style: TextStyle(color: cs.error)),
            ),
          const Divider(height: 1),
          for (int idx = 0; idx < _slots; idx++)
            ListTile(
              leading: Icon(
                idx == mc.activeChannel
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: idx == mc.activeChannel
                    ? cs.primary
                    : cs.onSurfaceVariant,
              ),
              title: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(known[idx] ?? l.channelsEmpty,
                        style: TextStyle(
                            color: known.containsKey(idx)
                                ? cs.onSurface
                                : cs.onSurfaceVariant)),
                  ),
                  if (mc.isDefaultChannel(idx))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: cs.tertiary.withValues(alpha: .55)),
                      ),
                      child: Text(l.channelsDefaultBadge,
                          style: TextStyle(
                              color: cs.tertiary,
                              fontSize: 10,
                              letterSpacing: 1.5)),
                    ),
                ],
              ),
              subtitle: Text(idx == mc.activeChannel
                  ? l.channelsSlotActive(idx)
                  : l.channelsSlotLabel(idx)),
              onTap: known.containsKey(idx)
                  ? () => mc.setActiveChannel(idx)
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (known.containsKey(idx))
                    IconButton(
                      tooltip: mc.isDefaultChannel(idx)
                          ? l.channelsClearDefaultTooltip
                          : l.channelsSetDefaultTooltip,
                      icon: Icon(
                          mc.isDefaultChannel(idx)
                              ? Icons.star
                              : Icons.star_border,
                          size: 20,
                          color: mc.isDefaultChannel(idx)
                              ? cs.tertiary
                              : cs.onSurfaceVariant),
                      onPressed: () async {
                        if (mc.isDefaultChannel(idx)) {
                          await mc.setDefaultChannelIdx(null);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                                content: Text(
                                    l.channelsClearedDefaultSnack)));
                        } else {
                          await mc.setDefaultChannelIdx(idx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                                content: Text(
                                    l.channelsSetDefaultSnack(idx))));
                        }
                      },
                    ),
                  TextButton(
                    onPressed: ready ? () => edit(idx) : null,
                    child: Text(known.containsKey(idx)
                        ? l.channelsEdit
                        : l.channelsSet),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Byte-equality check vs the well-known Public PSK. We use the
/// `kPublicChannelPsk` constant exported by the meshcore codec —
/// matching it means "this slot is still effectively Public."
bool _pskMatchesPublic(List<int> psk) {
  if (psk.length != kPublicChannelPsk.length) return false;
  for (int i = 0; i < psk.length; i++) {
    if (psk[i] != kPublicChannelPsk[i]) return false;
  }
  return true;
}

/// Result of the edit dialog.
class _ChannelEdit {
  const _ChannelEdit(this.idx, this.name, this.psk);
  final int idx;
  final String name;
  final List<int> psk;
}

enum _PskSource { public, hashtag, hex, shake }

class _EditChannelDialog extends StatefulWidget {
  const _EditChannelDialog({
    required this.idx,
    required this.initialName,
    this.currentPsk,
  });
  final int idx;
  final String initialName;

  /// The 16-byte PSK the controller has cached for this slot, if
  /// any. Null when we've never observed a `ChannelInfoFrame` for
  /// this slot (e.g. the user is creating it fresh) — in that case
  /// the reveal section is suppressed.
  final List<int>? currentPsk;

  @override
  State<_EditChannelDialog> createState() => _EditChannelDialogState();
}

class _EditChannelDialogState extends State<_EditChannelDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  final TextEditingController _tag = TextEditingController();
  late final TextEditingController _hex = TextEditingController(
    // Pre-fill Hex mode with the existing key (if the slot is
    // already set and the key isn't the well-known Public PSK).
    // Lets the user see what's there and tweak it instead of
    // re-typing 32 hex chars from scratch.
    text: widget.currentPsk != null &&
            !_pskMatchesPublic(widget.currentPsk!)
        ? widget.currentPsk!
            .map((int b) => b.toRadixString(16).padLeft(2, '0'))
            .join()
        : '',
  );
  // Default the key-source segmented button by inspecting the
  // current PSK: Public if it matches the well-known key (or no
  // slot data), Hex otherwise. We can't distinguish hashtag-derived
  // from random-hex keys after the fact (both are opaque bytes), so
  // any non-Public slot reads as Hex on re-open. The user can
  // switch modes manually if they prefer to re-derive from a tag.
  late _PskSource _src = widget.currentPsk == null ||
          _pskMatchesPublic(widget.currentPsk!)
      ? _PskSource.public
      : _PskSource.hex;
  String? _error;

  /// "Show current key" reveal state. Latched per-dialog session;
  /// dismissing & reopening the dialog requires another tap.
  bool _revealCurrent = false;

  /// R32 — dice-roll entropy collector. Lazily constructed when
  /// the user picks the Shake mode so we don't subscribe to the
  /// accelerometer in the common cases. Disposed on dialog close.
  DiceRollEntropy? _dice;

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    _hex.dispose();
    _dice?.dispose();
    super.dispose();
  }

  /// Common-word denylist for the #tag strength hint. Tags in this
  /// list (or their `#`-prefixed forms) are easy to grind from the
  /// surface attacker's side; we warn but don't block. The list is
  /// English / katakana-pop on purpose since #tag derivation is
  /// SHA-256 of the literal string — a tag that looks weak in EN
  /// is just as weak in JA.
  static const Set<String> _weakTagDeny = <String>{
    'public', 'private', 'group', 'channel', 'mesh', 'meshcore',
    'meshmore', 'chat', 'test', 'hello', 'home', 'work', 'family',
    'friends', 'main', 'general', 'team', 'crew', 'fleet',
    'パブリック', 'プライベート', 'グループ', 'チャンネル', 'メッシュ',
    'チャット', 'テスト', '家', '家族', '仲間', 'チーム',
  };

  String? _tagWeakHint(AppLocalizations l) {
    final String raw =
        _tag.text.trim().toLowerCase().replaceAll(RegExp(r'^#'), '');
    if (raw.isEmpty) return null;
    if (raw.length < 8) return l.channelsTagWeakShort;
    if (_weakTagDeny.contains(raw)) return l.channelsTagWeakCommon;
    return null;
  }

  /// Cryptographically-random 16-byte PSK, rendered as 32 hex chars
  /// into the field. Uses `Random.secure()` (platform OS-RNG).
  void _generateRandomPsk() {
    final math.Random r = math.Random.secure();
    final List<int> bytes = <int>[
      for (int i = 0; i < 16; i++) r.nextInt(256),
    ];
    setState(() {
      _hex.text = bytes
          .map((int b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    });
  }

  List<int>? _resolvePsk(AppLocalizations l) {
    switch (_src) {
      case _PskSource.public:
        return kPublicChannelPsk;
      case _PskSource.hashtag:
        final String t = _tag.text.trim();
        if (t.isEmpty) {
          _error = l.channelsErrorTag;
          return null;
        }
        return MeshcoreChannelCrypto.channelPskFromHashtag(t);
      case _PskSource.hex:
        final String h =
            _hex.text.trim().replaceAll(RegExp(r'\s'), '');
        if (h.length != 32 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(h)) {
          _error = l.channelsErrorHex;
          return null;
        }
        return <int>[
          for (int i = 0; i < 32; i += 2)
            int.parse(h.substring(i, i + 2), radix: 16),
        ];
      case _PskSource.shake:
        // The dice-roll widget hands the user a derived key once
        // entropy reaches `complete`. The Save button is disabled
        // while incomplete (see build), so this branch only ever
        // sees a finished digest.
        final DiceRollEntropy? d = _dice;
        if (d == null || !d.complete) {
          _error = l.channelsErrorHex; // generic — UI gates this
          return null;
        }
        return d.psk;
    }
  }

  void _save(AppLocalizations l) {
    setState(() => _error = null);
    final List<int>? psk = _resolvePsk(l);
    if (psk == null) {
      setState(() {});
      return;
    }
    String name = _name.text.trim();
    if (name.isEmpty && _src == _PskSource.public) name = 'Public';
    if (name.isEmpty && _src == _PskSource.hashtag) {
      name = _tag.text.trim();
    }
    if (name.isEmpty) {
      setState(() => _error = l.channelsErrorName);
      return;
    }
    Navigator.pop(context, _ChannelEdit(widget.idx, name, psk));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.channelsDialogTitle(widget.idx)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: l.channelsName, isDense: true),
            ),
            const SizedBox(height: 14),
            Text(l.channelsKeySource),
            SegmentedButton<_PskSource>(
              segments: <ButtonSegment<_PskSource>>[
                ButtonSegment<_PskSource>(
                    value: _PskSource.public,
                    label: Text(l.channelsKeyPublic)),
                ButtonSegment<_PskSource>(
                    value: _PskSource.hashtag,
                    label: Text(l.channelsKeyHashtag)),
                ButtonSegment<_PskSource>(
                    value: _PskSource.hex,
                    label: Text(l.channelsKeyHex)),
                ButtonSegment<_PskSource>(
                    value: _PskSource.shake,
                    label: Text(l.channelsKeyShake)),
              ],
              selected: <_PskSource>{_src},
              onSelectionChanged: (Set<_PskSource> s) {
                final _PskSource next = s.first;
                setState(() {
                  // Tearing down the entropy collector when the user
                  // leaves Shake mode avoids surprise background
                  // accelerometer sampling.
                  if (_src == _PskSource.shake &&
                      next != _PskSource.shake) {
                    _dice?.freeze();
                  }
                  _src = next;
                });
              },
            ),
            const SizedBox(height: 10),
            if (_src == _PskSource.public)
              Text(l.channelsKeyPublicBody,
                  style: const TextStyle(fontSize: 12))
            else if (_src == _PskSource.hashtag) ...<Widget>[
              TextField(
                controller: _tag,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: l.channelsKeyHashtagHint,
                    helperText: l.channelsKeyHashtagHelper,
                    isDense: true),
              ),
              if (_tagWeakHint(l) != null) ...<Widget>[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.warning_amber_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_tagWeakHint(l)!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiary,
                              fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ] else if (_src == _PskSource.hex) ...<Widget>[
              TextField(
                controller: _hex,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9a-fA-F]')),
                ],
                decoration: InputDecoration(
                    labelText: l.channelsKeyHexHint, isDense: true),
              ),
              const SizedBox(height: 6),
              // Buttons in a Wrap so they break to a second line on
              // narrow dialogs / dense locales. The JA labels
              // ("PSK をランダム生成" + "コピー") overflow the 283-wide
              // dialog content area as a single Row.
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.casino, size: 16),
                    label: Text(l.channelsHexGenerate),
                    onPressed: _generateRandomPsk,
                  ),
                  if (_hex.text.trim().length == 32)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(l.channelsHexCopy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(
                            text: _hex.text.trim().toLowerCase()));
                        if (!context.mounted) return;
                        ScaffoldMessenger.maybeOf(context)
                          ?.showSnackBar(SnackBar(
                              content: Text(l.channelsHexCopied),
                              duration:
                                  const Duration(seconds: 2)));
                      },
                    ),
                ],
              ),
            ] else if (_src == _PskSource.shake)
              _DiceRollPanel(
                getOrInit: () {
                  // Lazy-init the entropy collector + start
                  // sampling. Latched: subsequent rebuilds reuse
                  // the same instance.
                  if (_dice == null) {
                    _dice = DiceRollEntropy();
                    // If the user has reduceMotion on, prime the
                    // digest from Random.secure once instead of
                    // listening to the accelerometer. We still
                    // present a Reroll button, which re-seeds.
                    final ThemeController tc =
                        context.read<ThemeController>();
                    if (tc.reduceMotion) {
                      _dice!.seedFromSecureRandom();
                    } else {
                      _dice!.start();
                    }
                  }
                  return _dice!;
                },
                reroll: () {
                  _dice?.reset();
                  final ThemeController tc =
                      context.read<ThemeController>();
                  if (tc.reduceMotion) {
                    _dice!.seedFromSecureRandom();
                  } else {
                    _dice!.start();
                  }
                },
              ),
            // Reveal-current-key block (R6 follow-on). Only shown
            // when the controller has actually cached a PSK for
            // this slot. Latched behind a Reveal tap so the key
            // doesn't appear on every dialog-open. Slot 0's
            // "current key" is the well-known kPublicChannelPsk —
            // we still surface it for symmetry.
            if (widget.currentPsk != null) ...<Widget>[
              const Divider(height: 24),
              Row(
                children: <Widget>[
                  Icon(Icons.vpn_key,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(l.channelsCurrentKey,
                      style: const TextStyle(
                          fontSize: 12, letterSpacing: 1)),
                  const Spacer(),
                  TextButton.icon(
                    icon: Icon(
                        _revealCurrent
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 16),
                    label: Text(_revealCurrent
                        ? l.channelsHideKey
                        : l.channelsRevealKey),
                    onPressed: () => setState(
                        () => _revealCurrent = !_revealCurrent),
                  ),
                ],
              ),
              if (_revealCurrent)
                SelectableText(
                  widget.currentPsk!
                      .map((int b) =>
                          b.toRadixString(16).padLeft(2, '0'))
                      .join(),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11),
                ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        // Clear slot: only offered when the slot has actually been
        // configured (currentPsk known). Slot 0 is also clearable —
        // clearChannel(0) is a no-op (already Public).
        if (widget.currentPsk != null)
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(l.channelsClear),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final bool? ok = await showDialog<bool>(
                context: context,
                builder: (BuildContext ctx) => AlertDialog(
                  title: Text(
                      l.channelsClearConfirmTitle(widget.idx)),
                  content: Text(l.channelsClearConfirmBody),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.channelsCancel),
                    ),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx)
                            .colorScheme
                            .errorContainer,
                        foregroundColor: Theme.of(ctx)
                            .colorScheme
                            .onErrorContainer,
                      ),
                      child: Text(l.channelsClearConfirmAction),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              if (!context.mounted) return;
              // Pop with a special marker the outer screen reads
              // as "the user wants to clear this slot." We could
              // call mc.clearChannel here directly, but the outer
              // screen owns the snack + provider lookup, so it's
              // cleaner to delegate.
              Navigator.pop(
                  context, _ChannelEdit(widget.idx, '__clear__', const <int>[]));
            },
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.channelsCancel)),
        FilledButton(
            onPressed: () => _save(l),
            child: Text(l.channelsSave)),
      ],
    );
  }
}

/// R32 — UI surface for the dice-roll PSK derivation.
///
/// Hands the parent dialog a [DiceRollEntropy] via `getOrInit`
/// and re-renders as that collector accumulates motion samples.
/// Shows a circular progress ring + a 32-char hex preview that
/// fills in as the underlying SHA-256 digest stabilises + a
/// "Reroll" affordance that wipes the buffer and re-starts.
class _DiceRollPanel extends StatelessWidget {
  const _DiceRollPanel({
    required this.getOrInit,
    required this.reroll,
  });

  final DiceRollEntropy Function() getOrInit;
  final VoidCallback reroll;

  @override
  Widget build(BuildContext context) {
    final DiceRollEntropy d = getOrInit();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ThemeController tc = context.watch<ThemeController>();
    return AnimatedBuilder(
      animation: d,
      builder: (BuildContext _, Widget? __) {
        final String hex = d.psk
            .map((int b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.channelsShakeTitle,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              tc.reduceMotion
                  ? l.channelsShakeTapFallback
                  : l.channelsShakeBody,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: d.progress,
                    strokeWidth: 4,
                    color: d.complete ? cs.tertiary : cs.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SelectableText(
                    hex,
                    style: TextStyle(
                        color: d.complete ? cs.onSurface : cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l.channelsShakeProgress(
                d.acceptedSamples,
                (d.targetBits / d.bitsPerSample).round(),
                (d.progress * 100).round(),
              ),
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 11),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l.channelsShakeReroll),
              onPressed: reroll,
            ),
          ],
        );
      },
    );
  }
}
