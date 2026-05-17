import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshcore/meshcore.dart';
import 'package:provider/provider.dart';

import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';

/// Field/dev tool: connect to a real Meshcore radio, watch live state
/// and the raw frame log, send test commands, and run the M6
/// interop closure (export a `grp_txt_capture` fixture + the
/// channel-secret-tail oracle) — all over the existing
/// `MeshcoreController`. Reached from Settings.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final TextEditingController _msg =
      TextEditingController(text: 'M6 interop test 1');
  String? _exportJson;
  String? _oracleResult;

  static String get _pubPskHex => kPublicChannelPsk
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  Uint8List _hex(String s) {
    final Uint8List out = Uint8List(s.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send(MeshcoreController mc, Uint8List frame, String what) async {
    try {
      await mc.send(frame);
      _toast('Sent $what');
    } catch (e) {
      _toast('Send failed: $e');
    }
  }

  void _export(MeshcoreController mc) {
    try {
      final String json = mc.exportGrpTxtFixture(
        pskHex: _pubPskHex,
        knownPlaintextUtf8: _msg.text,
        channelName: kPublicChannelName,
        firmware: 'companion-v1.15.0 / dee3e26 (record exact T1000-E fw)',
        description: 'Public-channel msg captured via 0x88',
      );
      setState(() => _exportJson = json);
    } catch (e) {
      _toast('$e — need a captured 0x88 RF-log frame first');
    }
  }

  void _resolveTail(MeshcoreController mc) {
    final String? hex = mc.lastRfLogHex;
    if (hex == null) {
      _toast('No 0x88 RF-log frame captured yet');
      return;
    }
    final MeshcoreInbound f = MeshcoreFrameCodec.decode(_hex(hex));
    if (f is! RfLogFrame) {
      _toast('Last RF-log frame did not decode as RfLogFrame');
      return;
    }
    final GrpTxtPayload? g = f.log.packet?.grpTxt;
    if (g == null) {
      _toast('Captured packet is not a GRP_TXT — send on Public & retry');
      return;
    }
    final ChannelTailResult r = resolveChannelTail(
      psk: Uint8List.fromList(kPublicChannelPsk),
      knownPlaintext: Uint8List.fromList(utf8.encode(_msg.text)),
      grpTxt: g,
    );
    setState(() => _oracleResult = r.resolved
        ? 'RESOLVED → channel-secret tail = ${r.match!.name} '
            '(channelHashOk: ${r.channelHashOk})'
        : 'UNRESOLVED — try another capture / confirm PSK & plaintext');
  }

  @override
  Widget build(BuildContext context) {
    final MeshcoreController mc = context.watch<MeshcoreController>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool live = mc.state == MeshcoreConnectionState.ready ||
        mc.state == MeshcoreConnectionState.handshaking ||
        mc.state == MeshcoreConnectionState.reconnecting;
    final int nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final List<String> log = mc.captureLog.reversed.take(24).toList();

    Widget section(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text(t,
              style: TextStyle(
                  fontSize: 11, letterSpacing: 2, color: cs.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics & connect')),
      body: ListView(
        children: <Widget>[
          section('CONNECTION'),
          ListTile(
            title: Text('State: ${mc.state.name}'
                '${mc.isConnecting ? ' · connecting…' : ''}'),
            subtitle: Text(<String>[
              if (mc.selfInfo != null)
                'device: ${mc.selfInfo!.name} · '
                    '${mc.selfInfo!.frequencyMhz}MHz SF${mc.selfInfo!.spreadingFactor}',
              if (mc.reconnectAttempt > 0)
                'reconnect attempt ${mc.reconnectAttempt}'
                    '${mc.gaveUp ? ' (gave up)' : ''}',
              if (mc.error != null) 'error: ${mc.error}',
            ].join('\n')),
            isThreeLine: mc.selfInfo != null || mc.error != null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              icon: Icon(live ? Icons.link_off : Icons.bluetooth_searching),
              label: Text(live ? 'Disconnect' : 'Scan & connect'),
              onPressed: () =>
                  live ? mc.disconnect() : mc.connect(),
            ),
          ),
          section('SEND (requires connection)'),
          Wrap(
            spacing: 8,
            children: <Widget>[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _send(
                    mc, MeshcoreFrameCodec.sendSelfAdvert(), 'self-advert'),
                child: const Text('Self-advert'),
              ),
              OutlinedButton(
                onPressed: () => _send(
                    mc, MeshcoreFrameCodec.getDeviceTime(), 'get-time'),
                child: const Text('Get time'),
              ),
              OutlinedButton(
                onPressed: () => _send(mc,
                    MeshcoreFrameCodec.syncNextMessage(), 'sync-msg'),
                child: const Text('Sync msg'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _msg,
                    decoration: const InputDecoration(
                        labelText: 'Public-channel test message'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _send(
                    mc,
                    MeshcoreFrameCodec.sendChannelTextMessage(
                      channelIdx: 0,
                      timestamp: nowUnix,
                      text: _msg.text,
                    ),
                    'ch0 message',
                  ),
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
          section('M6 INTEROP CLOSURE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, children: <Widget>[
              OutlinedButton.icon(
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Resolve channel-tail'),
                onPressed: () => _resolveTail(mc),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text('Export fixture'),
                onPressed: () => _export(mc),
              ),
            ]),
          ),
          if (_oracleResult != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_oracleResult!,
                  style: TextStyle(color: cs.primary)),
            ),
          if (_exportJson != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy fixture JSON'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _exportJson!));
                      _toast('Copied — save to '
                          'packages/meshcore/test/vectors/interop/');
                    },
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: cs.surfaceContainerHighest,
                    child: SelectableText(_exportJson!,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                  ),
                ],
              ),
            ),
          section('RAW FRAME LOG (newest first)'),
          if (log.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('— no frames yet —'),
            ),
          for (final String hex in log)
            ListTile(
              dense: true,
              title: Text(
                _label(hex),
                style: TextStyle(
                    color: hex.startsWith('88') ? cs.primary : cs.onSurface),
              ),
              subtitle: Text(
                hex.length > 64 ? '${hex.substring(0, 64)}…' : hex,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _label(String hex) {
    try {
      final MeshcoreInbound f = MeshcoreFrameCodec.decode(_hex(hex));
      return f.runtimeType.toString();
    } catch (_) {
      return 'op 0x${hex.length >= 2 ? hex.substring(0, 2) : '?'}';
    }
  }
}
