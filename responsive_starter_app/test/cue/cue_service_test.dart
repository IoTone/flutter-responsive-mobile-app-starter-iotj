// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/cue/cue_service.dart';
import 'package:meshmore_sns_app/theme/theme_controller.dart';

class _FakeAudio implements AudioPack {
  final List<CueKind> calls = <CueKind>[];
  @override
  Future<void> play(CueKind k) async => calls.add(k);
}

class _FakeHaptic implements HapticBackend {
  final List<CueKind> calls = <CueKind>[];
  @override
  Future<void> play(CueKind k) async => calls.add(k);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audioMaster off: no audio, haptic always plays', () async {
    final ThemeController tc = ThemeController();
    await tc.setAudioMaster(false); // explicit mute (default is now on)
    final _FakeAudio a = _FakeAudio();
    final _FakeHaptic h = _FakeHaptic();
    final CueService cue = CueService(theme: tc, audio: a, haptic: h);
    await cue.play(CueKind.messageIn);
    await Future<void>.delayed(Duration.zero);
    expect(a.calls, isEmpty);
    expect(h.calls, <CueKind>[CueKind.messageIn]);
  });

  test('audioMaster on (and not visualHapticOnly): audio + haptic',
      () async {
    final ThemeController tc = ThemeController();
    await tc.setAudioMaster(true);
    final _FakeAudio a = _FakeAudio();
    final _FakeHaptic h = _FakeHaptic();
    final CueService cue = CueService(theme: tc, audio: a, haptic: h);
    await cue.play(CueKind.alert);
    await Future<void>.delayed(Duration.zero);
    expect(a.calls, <CueKind>[CueKind.alert]);
    expect(h.calls, <CueKind>[CueKind.alert]);
  });

  test('visualHapticOnly suppresses audio even when master is set',
      () async {
    final ThemeController tc = ThemeController();
    await tc.setAudioMaster(true);
    await tc.setVisualHapticOnly(true);
    final _FakeAudio a = _FakeAudio();
    final _FakeHaptic h = _FakeHaptic();
    final CueService cue = CueService(theme: tc, audio: a, haptic: h);
    await cue.play(CueKind.messageIn);
    await Future<void>.delayed(Duration.zero);
    expect(a.calls, isEmpty);
    expect(h.calls, <CueKind>[CueKind.messageIn]);
  });
}
