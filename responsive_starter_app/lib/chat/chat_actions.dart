// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gen/app_localizations.dart';
import '../meshcore/chat_message.dart';

/// R20 / U11 — per-message Reply / Copy / Delete actions for chat
/// rows (channel chat **and** DM thread). Long-press a row OR tap
/// the trailing affordance to open this sheet.
enum ChatAction { reply, copy, delete }

/// Modal bottom sheet listing the three actions. Returns the chosen
/// action (or null on dismiss). The caller wires the consequences:
/// quoting into the composer (Reply), `Clipboard.setData` + snack
/// (Copy), and `deleteMessageById` with a "OTA can't be recalled"
/// confirmation (Delete).
Future<ChatAction?> showChatActions(
    BuildContext context, ChatMessage m) async {
  final AppLocalizations l = AppLocalizations.of(context);
  return showModalBottomSheet<ChatAction>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.reply),
            title: Text(l.actionReply),
            subtitle: Text(l.actionReplySub),
            onTap: () => Navigator.pop(ctx, ChatAction.reply),
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: Text(l.actionCopy),
            subtitle: Text(l.actionCopySub),
            onTap: () => Navigator.pop(ctx, ChatAction.copy),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error),
            title: Text(l.actionDeleteLocal),
            subtitle: Text(l.actionDeleteLocalSub),
            onTap: () => Navigator.pop(ctx, ChatAction.delete),
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
}

/// Apply a Copy action: write [m]'s text to the clipboard and show
/// a brief confirmation snack on [scaffoldKey].
Future<void> copyMessageToClipboard(
    BuildContext context, ChatMessage m) async {
  final AppLocalizations l = AppLocalizations.of(context);
  await Clipboard.setData(ClipboardData(text: m.text));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(l.actionCopied),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Build a `> quoted text` prefix for a Reply, trimmed to ~80 chars
/// so the composer doesn't get swamped. The caller prepends this to
/// the existing input.
String buildReplyQuote(ChatMessage m) {
  String t = m.text.replaceAll('\n', ' ').trim();
  if (t.length > 80) t = '${t.substring(0, 80)}…';
  return '> $t\n\n';
}

/// Confirm + delete dialog. Caller passes a deletion closure (so
/// this helper stays platform-agnostic). Returns true if the user
/// confirmed.
Future<bool> confirmDeleteMessage(
    BuildContext context, ChatMessage m) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(l.actionDeleteConfirmTitle),
      content: Text(l.actionDeleteConfirmBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.actionCancel),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
            foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
          ),
          child: Text(l.actionDelete),
        ),
      ],
    ),
  );
  return ok == true;
}
