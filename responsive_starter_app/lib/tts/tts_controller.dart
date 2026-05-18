import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pluggable speech backend so the controller is unit-testable
/// without the platform `flutter_tts` plugin.
abstract class TtsSpeaker {
  Future<void> speak(String text);
  Future<void> stop();
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
}

/// Text-to-speech preference + gate (R5).
///
/// TTS is **off by default**. A global switch (App settings) is the
/// parent; each channel additionally has a per-channel mute (Chat
/// header) that only matters while the global switch is on. State:
/// the global flag persists; per-channel mutes are session-only.
class TtsController extends ChangeNotifier {
  TtsController({TtsSpeaker? speaker})
      : _speaker = speaker ?? FlutterTtsSpeaker();

  static const String _kEnabled = 'mm.tts';

  final TtsSpeaker _speaker;
  bool _enabled = false;
  final Set<int> _mutedChannels = <int>{};

  /// Global TTS on/off.
  bool get enabled => _enabled;

  /// True when [channelIdx] would be spoken: global on AND not muted.
  bool channelSpeaks(int channelIdx) =>
      _enabled && !_mutedChannels.contains(channelIdx);

  bool isChannelMuted(int channelIdx) =>
      _mutedChannels.contains(channelIdx);

  /// Load the persisted global flag. Safe to call once at startup.
  Future<void> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    _enabled = p.getBool(_kEnabled) ?? false;
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
