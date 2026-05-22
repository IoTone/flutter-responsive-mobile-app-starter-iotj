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

/// A LoRa **region** preset (R15). Band edges / duty / power are
/// regulatory (not MeshCore-proprietary); we only ship values we can
/// cite. `bwKhz`/`sf`/`cr` are filled when a region has a known
/// community/regulatory setting (e.g. Japan); when null only the
/// frequency is pre-filled and SF/BW/CR are left to match your mesh.
/// `freqMhz == 0` marks the manual "Custom" entry (no-op).
class _Band {
  const _Band(
    this.label,
    this.freqMhz,
    this.note, {
    this.bwKhz,
    this.sf,
    this.cr,
    this.txDbm,
    this.cite,
  });
  final String label;
  final double freqMhz;
  final String note;
  final double? bwKhz;
  final int? sf;
  final int? cr;
  final int? txDbm;
  final String? cite;
}

const List<_Band> _bands = <_Band>[
  _Band('US (902–928 MHz)', 915.0, '100% duty · ≤30 dBm'),
  _Band('EU 868 (869.4–869.65)', 869.525, '10% duty · ≤27 dBm'),
  // Japan, ARIB STD-T108. Full preset (freq+BW+SF+CR) is field-
  // validated for urban JP RF noise — see MeshCore issue #460
  // (@jirogit, 2026-03-18). 920.8 MHz is in the 920.6–922.2 zone:
  // LBT ≥5 ms, 4 s max TX, no hourly duty cap. CR 4/8 → codingRate 8.
  _Band(
    'JP (920.5–923.5 · ARIB T108)',
    920.8,
    'LBT ≥5 ms · 4 s max TX · ≤13 dBm',
    bwKhz: 125,
    sf: 12,
    cr: 8,
    txDbm: 13,
    cite: 'MeshCore #460',
  ),
  _Band('Custom', 0, 'enter exact values below'),
];

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

  void _loadFrom(SelfInfo s) {
    _freq.text = s.frequencyMhz.toString();
    _bw.text = s.bandwidthKhz.toString();
    _sf.text = s.spreadingFactor.toString();
    _cr.text = s.codingRate.toString();
    _tx.text = s.txPowerDbm.toString();
    _name.text = s.name;
    _lat.text = s.latitude == 0 ? '' : s.latitude.toString();
    _lon.text = s.longitude == 0 ? '' : s.longitude.toString();
    setState(() => _loaded = true);
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

  /// Fill the radio fields from a region preset. Frequency is always
  /// set; BW/SF/CR/TX are set only when the region ships a cited
  /// setting (e.g. Japan), otherwise left for you to match your mesh.
  void _applyBand(_Band band) {
    _freq.text = band.freqMhz.toString();
    if (band.bwKhz != null) _bw.text = band.bwKhz.toString();
    if (band.sf != null) _sf.text = band.sf.toString();
    if (band.cr != null) _cr.text = band.cr.toString();
    if (band.txDbm != null) _tx.text = band.txDbm.toString();
    final bool full = band.sf != null;
    _toast(
      full
          ? '${band.label}: preset loaded${band.cite == null ? '' : ' '
              '(${band.cite})'} — verify it is legal where you are & '
              'matches every node, then Apply'
          : '${band.label}: frequency set — confirm it is legal in your '
              'country & set SF/BW/CR to match your other nodes',
    );
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _applyRadio(MeshcoreController mc) async {
    final AppLocalizations l = AppLocalizations.of(context);
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
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final _Band band in _bands)
                OutlinedButton(
                  onPressed: band.freqMhz == 0 ? null : () => _applyBand(band),
                  child: Text(band.label),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Band edges/duty/power are regulatory. MeshCore sends '
              'raw frequency — pick the region legal where you are and '
              'use the SAME values on every node. JP (ARIB STD-T108) '
              'also mandates listen-before-talk (carrier sense); the '
              'app preset alone is not full regulatory compliance — '
              'JP needs a non-zero carrier-sense threshold in firmware.',
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
                onPressed: ready ? () => _applyRadio(mc) : null,
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
          const SizedBox(height: 8),
          num(l.deviceAdvertLatitude, _lat, 'e.g. 35.681'),
          num(l.deviceAdvertLongitude, _lon, 'e.g. 139.767'),
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

          // OTHER PARAMS (read-only for now)
          Text(l.deviceOtherParamsSection,
              style: TextStyle(
                  color: cs.primary, fontSize: 12, letterSpacing: 3)),
          const SizedBox(height: 4),
          Text(
            si == null
                ? '— awaiting device —'
                : 'manual-add contacts: ${si.manualAddContacts}\n'
                    'telemetry mode: ${si.telemetryModeRaw}\n'
                    'advert loc policy: ${si.advertLocPolicy}\n'
                    'multi-acks: ${si.multiAcks}',
            style: TextStyle(
                color: cs.onSurface,
                fontFamily: 'monospace',
                height: 1.5),
          ),
          Text('Editing these (telemetry / manual-add / acks) is a '
              'later step.',
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
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
        ],
      ),
    );
  }
}
