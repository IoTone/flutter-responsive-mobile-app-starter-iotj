// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
//
// Direct unit test of the pretty-name parser used by the voice
// picker. We expose the helper through a small wrapper subclass so
// the static private method can be exercised without spinning up
// the whole VoiceSettingsScreen widget (which would need flutter_tts
// + a controller + provider scaffolding).

import 'package:flutter_test/flutter_test.dart';
import 'package:meshmore_sns_app/screens/voice_settings_screen.dart';

void main() {
  group('voicePrettyName parser', () {
    test('iOS-style friendly names pass through unchanged', () {
      expect(VoiceSettingsScreen.prettyVoiceNameDebug('Samantha', 'en-US'),
          'Samantha');
      expect(VoiceSettingsScreen.prettyVoiceNameDebug('Alex', 'en-US'),
          'Alex');
      expect(VoiceSettingsScreen.prettyVoiceNameDebug('Kyoko', 'ja-JP'),
          'Kyoko');
    });

    test('Android cryptic IDs are parsed to human-readable text', () {
      expect(
        VoiceSettingsScreen.prettyVoiceNameDebug(
            'en-us-x-sfg#female_2-local', 'en-US'),
        contains('Female 2'),
      );
      expect(
        VoiceSettingsScreen.prettyVoiceNameDebug(
            'en-us-x-iol-network', 'en-US'),
        contains('IOL'),
      );
    });

    test('locale prefix is stripped (we display locale separately)',
        () {
      final String name = VoiceSettingsScreen.prettyVoiceNameDebug(
          'en-us-x-sfg#female_2-local', 'en-US');
      expect(name.toLowerCase(), isNot(contains('en-us')));
    });

    test('local/network suffix is removed (we surface via OFFLINE badge)',
        () {
      final String localName = VoiceSettingsScreen.prettyVoiceNameDebug(
          'en-us-x-sfg#female_2-local', 'en-US');
      expect(localName.toLowerCase(), isNot(endsWith('local')));
    });

    test('handles `en_US` underscore-style locale tag too', () {
      final String name = VoiceSettingsScreen.prettyVoiceNameDebug(
          'en-us-x-sfg#female_2-local', 'en_US');
      expect(name.toLowerCase(), isNot(contains('en-us')));
    });

    test('empty result falls back to raw name', () {
      expect(VoiceSettingsScreen.prettyVoiceNameDebug('en-us', 'en-US'),
          'en-us');
    });
  });
}
