import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
            title: const Text('Reply'),
            subtitle: const Text('Quote this message in your reply'),
            onTap: () => Navigator.pop(ctx, ChatAction.reply),
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Copy'),
            subtitle: const Text('Copy the message text to the clipboard'),
            onTap: () => Navigator.pop(ctx, ChatAction.copy),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error),
            title: const Text('Delete locally'),
            subtitle: const Text(
                'Removes this row from your history only — '
                'over-the-air messages cannot be recalled.'),
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
  await Clipboard.setData(ClipboardData(text: m.text));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(
      content: Text('Copied to clipboard'),
      duration: Duration(seconds: 2),
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
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Delete this message locally?'),
      content: const Text(
          'This removes the row from your local history. '
          'MeshCore has no recall — the recipient still has it.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
            foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}
