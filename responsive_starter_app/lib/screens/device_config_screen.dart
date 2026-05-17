import 'package:flutter/material.dart';

/// Device configuration (Meshcore radio/device — R7). Wired to the
/// M4 protocol surface (`MeshcoreController` / `MeshcoreFrameCodec`)
/// in U4; U1 ships the routed, themed scaffold.
class DeviceConfigScreen extends StatelessWidget {
  const DeviceConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Device configuration')),
      body: ListView(
        children: <Widget>[
          for (final ({String h, String s}) row in const <({String h, String s})>[
            (h: 'RADIO', s: 'Frequency · Bandwidth · SF · CR · TX power'),
            (h: 'IDENTITY / ADVERT', s: 'Node name · advert lat/lon · send advert'),
            (h: 'CHANNELS', s: 'List · add/edit (name + PSK) · QR import'),
            (h: 'OTHER PARAMS / TUNING', s: 'Manual-add · telemetry · multi-acks'),
            (h: 'DEVICE', s: 'Firmware · battery & storage · time sync'),
          ])
            ListTile(
              title: Text(row.h),
              subtitle: Text(row.s,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: .6))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Wired to the M4/R7 protocol surface in U4.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .5)),
            ),
          ),
        ],
      ),
    );
  }
}
