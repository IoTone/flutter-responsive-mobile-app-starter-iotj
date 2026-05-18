import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';

/// Device configuration (R7). The **Radio / Region** section is wired
/// to the M4 protocol surface (`setRadioParams` / `setRadioTxPower`).
/// Other sections remain scaffolds (later U-steps).
///
/// "Region" is an app convenience — the companion protocol only
/// carries raw frequency/BW/SF/CR. We expose the band edges we can
/// cite (Seeed T1000-E wiki) and let you confirm the exact frequency;
/// **all nodes must use identical radio params or they can't hear
/// each other**, so match your other devices / the official app.
class DeviceConfigScreen extends StatefulWidget {
  const DeviceConfigScreen({super.key});

  @override
  State<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

/// Cited from the Seeed SenseCAP T1000-E + MeshCore wiki (band edges /
/// duty / power are regulatory, not MeshCore-proprietary). The
/// frequency we pre-fill is an in-band value you must confirm for
/// your country and match across nodes.
class _Band {
  const _Band(this.label, this.freqMhz, this.note);
  final String label;
  final double freqMhz;
  final String note;
}

const List<_Band> _bands = <_Band>[
  _Band('US (902–928 MHz)', 915.0, '100% duty · ≤30 dBm'),
  _Band('EU 868 (869.4–869.65)', 869.525, '10% duty · ≤27 dBm'),
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
                  onPressed: band.freqMhz == 0
                      ? null
                      : () {
                          _freq.text = band.freqMhz.toString();
                          _toast('${band.label}: confirm it is legal in '
                              'your country & matches your other nodes');
                        },
                  child: Text(band.label),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Band edges/duty/power are regulatory (Seeed T1000-E '
              'wiki). MeshCore sends raw frequency — pick the band '
              'legal where you are and use the SAME values on every '
              'node.',
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
