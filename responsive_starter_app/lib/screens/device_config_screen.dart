import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';

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
  bool _loaded = false;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _freq, _bw, _sf, _cr, _tx
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
    setState(() => _loaded = true);
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
    final double? f = double.tryParse(_freq.text);
    final double? b = double.tryParse(_bw.text);
    final int? sf = int.tryParse(_sf.text);
    final int? cr = int.tryParse(_cr.text);
    if (f == null || b == null || sf == null || cr == null) {
      _toast('Enter valid numbers for freq/BW/SF/CR');
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
      _toast('Radio params sent — restart/observe the device to confirm');
    } catch (e) {
      _toast('Send failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
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
      appBar: AppBar(title: const Text('Device configuration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('REGION / BAND',
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
          Text('RADIO PARAMS',
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
          num('Frequency (MHz)', _freq, 'e.g. 915.0'),
          num('Bandwidth (kHz)', _bw, 'e.g. 250'),
          num('Spreading factor (5–12)', _sf, 'e.g. 7'),
          num('Coding rate (5–8)', _cr, 'e.g. 5'),
          num('TX power (dBm)', _tx, 'within regional limit'),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (si != null)
                TextButton(
                  onPressed: () => _loadFrom(si),
                  child: const Text('Load from device'),
                ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Apply radio params'),
                onPressed: ready ? () => _applyRadio(mc) : null,
              ),
            ],
          ),
          if (!ready)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Connect a radio first (Diagnostics & connect).',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          const Divider(height: 28),
          for (final ({String h, String s}) row in const <({
            String h,
            String s
          })>[
            (h: 'IDENTITY / ADVERT', s: 'Node name · advert lat/lon (later)'),
            (h: 'CHANNELS', s: 'List · add/edit (name + PSK) · QR (later)'),
            (h: 'OTHER PARAMS / TUNING', s: 'Telemetry · multi-acks (later)'),
            (h: 'DEVICE', s: 'Firmware · battery · time sync (later)'),
          ])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(row.h),
              subtitle: Text(row.s,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: .55))),
            ),
        ],
      ),
    );
  }
}
