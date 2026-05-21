// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore/meshcore.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';

import 'fake_transport.dart';

void main() {
  test('attach to a connected transport → handshaking + APP_START sent',
      () async {
    final FakeMeshcoreTransport t = FakeMeshcoreTransport(connected: true);
    final MeshcoreConnection c = MeshcoreConnection(appName: 'unit-test');
    c.attach(t);

    expect(c.state, MeshcoreConnectionState.handshaking);
    expect(t.sent, hasLength(1));
    expect(t.sent.first,
        MeshcoreFrameCodec.appStart(appName: 'unit-test'));
    await c.dispose();
  });

  test('SELF_INFO completes the handshake → ready + selfInfo set',
      () async {
    final FakeMeshcoreTransport t = FakeMeshcoreTransport(connected: true);
    final MeshcoreConnection c = MeshcoreConnection();
    final List<MeshcoreConnectionState> seen = <MeshcoreConnectionState>[];
    c.states.listen(seen.add);
    c.attach(t);

    t.emit(selfInfoFrame());
    await Future<void>.delayed(Duration.zero);

    expect(c.state, MeshcoreConnectionState.ready);
    expect(c.selfInfo, isNotNull);
    expect(seen, contains(MeshcoreConnectionState.ready));
    await c.dispose();
  });

  test('inbound frames are decoded and forwarded', () async {
    final FakeMeshcoreTransport t = FakeMeshcoreTransport(connected: true);
    final MeshcoreConnection c = MeshcoreConnection();
    c.attach(t);
    final Future<MeshcoreInbound> next =
        c.inbound.firstWhere((MeshcoreInbound f) => f is CurrentTimeFrame);

    t.emit(currentTimeFrame());
    final MeshcoreInbound f = await next;

    expect(f, isA<CurrentTimeFrame>());
    expect((f as CurrentTimeFrame).unixSeconds, 1700000000);
    await c.dispose();
  });

  test('link drop after ready → reconnecting', () async {
    final FakeMeshcoreTransport t = FakeMeshcoreTransport(connected: true);
    final MeshcoreConnection c = MeshcoreConnection();
    c.attach(t);
    t.emit(selfInfoFrame());
    await Future<void>.delayed(Duration.zero);
    expect(c.state, MeshcoreConnectionState.ready);

    t.setConnected(false);
    await Future<void>.delayed(Duration.zero);
    expect(c.state, MeshcoreConnectionState.reconnecting);
    await c.dispose();
  });

  test('no SELF_INFO before timeout → failed', () async {
    final FakeMeshcoreTransport t = FakeMeshcoreTransport(connected: true);
    final MeshcoreConnection c = MeshcoreConnection(
        handshakeTimeout: const Duration(milliseconds: 40));
    c.attach(t);
    expect(c.state, MeshcoreConnectionState.handshaking);

    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(c.state, MeshcoreConnectionState.failed);
    await c.dispose();
  });

  test('sendCommand throws when not connected', () async {
    final FakeMeshcoreTransport t = FakeMeshcoreTransport(connected: false);
    final MeshcoreConnection c = MeshcoreConnection();
    c.attach(t);
    expect(
      () => c.sendCommand(Uint8List.fromList(<int>[0x0A])),
      throwsStateError,
    );
    await c.dispose();
  });
}
