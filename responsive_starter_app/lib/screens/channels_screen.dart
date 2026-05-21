// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';

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
    final bool ready = mc.state == MeshcoreConnectionState.ready;
    final Map<int, String> known = <int, String>{
      for (final MapEntry<int, String> e in mc.channels) e.key: e.value,
    };

    Future<void> edit(int idx) async {
      final _ChannelEdit? r = await showDialog<_ChannelEdit>(
        context: context,
        builder: (BuildContext _) =>
            _EditChannelDialog(idx: idx, initialName: known[idx] ?? ''),
      );
      if (r == null) return;
      await mc.setChannel(idx: r.idx, name: r.name, psk: r.psk);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
              content: Text('Channel $idx set to "${r.name}" — every '
                  'node needs the same name & PSK here')));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Channels')),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'A channel = slot + name + 16-byte key. Public (slot 0) '
              'is the shared default. For a private group, set the '
              'SAME name & PSK in the same slot on every node.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
          if (!ready)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Text(
                  'Connect a radio (Diagnostics) to edit channels.',
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
              title: Text(known[idx] ?? '— empty —',
                  style: TextStyle(
                      color: known.containsKey(idx)
                          ? cs.onSurface
                          : cs.onSurfaceVariant)),
              subtitle: Text('slot $idx'
                  '${idx == mc.activeChannel ? ' · ACTIVE' : ''}'),
              onTap: known.containsKey(idx)
                  ? () => mc.setActiveChannel(idx)
                  : null,
              trailing: TextButton(
                onPressed: ready ? () => edit(idx) : null,
                child: Text(known.containsKey(idx) ? 'Edit' : 'Set'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Result of the edit dialog.
class _ChannelEdit {
  const _ChannelEdit(this.idx, this.name, this.psk);
  final int idx;
  final String name;
  final List<int> psk;
}

enum _PskSource { public, hashtag, hex }

class _EditChannelDialog extends StatefulWidget {
  const _EditChannelDialog({required this.idx, required this.initialName});
  final int idx;
  final String initialName;

  @override
  State<_EditChannelDialog> createState() => _EditChannelDialogState();
}

class _EditChannelDialogState extends State<_EditChannelDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  final TextEditingController _tag = TextEditingController();
  final TextEditingController _hex = TextEditingController();
  _PskSource _src = _PskSource.public;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    _hex.dispose();
    super.dispose();
  }

  List<int>? _resolvePsk() {
    switch (_src) {
      case _PskSource.public:
        return kPublicChannelPsk;
      case _PskSource.hashtag:
        final String t = _tag.text.trim();
        if (t.isEmpty) {
          _error = 'Enter a #hashtag';
          return null;
        }
        return MeshcoreChannelCrypto.channelPskFromHashtag(t);
      case _PskSource.hex:
        final String h =
            _hex.text.trim().replaceAll(RegExp(r'\s'), '');
        if (h.length != 32 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(h)) {
          _error = 'PSK must be 32 hex chars (16 bytes)';
          return null;
        }
        return <int>[
          for (int i = 0; i < 32; i += 2)
            int.parse(h.substring(i, i + 2), radix: 16),
        ];
    }
  }

  void _save() {
    setState(() => _error = null);
    final List<int>? psk = _resolvePsk();
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
      setState(() => _error = 'Enter a channel name');
      return;
    }
    Navigator.pop(context, _ChannelEdit(widget.idx, name, psk));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Channel slot ${widget.idx}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Channel name', isDense: true),
            ),
            const SizedBox(height: 14),
            const Text('Key source'),
            SegmentedButton<_PskSource>(
              segments: const <ButtonSegment<_PskSource>>[
                ButtonSegment<_PskSource>(
                    value: _PskSource.public, label: Text('Public')),
                ButtonSegment<_PskSource>(
                    value: _PskSource.hashtag, label: Text('#tag')),
                ButtonSegment<_PskSource>(
                    value: _PskSource.hex, label: Text('Hex')),
              ],
              selected: <_PskSource>{_src},
              onSelectionChanged: (Set<_PskSource> s) =>
                  setState(() => _src = s.first),
            ),
            const SizedBox(height: 10),
            if (_src == _PskSource.public)
              const Text('Uses the well-known Public channel key.',
                  style: TextStyle(fontSize: 12))
            else if (_src == _PskSource.hashtag)
              TextField(
                controller: _tag,
                decoration: const InputDecoration(
                    labelText: 'e.g. #mygroup',
                    helperText: 'Key derived from the tag (sha256)',
                    isDense: true),
              )
            else
              TextField(
                controller: _hex,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9a-fA-F]')),
                ],
                decoration: const InputDecoration(
                    labelText: '32 hex chars (16 bytes)',
                    isDense: true),
              ),
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
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
