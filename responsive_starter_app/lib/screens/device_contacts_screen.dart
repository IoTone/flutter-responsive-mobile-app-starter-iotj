// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/meshcore_controller.dart';

/// Diagnostic: the RAW contact list stored on the radio (not the app's
/// favourites, and not filtered by superseded keys). Answers "what does my
/// device actually have?" — and lets the user free a full table by
/// removing entries (a full table is `ERR_CODE_TABLE_FULL`, which blocks
/// adding a re-homed key and silently breaks DMs).
class DeviceContactsScreen extends StatefulWidget {
  const DeviceContactsScreen({super.key});

  @override
  State<DeviceContactsScreen> createState() => _DeviceContactsScreenState();
}

class _DeviceContactsScreenState extends State<DeviceContactsScreen> {
  final Set<String> _removed = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MeshcoreController>().refreshDeviceContacts();
    });
  }

  String _hex(List<int> b) =>
      b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();

  String _path(Contact c, AppLocalizations l) {
    if (c.outPathLen == 0xFF) return l.deviceContactsFlood;
    if (c.outPathLen == 0) return l.deviceContactsDirect;
    return l.deviceContactsHops(c.outPathLen);
  }

  Future<void> _removeOutOfRange(
      MeshcoreController mc, AppLocalizations l) async {
    final double? picked = await showDialog<double>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l.deviceContactsRemoveOutOfRange),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.deviceContactsOutOfRangeIntro,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              if (mc.ownLocation == null) ...<Widget>[
                const SizedBox(height: 6),
                Text(l.deviceContactsNeedLocation,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 8),
              for (final double km in <double>[25, 50, 100])
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.deviceContactsBeyondKm(km.round())),
                  trailing: Text('${mc.outOfRangeContactCount(km)}',
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w600)),
                  enabled: mc.outOfRangeContactCount(km) > 0,
                  onTap: mc.outOfRangeContactCount(km) > 0
                      ? () => Navigator.pop(ctx, km)
                      : null,
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.actionCancel)),
          ],
        );
      },
    );
    if (picked == null || !mounted) return;
    final int n = await mc.removeOutOfRangeContacts(picked);
    if (!mounted) return;
    setState(_removed.clear);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
          content: Text(l.deviceContactsRemoveOutOfRangeDone(n < 0 ? 0 : n)),
          duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _removeStale(
      MeshcoreController mc, AppLocalizations l) async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l.deviceContactsRemoveStale),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.deviceContactsStaleIntro,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 8),
              for (final int days in <int>[30, 90, 180])
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.deviceContactsNotHeardDays(days)),
                  trailing: Text('${mc.staleContactCount(days)}',
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w600)),
                  enabled: mc.staleContactCount(days) > 0,
                  onTap: mc.staleContactCount(days) > 0
                      ? () => Navigator.pop(ctx, days)
                      : null,
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.actionCancel)),
          ],
        );
      },
    );
    if (picked == null || !mounted) return;
    final int n = await mc.removeStaleContacts(picked);
    if (!mounted) return;
    setState(_removed.clear);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
          content: Text(l.deviceContactsRemoveStaleDone(n)),
          duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _removeAll(
      MeshcoreController mc, int count, AppLocalizations l) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text(l.deviceContactsRemoveAll),
            content: Text(l.deviceContactsRemoveAllConfirm(count)),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.actionCancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.deviceContactsRemoveAll)),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    final int n = await mc.removeAllDeviceContacts();
    if (!mounted) return;
    setState(_removed.clear);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
          content: Text(l.deviceContactsRemoveAllDone(n)),
          duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _remove(MeshcoreController mc, Contact c, String key,
      AppLocalizations l) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text(l.nodeDetailRemoveDeviceContact),
            content: Text(l.nodeDetailRemoveDeviceContactConfirm(
                c.name.isEmpty ? _hex(c.publicKey).substring(0, 8) : c.name)),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.actionCancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.nodeDetailRemoveDeviceContact)),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await mc.removeDeviceContact(key);
    if (mounted) setState(() => _removed.add(key));
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<Contact> contacts = <Contact>[
      for (final Contact c in mc.probedContacts)
        if (!_removed.contains(_hex(c.publicKey))) c
    ];
    final int? max = mc.maxContacts;
    final int? count = mc.deviceContactCount;
    final bool full = (count != null && max != null && count >= max);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.deviceContactsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l.deviceContactsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: mc.isReady
                ? () {
                    setState(_removed.clear);
                    mc.refreshDeviceContacts();
                  }
                : null,
          ),
          PopupMenuButton<String>(
            enabled: mc.isReady && contacts.isNotEmpty,
            tooltip: l.deviceContactsScrub,
            icon: const Icon(Icons.cleaning_services_outlined),
            onSelected: (String v) {
              switch (v) {
                case 'range':
                  _removeOutOfRange(mc, l);
                case 'stale':
                  _removeStale(mc, l);
                case 'all':
                  _removeAll(mc, contacts.length, l);
              }
            },
            itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                  value: 'range',
                  child: ListTile(
                      leading: const Icon(Icons.wrong_location_outlined),
                      title: Text(l.deviceContactsRemoveOutOfRange))),
              PopupMenuItem<String>(
                  value: 'stale',
                  child: ListTile(
                      leading: const Icon(Icons.history_toggle_off),
                      title: Text(l.deviceContactsRemoveStale))),
              PopupMenuItem<String>(
                  value: 'all',
                  child: ListTile(
                      leading: const Icon(Icons.delete_sweep_outlined),
                      title: Text(l.deviceContactsRemoveAll))),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            color: full ? cs.errorContainer : cs.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(full ? Icons.warning_amber : Icons.contacts,
                    size: 18,
                    color: full ? cs.onErrorContainer : cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    count == null
                        ? l.deviceContactsSyncing
                        : (max == null
                            ? l.deviceContactsCountOnly(count)
                            : l.deviceContactsCount(count, max)),
                    style: TextStyle(
                        color: full ? cs.onErrorContainer : cs.onSurface,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l.deviceContactsChannelsNote,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 12, height: 1.35)),
          ),
          if (full)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(l.deviceContactsFullHelp,
                  style: TextStyle(color: cs.error, fontSize: 13, height: 1.4)),
            ),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text(
                        count == 0 ? l.deviceContactsEmpty : l.deviceContactsSyncing,
                        style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext _, int i) {
                      final Contact c = contacts[i];
                      final String key = _hex(c.publicKey);
                      return ListTile(
                        title: Text(
                            c.name.isEmpty ? key.substring(0, 12) : c.name,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '…${key.substring(0, 12)} · ${_path(c, l)}',
                            style: const TextStyle(
                                fontFamily: 'JetBrains Mono', fontSize: 11)),
                        trailing: IconButton(
                          tooltip: l.nodeDetailRemoveDeviceContact,
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          onPressed: () => _remove(mc, c, key, l),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
