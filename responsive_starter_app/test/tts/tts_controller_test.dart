// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/tts/tts_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTtsSpeaker implements TtsSpeaker {
  final List<String> spoken = <String>[];
  int stops = 0;
  double? lastRate;
  double? lastPitch;
  TtsVoice? lastVoice;
  List<TtsVoice> voices = const <TtsVoice>[];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> setRate(double rate) async => lastRate = rate;

  @override
  Future<void> setPitch(double pitch) async => lastPitch = pitch;

  @override
  Future<void> setVoice(TtsVoice? voice) async => lastVoice = voice;

  @override
  Future<List<TtsVoice>> listVoices() async => voices;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('off by default; speak is a no-op until enabled (R5)', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final FakeTtsSpeaker spk = FakeTtsSpeaker();
    final TtsController tts = TtsController(speaker: spk);
    await tts.load();

    expect(tts.enabled, isFalse);
    expect(tts.channelSpeaks(0), isFalse);
    await tts.speakForChannel(0, 'hello');
    expect(spk.spoken, isEmpty);

    await tts.setEnabled(true);
    expect(tts.enabled, isTrue);
    expect(tts.channelSpeaks(0), isTrue);
    await tts.speakForChannel(0, 'hello');
    expect(spk.spoken, <String>['hello']);
  });

  test('per-channel mute gates speech without touching the global',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final FakeTtsSpeaker spk = FakeTtsSpeaker();
    final TtsController tts = TtsController(speaker: spk);
    await tts.setEnabled(true);

    tts.toggleChannelMute(2);
    expect(tts.isChannelMuted(2), isTrue);
    expect(tts.channelSpeaks(2), isFalse);
    expect(tts.channelSpeaks(0), isTrue); // others unaffected
    await tts.speakForChannel(2, 'muted');
    await tts.speakForChannel(0, 'audible');
    expect(spk.spoken, <String>['audible']);

    tts.toggleChannelMute(2); // unmute
    expect(tts.channelSpeaks(2), isTrue);
  });

  test('global flag persists; disabling stops the speaker', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final FakeTtsSpeaker spk = FakeTtsSpeaker();
    final TtsController a = TtsController(speaker: spk);
    await a.setEnabled(true);
    expect(spk.stops, 0);
    await a.setEnabled(false);
    expect(spk.stops, 1);

    // A fresh controller reads back the persisted (false) value.
    final TtsController b = TtsController(speaker: FakeTtsSpeaker());
    await b.load();
    expect(b.enabled, isFalse);

    SharedPreferences.setMockInitialValues(<String, Object>{'mm.tts': true});
    final TtsController c = TtsController(speaker: FakeTtsSpeaker());
    await c.load();
    expect(c.enabled, isTrue);
  });
}
