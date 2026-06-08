// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/cue/cue_service.dart';
import 'package:meshmore_sns_app/theme/mm_tokens.dart';
import 'package:meshmore_sns_app/theme/theme_controller.dart';

class _FakeAudio implements AudioPack {
  final List<CueKind> calls = <CueKind>[];
  final List<CueKind> loops = <CueKind>[];
  int stopLoopCalls = 0;
  @override
  Future<void> play(CueKind k) async => calls.add(k);
  @override
  Future<void> startLoop(CueKind k) async => loops.add(k);
  @override
  Future<void> stopLoop() async => stopLoopCalls++;
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

  test('scan hum loops scanStart (gated like audio) and stops on demand',
      () async {
    final ThemeController tc = ThemeController();
    await tc.setAudioMaster(true);
    final _FakeAudio a = _FakeAudio();
    final _FakeHaptic h = _FakeHaptic();
    final CueService cue = CueService(theme: tc, audio: a, haptic: h);

    await cue.startScanHum();
    await Future<void>.delayed(Duration.zero);
    expect(a.loops, <CueKind>[CueKind.scanStart]);
    expect(h.calls, <CueKind>[CueKind.scanStart]); // haptic marks start

    await cue.stopScanHum();
    await Future<void>.delayed(Duration.zero);
    expect(a.stopLoopCalls, 1);
  });

  test('scan hum: audio muted → no loop, but stop still safe', () async {
    final ThemeController tc = ThemeController();
    await tc.setAudioMaster(false);
    final _FakeAudio a = _FakeAudio();
    final _FakeHaptic h = _FakeHaptic();
    final CueService cue = CueService(theme: tc, audio: a, haptic: h);

    await cue.startScanHum();
    await cue.stopScanHum();
    await Future<void>.delayed(Duration.zero);
    expect(a.loops, isEmpty);
    expect(h.calls, <CueKind>[CueKind.scanStart]); // haptic always
    expect(a.stopLoopCalls, 1); // idempotent stop
  });

  group('hapticPatternFor (per-theme feel)', () {
    test('every preset × cue resolves to a non-empty pattern', () {
      for (final MmThemePreset p in MmThemePreset.values) {
        for (final CueKind k in CueKind.values) {
          expect(hapticPatternFor(p, k), isNotEmpty, reason: '$p/$k');
        }
      }
    });

    test('null preset falls back to the neutral default', () {
      expect(hapticPatternFor(null, CueKind.alert),
          <HapticHit>[HapticHit.heavy]);
    });

    test('themes feel different for the same cue (alert)', () {
      // NERV klaxons (triple), Recon is a single firm hit.
      expect(hapticPatternFor(MmThemePreset.nerv, CueKind.alert).length, 3);
      expect(hapticPatternFor(MmThemePreset.recon, CueKind.alert).length, 1);
      // Hyperlocal stays calm — never a heavy pulse, even on critical.
      expect(hapticPatternFor(MmThemePreset.hyperlocal, CueKind.alert),
          everyElement(isNot(HapticHit.heavy)));
      // At least 3 distinct alert patterns across the 6 themes.
      final Set<String> variants = <String>{
        for (final MmThemePreset p in MmThemePreset.values)
          hapticPatternFor(p, CueKind.alert)
              .map((HapticHit h) => h.name)
              .join(','),
      };
      expect(variants.length, greaterThanOrEqualTo(3));
    });

    test('discovery (arrival) is distinct from a DM in NERV', () {
      expect(hapticPatternFor(MmThemePreset.nerv, CueKind.discovery),
          isNot(hapticPatternFor(MmThemePreset.nerv, CueKind.dmIn)));
    });
  });
}
