// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A voice the platform TTS engine can synthesize with. The pair
/// `(name, locale)` is the unique identifier flutter_tts expects on
/// `setVoice`; the optional `qualityHint` lets us bubble up a
/// platform-specific quality label (e.g. "enhanced") to the picker.
class TtsVoice {
  const TtsVoice({
    required this.name,
    required this.locale,
    this.qualityHint,
  });

  final String name;
  final String locale;
  final String? qualityHint;

  /// Stable id we persist in shared_preferences — `name|locale`.
  /// Lets us re-find this voice on the next launch even though
  /// `flutter_tts.getVoices()` returns objects that aren't `==`able.
  String get id => '$name|$locale';

  static TtsVoice? parseId(String id) {
    final int sep = id.indexOf('|');
    if (sep <= 0) return null;
    return TtsVoice(
        name: id.substring(0, sep), locale: id.substring(sep + 1));
  }
}

/// Pluggable speech backend so the controller is unit-testable
/// without the platform `flutter_tts` plugin. The controller calls
/// `setRate / setPitch / setVoice` whenever those properties change
/// before issuing `speak`, so the speaker just needs to honour the
/// last-set values.
abstract class TtsSpeaker {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVoice(TtsVoice? voice);

  /// Voices the platform reports as installed/available. May be
  /// empty on platforms where the plugin can't enumerate (returns
  /// empty list rather than throwing).
  Future<List<TtsVoice>> listVoices();

  /// True when the language pack backing [locale] (e.g. `"en-US"`)
  /// is installed locally on the device — i.e. synthesis works
  /// offline. False when the locale would require network access
  /// (or isn't available). Best-effort: on iOS this is effectively
  /// "is this voice known to the system"; on Android it tracks
  /// the active engine's downloaded language packs.
  Future<bool> isLanguageAvailable(String locale);
}

/// Default speaker — thin wrapper over `flutter_tts`. Not exercised in
/// `flutter test` (no platform channel); covered on-device.
class FlutterTtsSpeaker implements TtsSpeaker {
  FlutterTtsSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();
  final FlutterTts _tts;

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<void> setVoice(TtsVoice? voice) async {
    if (voice == null) return;
    try {
      await _tts.setVoice(<String, String>{
        'name': voice.name,
        'locale': voice.locale,
      });
    } catch (_) {
      // Voice not installed any more / plugin disagreed — fall
      // through to the platform default. Silent: not worth a snack.
    }
  }

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    try {
      final dynamic raw = await _tts.isLanguageAvailable(locale);
      // Android returns int (0..2, "available + installed"); iOS
      // returns bool. Map both to a strict-offline "true" only
      // when the platform's strongest signal is set.
      if (raw is bool) return raw;
      if (raw is int) return raw >= 1;
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<TtsVoice>> listVoices() async {
    try {
      final dynamic raw = await _tts.getVoices;
      if (raw is! List) return const <TtsVoice>[];
      final List<TtsVoice> out = <TtsVoice>[];
      for (final dynamic v in raw) {
        if (v is! Map) continue;
        final String? name = v['name']?.toString();
        final String? locale = v['locale']?.toString();
        if (name == null || locale == null) continue;
        out.add(TtsVoice(
          name: name,
          locale: locale,
          qualityHint: v['quality']?.toString(),
        ));
      }
      return out;
    } catch (_) {
      return const <TtsVoice>[];
    }
  }
}

/// Text-to-speech preference + gate (R5).
///
/// TTS is **off by default**. A global switch (App settings) is the
/// parent; each channel additionally has a per-channel mute (Chat
/// header) that only matters while the global switch is on.
///
/// Quality (R5/U5 extension): the global rate, pitch, and an
/// optional preferred voice are persisted across launches. Setters
/// also push the new value down into the speaker so the next
/// `speak` reflects it immediately.
class TtsController extends ChangeNotifier {
  TtsController({TtsSpeaker? speaker})
      : _speaker = speaker ?? FlutterTtsSpeaker();

  static const String _kEnabled = 'mm.tts';
  static const String _kRate = 'mm.tts.rate';
  static const String _kPitch = 'mm.tts.pitch';
  static const String _kVoiceId = 'mm.tts.voiceId';

  /// Default rate matches flutter_tts default on iOS / Android
  /// "natural" cadence.
  static const double defaultRate = 0.5;
  static const double defaultPitch = 1.0;
  static const double minRate = 0.3;
  static const double maxRate = 1.0;
  static const double minPitch = 0.7;
  static const double maxPitch = 1.4;

  final TtsSpeaker _speaker;
  bool _enabled = false;
  double _rate = defaultRate;
  double _pitch = defaultPitch;
  TtsVoice? _voice;
  final Set<int> _mutedChannels = <int>{};

  /// Global TTS on/off.
  bool get enabled => _enabled;
  double get rate => _rate;
  double get pitch => _pitch;
  TtsVoice? get voice => _voice;

  /// True when [channelIdx] would be spoken: global on AND not muted.
  bool channelSpeaks(int channelIdx) =>
      _enabled && !_mutedChannels.contains(channelIdx);

  bool isChannelMuted(int channelIdx) =>
      _mutedChannels.contains(channelIdx);

  /// Load the persisted global flag + quality knobs. Safe to call
  /// once at startup. Applies the loaded values to the speaker.
  Future<void> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    _enabled = p.getBool(_kEnabled) ?? false;
    _rate = (p.getDouble(_kRate) ?? defaultRate).clamp(minRate, maxRate);
    _pitch =
        (p.getDouble(_kPitch) ?? defaultPitch).clamp(minPitch, maxPitch);
    final String? vid = p.getString(_kVoiceId);
    _voice = vid == null ? null : TtsVoice.parseId(vid);
    // Push to speaker so the very first speak() reflects loaded prefs.
    await _speaker.setRate(_rate);
    await _speaker.setPitch(_pitch);
    if (_voice != null) await _speaker.setVoice(_voice);
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    if (v == _enabled) return;
    _enabled = v;
    if (!v) await _speaker.stop();
    notifyListeners();
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, v);
  }

  Future<void> setRate(double v) async {
    final double c = v.clamp(minRate, maxRate);
    if (c == _rate) return;
    _rate = c;
    await _speaker.setRate(c);
    notifyListeners();
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setDouble(_kRate, c);
  }

  Future<void> setPitch(double v) async {
    final double c = v.clamp(minPitch, maxPitch);
    if (c == _pitch) return;
    _pitch = c;
    await _speaker.setPitch(c);
    notifyListeners();
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setDouble(_kPitch, c);
  }

  Future<void> setVoice(TtsVoice? v) async {
    if (v?.id == _voice?.id) return;
    _voice = v;
    await _speaker.setVoice(v);
    notifyListeners();
    final SharedPreferences p = await SharedPreferences.getInstance();
    if (v == null) {
      await p.remove(_kVoiceId);
    } else {
      await p.setString(_kVoiceId, v.id);
    }
  }

  /// Enumerates voices the platform engine knows about (filtered to
  /// the locales we use). May be empty on test backends.
  Future<List<TtsVoice>> listVoices() => _speaker.listVoices();

  /// True when [locale] (e.g. `"en-US"`) is installed locally —
  /// synthesis will work offline for that pack. Exposed for the
  /// Voice settings UI to badge each row.
  Future<bool> isLanguageAvailable(String locale) =>
      _speaker.isLanguageAvailable(locale);

  /// Speak a one-off preview phrase (used by the App-settings "Try
  /// a phrase" button). Bypasses the per-channel mute since the user
  /// is auditioning the *quality* knobs, not the channel routing.
  /// Still respects the global enable.
  Future<void> previewPhrase(String phrase) async {
    if (!_enabled) return;
    await _speaker.speak(phrase);
  }

  /// Toggle the per-channel mute (no effect on the persisted global).
  void toggleChannelMute(int channelIdx) {
    if (!_mutedChannels.remove(channelIdx)) {
      _mutedChannels.add(channelIdx);
    }
    notifyListeners();
  }

  /// Speak [text] for [channelIdx] iff that channel is currently
  /// audible. A no-op otherwise (single gate for all callers).
  Future<void> speakForChannel(int channelIdx, String text) async {
    if (!channelSpeaks(channelIdx)) return;
    await _speaker.speak(text);
  }
}
