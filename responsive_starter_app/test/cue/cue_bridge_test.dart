// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/cue/cue_bridge.dart';
import 'package:meshmore_sns_app/cue/cue_service.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_connection.dart';
import 'package:meshmore_sns_app/meshcore/meshcore_controller.dart';
import 'package:meshmore_sns_app/theme/theme_controller.dart';

import '../meshcore/fake_transport.dart';

/// Records dispatched cues without touching platform channels.
class _RecordingCue extends CueService {
  _RecordingCue(ThemeController t) : super(theme: t);
  final List<CueKind> calls = <CueKind>[];
  @override
  Future<void> play(CueKind k) async {
    calls.add(k);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reaching ready fires linkUp', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl = MeshcoreController(
      transportFactory: () async => fake,
      connection:
          MeshcoreConnection(handshakeTimeout: const Duration(seconds: 5)),
    );
    final _RecordingCue cue = _RecordingCue(ThemeController());
    final CueBridge bridge = CueBridge(ctrl, cue);

    await ctrl.connect();
    fake.emit(selfInfoFrame()); // → ready
    await Future<void>.delayed(Duration.zero);

    expect(cue.calls, contains(CueKind.linkUp));
    bridge.dispose();
    ctrl.dispose();
  });

  test('incoming DM fires dmIn', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl =
        MeshcoreController(transportFactory: () async => fake);
    final _RecordingCue cue = _RecordingCue(ThemeController());
    final CueBridge bridge = CueBridge(ctrl, cue);

    await ctrl.connect();
    fake.emit(contactMessageFrame(
        prefix: <int>[1, 2, 3, 4, 5, 6], text: 'hi'));
    await Future<void>.delayed(Duration.zero);

    expect(cue.calls, contains(CueKind.dmIn));
    bridge.dispose();
    ctrl.dispose();
  });

  test('a newly heard node fires discovery (the Geiger tick)', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl =
        MeshcoreController(transportFactory: () async => fake);
    final _RecordingCue cue = _RecordingCue(ThemeController());
    final CueBridge bridge = CueBridge(ctrl, cue);

    await ctrl.connect();
    // A fresh advert → a brand-new node in mc.nodes → discovery cue.
    fake.emit(advertFrame(name: 'NewNode', firstPubByte: 80));
    await Future<void>.delayed(Duration.zero);

    expect(cue.calls, contains(CueKind.discovery));

    // A repeat advert from the same node does NOT re-fire discovery —
    // it fires the ambient `advert` ping instead.
    cue.calls.clear();
    fake.emit(advertFrame(name: 'NewNode', firstPubByte: 80));
    await Future<void>.delayed(Duration.zero);
    expect(cue.calls, isNot(contains(CueKind.discovery)));
    expect(cue.calls, contains(CueKind.advert));

    bridge.dispose();
    ctrl.dispose();
  });

  test('incoming channel message fires messageIn', () async {
    final FakeMeshcoreTransport fake =
        FakeMeshcoreTransport(connected: true);
    final MeshcoreController ctrl =
        MeshcoreController(transportFactory: () async => fake);
    final _RecordingCue cue = _RecordingCue(ThemeController());
    final CueBridge bridge = CueBridge(ctrl, cue);

    await ctrl.connect();
    fake.emit(channelMsgFrame(text: 'hi'));
    await Future<void>.delayed(Duration.zero);

    expect(cue.calls, contains(CueKind.messageIn));
    bridge.dispose();
    ctrl.dispose();
  });
}
