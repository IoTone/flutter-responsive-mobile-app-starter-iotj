// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../gen/app_localizations.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import '../meshcore/own_location.dart';
import '../meshcore/region_presets.dart';
import '../perms/location_service.dart';
import '../perms/permissions_service.dart';

/// Device configuration (R7) + LoRa region selection (R15). The
/// **Radio / Region** section is wired to the M4 protocol surface
/// (`setRadioParams` / `setRadioTxPower`). Other sections remain
/// scaffolds (later U-steps).
///
/// "Region" is an app convenience — the companion protocol only
/// carries raw frequency/BW/SF/CR, with no per-region opcode. We
/// ship a small list of community/regulatory presets (US, EU 868,
/// Japan/ARIB STD-T108) and a Custom entry; only cited values are
/// pre-filled. **All nodes must use identical radio params or they
/// can't hear each other**, so match your mesh, and confirm the
/// settings are legal in your jurisdiction (Japan additionally
/// requires firmware-side listen-before-talk).
class DeviceConfigScreen extends StatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  State<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends State<DeviceConfigScreen> {
  final TextEditingController _freq = TextEditingController();
  final TextEditingController _bw = TextEditingController();
  final TextEditingController _sf = TextEditingController();
  final TextEditingController _cr = TextEditingController();
  final TextEditingController _tx = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _lat = TextEditingController();
  final TextEditingController _lon = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _freq, _bw, _sf, _cr, _tx, _name, _lat, _lon
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Snapshot of what `_loadFrom` last wrote. Lets us detect
  // "user hasn't touched these fields" so the auto-reload doesn't
  // clobber in-progress edits.
  String _lastLoadedLat = '';
  String _lastLoadedLon = '';
  String _lastLoadedName = '';

  void _loadFrom(SelfInfo s) {
    _freq.text = s.frequencyMhz.toString();
    _bw.text = s.bandwidthKhz.toString();
    _sf.text = s.spreadingFactor.toString();
    _cr.text = s.codingRate.toString();
    _tx.text = s.txPowerDbm.toString();
    _name.text = s.name;
    _lat.text = s.latitude == 0 ? '' : s.latitude.toString();
    _lon.text = s.longitude == 0 ? '' : s.longitude.toString();
    _lastLoadedLat = _lat.text;
    _lastLoadedLon = _lon.text;
    _lastLoadedName = _name.text;
    setState(() => _loaded = true);
  }

  /// Re-sync text fields when the device's `selfInfo` has changed
  /// AND the user hasn't typed over the previously-loaded values.
  /// This is what makes the periodic location-refresh actually
  /// appear in the lat/lon fields instead of freezing at the
  /// initial-handshake snapshot.
  void _maybeReloadFromSelfInfo(SelfInfo s) {
    final String latNext = s.latitude == 0 ? '' : s.latitude.toString();
    final String lonNext = s.longitude == 0 ? '' : s.longitude.toString();
    final String nameNext = s.name;
    final bool latUntouched = _lat.text == _lastLoadedLat;
    final bool lonUntouched = _lon.text == _lastLoadedLon;
    final bool nameUntouched = _name.text == _lastLoadedName;
    if (latUntouched && _lat.text != latNext) {
      _lat.text = latNext;
      _lastLoadedLat = latNext;
    }
    if (lonUntouched && _lon.text != lonNext) {
      _lon.text = lonNext;
      _lastLoadedLon = lonNext;
    }
    if (nameUntouched && _name.text != nameNext) {
      _name.text = nameNext;
      _lastLoadedName = nameNext;
    }
  }

  Future<void> _applyName(MeshcoreController mc) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final String n = _name.text.trim();
    if (n.isEmpty) {
      _toast(l.deviceToastNameEmpty);
      return;
    }
    try {
      await mc.setAdvertName(n);
      _toast(l.deviceToastNameSet);
    } catch (e) {
      _toast(l.deviceToastSendFailed('$e'));
    }
  }

  /// R22 / U13 — read the device's own SelfInfo lat/lon back into
  /// the form (in case the user typed something and wants to revert
  /// to what the device is currently reporting).
  void _readDeviceLocation(MeshcoreController mc) {
    final AppLocalizations l = AppLocalizations.of(context);
    final SelfInfo? s = mc.selfInfo;
    if (s == null) {
      _toast(l.deviceToastNoDeviceYet);
      return;
    }
    if (s.latitude == 0 && s.longitude == 0) {
      _toast(l.deviceToastNoGpsYet);
      return;
    }
    setState(() {
      _lat.text = s.latitude.toString();
      _lon.text = s.longitude.toString();
    });
    _toast(l.deviceToastLoadedDeviceLoc);
  }

  /// R22 / U13 — request a one-shot phone-GPS fix and populate the
  /// lat/lon fields with it. Permission is requested just-in-time
  /// (we don't ask at first-run; the user only pays the permission
  /// cost if they actually take this action).
  Future<void> _usePhoneLocation(MeshcoreController mc) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final PermissionsService perms = context.read<PermissionsService>();
    final PermissionResult r = await perms.requestLocation();
    if (!mounted) return;
    if (r != PermissionResult.granted &&
        r != PermissionResult.notApplicable) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(r == PermissionResult.permanentlyDenied
              ? l.deviceLocPermDeniedPerm
              : l.deviceLocPermDenied),
          action: SnackBarAction(
            label: l.deviceOpenSettings,
            onPressed: () => perms.openAppSettingsPage(),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    _toast(l.deviceToastGettingPhoneFix);
    final bool ok = await mc.requestPhoneLocationFix();
    if (!mounted) return;
    if (!ok) {
      _toast(l.deviceToastPhoneFixFailed);
      return;
    }
    final OwnLocation? loc = mc.phoneLocationFix;
    if (loc == null) {
      _toast(l.deviceToastNoFixReturned);
      return;
    }
    setState(() {
      _lat.text = loc.latitude.toStringAsFixed(6);
      _lon.text = loc.longitude.toStringAsFixed(6);
    });
    _toast(l.deviceToastGotPhoneLoc);
  }

  Future<void> _applyLocation(MeshcoreController mc) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final double? la = double.tryParse(_lat.text.trim());
    final double? lo = double.tryParse(_lon.text.trim());
    if (la == null || lo == null || la.abs() > 90 || lo.abs() > 180) {
      _toast(l.deviceToastInvalidLatLon);
      return;
    }
    try {
      await mc.setAdvertLatLon(latitude: la, longitude: lo);
      _toast(l.deviceToastAdvertLocSet);
    } catch (e) {
      _toast(l.deviceToastSendFailed('$e'));
    }
  }

  /// Fill the radio fields from a region preset and apply
  /// immediately. The preset's tuple is the canonical operating
  /// point — there's no "frequency only" partial-fill anymore.
  Future<void> _applyPreset(MeshcoreController mc, RegionPreset p) async {
    final AppLocalizations l = AppLocalizations.of(context);
    setState(() {
      _freq.text = p.frequencyMhz.toString();
      _bw.text = p.bandwidthKhz.toString();
      _sf.text = p.spreadingFactor.toString();
      _cr.text = p.codingRate.toString();
      _tx.text = p.txPowerDbm.toString();
    });
    final String localized = localizedPresetLabel(l, p.id);
    if (!mc.isReady) {
      // R25+3 — clearer feedback. The fields are filled and visible;
      // tell the user explicitly that the values won't reach the
      // radio until they connect. Pairs with the "Connect a device
      // first" toast on the bottom Apply button.
      _toast(l.deviceRegionLoadedOffline(localized));
      return;
    }
    try {
      await mc.send(MeshcoreFrameCodec.setRadioParams(RadioParams(
        frequencyMhz: p.frequencyMhz,
        bandwidthKhz: p.bandwidthKhz,
        spreadingFactor: p.spreadingFactor,
        codingRate: p.codingRate,
      )));
      await mc.send(MeshcoreFrameCodec.setRadioTxPower(p.txPowerDbm));
      _toast(l.deviceRegionAppliedToast(localized));
    } catch (e) {
      _toast(l.deviceToastSendFailed('$e'));
    }
  }

  /// Suggest a preset from the phone's GPS fix. No-op if location is
  /// unavailable or the fix falls outside every shipped country box.
  /// Shows a confirmation dialog before applying so a user near a
  /// national border can override.
  Future<void> _suggestFromMyLocation(MeshcoreController mc) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final PhoneFix? fix = await const GeolocatorLocationService()
        .currentFix(timeLimit: const Duration(seconds: 15));
    if (fix == null) {
      _toast(l.deviceRegionSuggestNoFix);
      return;
    }
    final RegionPreset? p =
        suggestPresetForLatLon(fix.latitude, fix.longitude);
    if (p == null) {
      _toast(l.deviceRegionSuggestNoMatch);
      return;
    }
    if (!mounted) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l.deviceRegionSuggestTitle),
        content: Text(l.deviceRegionSuggestBody(
            localizedPresetLabel(l, p.id),
            fix.latitude.toStringAsFixed(3),
            fix.longitude.toStringAsFixed(3))),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.deviceRegionSuggestApply)),
        ],
      ),
    );
    if (ok == true) await _applyPreset(mc, p);
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _applyRadio(MeshcoreController mc) async {
    final AppLocalizations l = AppLocalizations.of(context);
    // R25+3 — the user-reported bug: "Apply radio settings" was
    // greyed out when not connected, with no clue why. Now we keep
    // the button enabled and surface an explicit toast — picking a
    // preset while offline at least leaves a clear trail of what to
    // do next, rather than looking like the app is broken.
    if (!mc.isReady) {
      _toast(l.deviceConnectFirst);
      return;
    }
    final double? f = double.tryParse(_freq.text);
    final double? b = double.tryParse(_bw.text);
    final int? sf = int.tryParse(_sf.text);
    final int? cr = int.tryParse(_cr.text);
    if (f == null || b == null || sf == null || cr == null) {
      _toast(l.deviceToastInvalidRadio);
      return;
    }
    try {
      await mc.send(MeshcoreFrameCodec.setRadioParams(RadioParams(
        frequencyMhz: f,
        bandwidthKhz: b,
        spreadingFactor: sf,
        codingRate: cr,
      )));
      final int? tx = int.tryParse(_tx.text);
      if (tx != null) {
        await mc.send(MeshcoreFrameCodec.setRadioTxPower(tx));
      }
      _toast(l.deviceToastRadioSent);
    } catch (e) {
      _toast(l.deviceToastSendFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool ready = mc.state == MeshcoreConnectionState.ready;
    final SelfInfo? si = mc.selfInfo;
    if (!_loaded && si != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loaded) _loadFrom(si);
      });
    } else if (_loaded && si != null) {
      // Subsequent SelfInfo arrivals (e.g. the dashboard's 60 s
      // refresh trigger) — sync the lat/lon/name fields into the
      // form unless the user has edited them since the last load.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeReloadFromSelfInfo(si);
      });
    }

    Widget num(String label, TextEditingController c, String hint) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
            ],
            decoration: InputDecoration(
                labelText: label, hintText: hint, isDense: true),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.deviceConfigTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(l.deviceRegionBand,
              style: TextStyle(
                  color: cs.primary, fontSize: 12, letterSpacing: 3)),
          const SizedBox(height: 8),
          _CurrentRegionBanner(si: si, cs: cs, l: l),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final RegionPreset p in kRegionPresets)
                _RegionChip(
                  label: localizedPresetLabel(l, p.id),
                  note: p.note,
                  selected: si != null &&
                      matchPresetByRadioParams(
                            frequencyMhz: si.frequencyMhz,
                            bandwidthKhz: si.bandwidthKhz,
                            spreadingFactor: si.spreadingFactor,
                            codingRate: si.codingRate,
                          )?.id ==
                          p.id,
                  onTap: () => _applyPreset(mc, p),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.my_location, size: 16),
              label: Text(l.deviceRegionSuggestFromLocation),
              onPressed: () => _suggestFromMyLocation(mc),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.deviceRegionDisclaimer,
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
          const Divider(height: 28),
          Text(l.deviceRadioParams,
              style: TextStyle(
                  color: cs.primary, fontSize: 12, letterSpacing: 3)),
          if (si != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  'device now: ${si.frequencyMhz}MHz '
                  '${si.bandwidthKhz}kHz SF${si.spreadingFactor} '
                  'CR${si.codingRate} ${si.txPowerDbm}dBm',
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: 12)),
            ),
          num(l.deviceFrequency, _freq, 'e.g. 915.0'),
          num(l.deviceBandwidth, _bw, 'e.g. 250'),
          num(l.deviceSpreadingFactor, _sf, 'e.g. 7'),
          num(l.deviceCodingRate, _cr, 'e.g. 5'),
          num(l.deviceTxPower, _tx, 'within regional limit'),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (si != null)
                TextButton(
                  onPressed: () => _loadFrom(si),
                  child: Text(l.deviceLoadFromDevice),
                ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.send),
                label: Text(l.deviceApplyRadio),
                // R25+3 — always tappable. _applyRadio handles the
                // not-ready case explicitly so a user with the form
                // already populated (e.g. via Suggest-from-location
                // while offline) gets actionable feedback instead
                // of a dead button.
                onPressed: () => _applyRadio(mc),
              ),
            ],
          ),
          if (!ready)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.deviceConnectFirst,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          const Divider(height: 28),

          // IDENTITY / ADVERT (R7)
          Text(l.deviceIdentityAdvert,
              style: TextStyle(
                  color: cs.primary, fontSize: 12, letterSpacing: 3)),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            maxLength: 31,
            decoration: InputDecoration(
                labelText: l.deviceAdvertName, isDense: true),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: Text(l.deviceSetName),
              onPressed: ready ? () => _applyName(mc) : null,
            ),
          ),
          // Advert location SOURCE — None / Pinned / GPS. Drives what
          // the device broadcasts: 0 = nothing, 1 = the pinned lat/lon
          // below, 2 = the on-board GPS reading. Sent via
          // CMD_SET_OTHER_PARAMS (0x26).
          const SizedBox(height: 6),
          Text(l.deviceAdvertSource,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Builder(builder: (BuildContext _) {
            final SelfInfo? si = mc.selfInfo;
            final int current = si?.advertLocPolicy ?? 0;
            return SegmentedButton<int>(
              segments: <ButtonSegment<int>>[
                ButtonSegment<int>(
                    value: 0,
                    label: Text(l.deviceAdvertSourceNone),
                    icon: const Icon(Icons.do_not_disturb, size: 16)),
                ButtonSegment<int>(
                    value: 1,
                    label: Text(l.deviceAdvertSourcePinned),
                    icon: const Icon(Icons.push_pin_outlined, size: 16)),
                ButtonSegment<int>(
                    value: 2,
                    label: Text(l.deviceAdvertSourceGps),
                    icon: const Icon(Icons.satellite_alt, size: 16)),
              ],
              selected: <int>{current},
              showSelectedIcon: false,
              onSelectionChanged: ready && si != null
                  ? (Set<int> next) async {
                      final int v = next.first;
                      if (v == current) return;
                      try {
                        await mc.setAdvertLocPolicy(v);
                        final List<String> labels = <String>[
                          l.deviceAdvertSourceNone,
                          l.deviceAdvertSourcePinned,
                          l.deviceAdvertSourceGps,
                        ];
                        _toast(labels[v]);
                      } catch (e) {
                        _toast(l.deviceToastSendFailed('$e'));
                      }
                    }
                  : null,
            );
          }),
          // R38 — on-board GPS module (separate from advert policy
          // above). Without this, picking "Device GPS" above only
          // controls whether GPS coords get *included in adverts* —
          // the firmware never reads its GPS chip into
          // sensors.node_lat/lon. Defaults gps=0, gps_interval=0;
          // we surface the live values + a switch + interval picker.
          _GpsModuleControls(mc: mc, ready: ready, cs: cs, l: l),
          const SizedBox(height: 8),
          // What the device currently reports — read-only "ground
          // truth" line. The editable text fields below are
          // **staging**; this line is the wire-side value. Always
          // shown so divergence is visible at a glance.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Icon(Icons.developer_board,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    () {
                      if (si == null) return l.deviceLocReportsAwaiting;
                      if (si.latitude.abs() < 1e-9 &&
                          si.longitude.abs() < 1e-9) {
                        return l.deviceLocReportsNone;
                      }
                      return l.deviceLocReportsValue(
                          si.latitude.toStringAsFixed(5),
                          si.longitude.toStringAsFixed(5));
                    }(),
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          _LatLonField(
            label: l.deviceAdvertLatitude,
            hint: 'e.g. 35.681',
            controller: _lat,
            deviceValue: si?.latitude,
            unsavedLabel: l.deviceLocUnsaved,
          ),
          _LatLonField(
            label: l.deviceAdvertLongitude,
            hint: 'e.g. 139.767',
            controller: _lon,
            deviceValue: si?.longitude,
            unsavedLabel: l.deviceLocUnsaved,
          ),
          // R22 / U13 — populate-the-field actions (no broadcast).
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.smartphone, size: 16),
                  label: Text(l.deviceUsePhoneLocation),
                  onPressed: () => _usePhoneLocation(mc),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.developer_board, size: 16),
                  label: Text(l.deviceReadDeviceLocation),
                  onPressed: () => _readDeviceLocation(mc),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(l.deviceSetAdvertLocation),
              onPressed: ready ? () => _applyLocation(mc) : null,
            ),
          ),
          Text(
            'Name/location change propagates on the next advert '
            '(Nodes → Advertise).',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const Divider(height: 28),

          // CHANNELS → dedicated screen
          Text(l.deviceChannelsSection,
              style: TextStyle(
                  color: cs.primary, fontSize: 12, letterSpacing: 3)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tag),
            title: const Text('Manage channels'),
            subtitle: Text('Active: ${mc.activeChannelName} · '
                'slots · name + PSK · #hashtag'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/channels'),
          ),
          const Divider(height: 28),

          // OTHER PARAMS — editable. Each setter wraps
          // CMD_SET_OTHER_PARAMS (0x26) and preserves the other
          // three fields by reading them off SelfInfo.
          Text(l.deviceOtherParamsSection,
              style: TextStyle(
                  color: cs.primary, fontSize: 12, letterSpacing: 3)),
          const SizedBox(height: 4),
          if (si == null)
            Text(l.otherAwaitingDevice,
                style: TextStyle(
                    color: cs.onSurface,
                    fontFamily: 'monospace',
                    height: 1.5))
          else
            _OtherParamsEditor(mc: mc, si: si, enabled: ready),
          const Divider(height: 28),

          // DEVICE (read-only)
          Text(l.deviceDeviceSection,
              style: TextStyle(
                  color: cs.primary, fontSize: 12, letterSpacing: 3)),
          const SizedBox(height: 4),
          Builder(builder: (BuildContext _) {
            final DeviceInfo? d = mc.deviceInfo;
            final String batt = mc.batteryMillivolts == null
                ? '—'
                : '${mc.batteryVolts!.toStringAsFixed(2)}V '
                    '(~${mc.batteryPercent}%)'
                    '${mc.charging == true ? ' ⚡' : ''}';
            return Text(
              d == null
                  ? 'querying device…\nbattery: $batt'
                  : 'firmware: ${d.firmwareVersion}\n'
                      'build: ${d.firmwareBuildDate}\n'
                      'mfr: ${d.manufacturer}\n'
                      'max contacts: ${d.maxContacts} · '
                      'channels: ${d.maxGroupChannels}\n'
                      'BLE pin: ${d.blePin}\n'
                      'battery: $batt',
              style: TextStyle(
                  color: cs.onSurface,
                  fontFamily: 'monospace',
                  height: 1.5),
            );
          }),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.battery_charging_full),
            title: Text(l.batteryTitle),
            subtitle: Text(l.batteryConfigSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/battery'),
          ),
        ],
      ),
    );
  }
}

/// Editable OTHER PARAMS block. The three settings (manual-add,
/// telemetry mode, multi-acks) all share the same `CMD_SET_OTHER_PARAMS`
/// (0x26) wire surface; each setter on `MeshcoreController` preserves
/// the other fields so we don't accidentally clobber them when only
/// one changes.
class _OtherParamsEditor extends StatefulWidget {
  const _OtherParamsEditor({
    required this.mc,
    required this.si,
    required this.enabled,
  });
  final MeshcoreController mc;
  final SelfInfo si;
  final bool enabled;

  @override
  State<_OtherParamsEditor> createState() => _OtherParamsEditorState();
}

class _OtherParamsEditorState extends State<_OtherParamsEditor> {
  // Telemetry mode is a packed byte: bits 0-1 = base, 2-3 = location,
  // 4-5 = environment (each 0–3, meaning firmware-defined). Decompose
  // it into three selectors so the user isn't editing a raw number.
  late int _telBase = widget.si.telemetryModeRaw & 0x03;
  late int _telLoc = (widget.si.telemetryModeRaw >> 2) & 0x03;
  late int _telEnv = (widget.si.telemetryModeRaw >> 4) & 0x03;
  late int _multiAcks = widget.si.multiAcks;

  int get _telPacked => _telBase | (_telLoc << 2) | (_telEnv << 4);

  @override
  void didUpdateWidget(_OtherParamsEditor old) {
    super.didUpdateWidget(old);
    // SelfInfo can change underfoot (the device echoes back the new
    // value after a successful SET) — re-sync the local UI state to
    // match the truth.
    if (old.si.telemetryModeRaw != widget.si.telemetryModeRaw) {
      _telBase = widget.si.telemetryModeRaw & 0x03;
      _telLoc = (widget.si.telemetryModeRaw >> 2) & 0x03;
      _telEnv = (widget.si.telemetryModeRaw >> 4) & 0x03;
    }
    if (old.si.multiAcks != widget.si.multiAcks) {
      _multiAcks = widget.si.multiAcks;
    }
  }

  Future<void> _applyTelemetryMode() async {
    await widget.mc.setTelemetryMode(_telPacked);
    _snack();
  }

  Future<void> _applyMultiAcks(int v) async {
    setState(() => _multiAcks = v);
    await widget.mc.setMultiAcks(v);
    _snack();
  }

  void _snack() {
    if (!mounted) return;
    final AppLocalizations l = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l.otherSentSnack)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // manual-add — boolean.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(l.otherManualAddTitle),
          subtitle: Text(
            widget.si.manualAddContacts
                ? l.otherManualAddSubOn
                : l.otherManualAddSubOff,
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: .6),
                fontSize: 12),
          ),
          value: widget.si.manualAddContacts,
          onChanged: widget.enabled
              ? (bool v) async {
                  await widget.mc.setManualAddContacts(v);
                  _snack();
                }
              : null,
        ),
        const SizedBox(height: 6),
        // multi-acks — 0..3 segmented.
        Text(l.otherMultiAcksLabel,
            style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          segments: const <ButtonSegment<int>>[
            ButtonSegment<int>(value: 0, label: Text('0')),
            ButtonSegment<int>(value: 1, label: Text('1')),
            ButtonSegment<int>(value: 2, label: Text('2')),
            ButtonSegment<int>(value: 3, label: Text('3')),
          ],
          selected: <int>{_multiAcks.clamp(0, 3)},
          showSelectedIcon: false,
          onSelectionChanged: widget.enabled
              ? (Set<int> next) => _applyMultiAcks(next.first)
              : null,
        ),
        const SizedBox(height: 4),
        Text(l.otherMultiAcksHelper,
            style:
                TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
        const SizedBox(height: 10),
        // Telemetry mode — base / location / environment, each 0–3.
        // Packed into one byte (bits 0-1/2-3/4-5). Value meanings are
        // firmware-defined; applied to the device on each change.
        Text(l.otherTelemetryModeTitle,
            style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        for (final (String, int, void Function(int)) row
            in <(String, int, void Function(int))>[
          (l.otherTelemetryBase, _telBase, (int v) {
            setState(() => _telBase = v);
            _applyTelemetryMode();
          }),
          (l.otherTelemetryLoc, _telLoc, (int v) {
            setState(() => _telLoc = v);
            _applyTelemetryMode();
          }),
          (l.otherTelemetryEnv, _telEnv, (int v) {
            setState(() => _telEnv = v);
            _applyTelemetryMode();
          }),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: <Widget>[
                SizedBox(
                    width: 88,
                    child: Text(row.$1,
                        style:
                            TextStyle(color: cs.onSurface, fontSize: 13))),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment<int>(value: 0, label: Text('0')),
                      ButtonSegment<int>(value: 1, label: Text('1')),
                      ButtonSegment<int>(value: 2, label: Text('2')),
                      ButtonSegment<int>(value: 3, label: Text('3')),
                    ],
                    selected: <int>{row.$2},
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact),
                    onSelectionChanged: widget.enabled
                        ? (Set<int> s) => row.$3(s.first)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          l.otherTelemetryModeHelp('$_telPacked'),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
        ),
      ],
    );
  }
}

/// Lat/lon `TextField` that subscribes to its own controller +
/// compares the typed text against the device's current
/// `selfInfo` value. When they diverge, an "✱ unsaved" suffix
/// renders in the input decoration so the user knows the
/// staged value hasn't been pushed to the device yet.
///
/// The comparison tolerates floating-point noise (1e-5 ≈ 1.1 m
/// at the equator) — typing "35.681" should not show "unsaved"
/// against a device value of 35.6810002 from JSON round-tripping.
class _LatLonField extends StatefulWidget {
  const _LatLonField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.deviceValue,
    required this.unsavedLabel,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  /// The device's last-reported value for this field. May be null
  /// (no selfInfo yet) — in that case we never show "unsaved"
  /// since we have no baseline.
  final double? deviceValue;

  final String unsavedLabel;

  @override
  State<_LatLonField> createState() => _LatLonFieldState();
}

class _LatLonFieldState extends State<_LatLonField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _unsaved {
    final double? dev = widget.deviceValue;
    if (dev == null) return false;
    final double? typed =
        double.tryParse(widget.controller.text.trim());
    if (typed == null) {
      // Empty / unparseable text: treat as unsaved iff the device
      // has a non-zero value.
      return dev.abs() >= 1e-9;
    }
    return (typed - dev).abs() > 1e-5;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: widget.controller,
        keyboardType: const TextInputType.numberWithOptions(
            decimal: true, signed: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          isDense: true,
          suffix: _unsaved
              ? Text(
                  widget.unsavedLabel,
                  style: TextStyle(
                      color: cs.tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                )
              : null,
        ),
      ),
    );
  }
}

/// R39 — banner at the top of the region section that names the
/// currently-applied preset (matched against the device's live
/// radio params). Removes the "what am I on?" guesswork.
class _CurrentRegionBanner extends StatelessWidget {
  const _CurrentRegionBanner({
    required this.si,
    required this.cs,
    required this.l,
  });
  final SelfInfo? si;
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final RegionPreset? match = si == null
        ? null
        : matchPresetByRadioParams(
            frequencyMhz: si!.frequencyMhz,
            bandwidthKhz: si!.bandwidthKhz,
            spreadingFactor: si!.spreadingFactor,
            codingRate: si!.codingRate,
          );
    final String label = si == null
        ? l.deviceRegionUnknown
        : match != null
            ? localizedPresetLabel(l, match.id)
            : l.deviceRegionCustom;
    final bool isCustom = si != null && match == null;
    final Color border = isCustom ? cs.tertiary : cs.primary;
    final Color fg = isCustom ? cs.tertiary : cs.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withValues(alpha: .5)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
              isCustom ? Icons.tune : Icons.public,
              size: 18,
              color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.deviceRegionCurrent,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                        letterSpacing: 2)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (si != null)
                  Text(
                    '${si!.frequencyMhz} MHz · ${si!.bandwidthKhz} kHz · '
                    'SF${si!.spreadingFactor} · CR${si!.codingRate} · '
                    '${si!.txPowerDbm} dBm',
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// R39 — selectable region preset chip. Highlights when the
/// preset's tuple matches the device's live radio params.
class _RegionChip extends StatelessWidget {
  const _RegionChip({
    required this.label,
    required this.note,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InputChip(
      selected: selected,
      onPressed: onTap,
      avatar: selected
          ? Icon(Icons.check, size: 16, color: cs.onPrimary)
          : null,
      label: Text(label),
      tooltip: note,
      selectedColor: cs.primary,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimary : cs.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

/// R38 — on-board GPS module controls.
///
/// Two firmware custom-vars: `gps` (0/1, powers the module) and
/// `gps_interval` (seconds, 0-86400, polling cadence into
/// `sensors.node_lat/lon`). Both default to 0 on fresh firmware.
/// Without these, picking "Device GPS" in the advert-source
/// segmented button above is a no-op — that policy only governs
/// whether GPS coords get *into adverts*, not whether the device
/// reads its chip at all.
class _GpsModuleControls extends StatelessWidget {
  const _GpsModuleControls({
    required this.mc,
    required this.ready,
    required this.cs,
    required this.l,
  });

  final MeshcoreController mc;
  final bool ready;
  final ColorScheme cs;
  final AppLocalizations l;

  static const List<int> _intervalOptions = <int>[0, 10, 30, 60, 300];

  static String _intervalLabel(AppLocalizations l, int sec) {
    if (sec <= 0) return l.deviceGpsIntervalOff;
    if (sec < 60) return l.deviceGpsIntervalSec(sec);
    if (sec < 3600) return l.deviceGpsIntervalMin(sec ~/ 60);
    return l.deviceGpsIntervalHour(sec ~/ 3600);
  }

  @override
  Widget build(BuildContext context) {
    final bool? enabled = mc.deviceGpsEnabled;
    final int? interval = mc.deviceGpsIntervalSec;
    final bool unknown = enabled == null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.deviceGpsModule,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          // gps switch
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l.deviceGpsEnable),
            subtitle: Text(
              unknown
                  ? l.deviceGpsUnknown
                  : enabled
                      ? l.deviceGpsEnabledHint
                      : l.deviceGpsDisabledHint,
              style:
                  TextStyle(color: cs.onSurface.withValues(alpha: .6)),
            ),
            value: enabled ?? false,
            onChanged: !ready || unknown
                ? null
                : (bool v) async {
                    try {
                      await mc.setCustomVar(
                          name: 'gps', value: v ? '1' : '0');
                    } catch (_) {/* silent — toast is overkill */}
                  },
          ),
          // gps_interval picker — only when the firmware actually
          // advertises the key. On hardware where it isn't exposed
          // (e.g. T1000-E v1.15.0) writes ERR with ILLEGAL_ARG, so
          // hide the control and show a one-line note instead.
          if (mc.supportsGpsInterval == true)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined),
              title: Text(l.deviceGpsInterval),
              subtitle: Text(
                interval == null
                    ? l.deviceGpsUnknown
                    : _intervalLabel(l, interval),
                style:
                    TextStyle(color: cs.onSurface.withValues(alpha: .6)),
              ),
              enabled: ready && enabled == true,
              trailing: const Icon(Icons.chevron_right),
              onTap: !(ready && enabled == true)
                  ? null
                  : () => _pickInterval(context, interval ?? 0),
            )
          else if (mc.supportsGpsInterval == false && enabled == true)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(l.deviceGpsIntervalFixedByFirmware,
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Future<void> _pickInterval(BuildContext ctx, int current) async {
    final int? picked = await showModalBottomSheet<int>(
      context: ctx,
      builder: (BuildContext _) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final int s in _intervalOptions)
              ListTile(
                dense: true,
                leading: Icon(
                  current == s
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_intervalLabel(l, s)),
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != current) {
      try {
        await mc.setCustomVar(
          name: 'gps_interval',
          value: '$picked',
          // Some firmware builds don't expose gps_interval as a
          // settable sensors key — they reply ILLEGAL_ARG. Don't
          // surface that in the recent-activity feed.
          absorbErrorFromUserFeed: true,
        );
      } catch (_) {/* silent */}
    }
  }
}
