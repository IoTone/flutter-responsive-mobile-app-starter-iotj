// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../theme/mm_tokens.dart';
import '../theme/theme_controller.dart';
import 'cue_service.dart';

/// R12 — `AudioPack` that plays per-theme, per-CueKind WAV assets
/// synthesized by `brand/_audio_pack.py`. The active theme is read
/// off `ThemeController.preset` at play time, so a theme switch
/// changes the audio identity *immediately* without rebuilding the
/// service (or restarting the app).
///
/// Asset shape — `assets/audio/<preset.audioPackKey>/<CueKind.name>.wav`.
/// Six preset folders × fourteen CueKinds = 84 files (every theme has a
/// full bespoke set — none fall through to a generic motif); if a file is
/// missing at runtime (asset bundling slipped, etc.) we silently fall back
/// to the system click via [SystemSoundAudioPack].
class AssetAudioPack implements AudioPack {
  AssetAudioPack({
    required this.theme,
    AudioPlayer? player,
    AudioPlayer? loopPlayer,
    AudioPack? fallback,
  })  : _player = player ?? AudioPlayer(),
        _loopPlayer = loopPlayer ?? AudioPlayer(),
        _fallback = fallback ?? const SystemSoundAudioPack();

  final ThemeController theme;
  final AudioPlayer _player;
  // Separate player for the sustained scanning drone, so a one-shot cue
  // firing mid-scan (a node advert, say) doesn't cut the loop short.
  final AudioPlayer _loopPlayer;
  final AudioPack _fallback;

  /// Looped cues (the scan drone) play quieter than one-shots — they run
  /// for seconds and shouldn't dominate. Lower gain per the field brief.
  static const double _loopVolume = 0.45;

  /// Compose the asset path the same way the synth script lays it out.
  /// Visible for the unit test (and for anyone reading the call site).
  static String assetPathFor(MmThemePreset preset, CueKind kind) =>
      'audio/${preset.audioPackKey}/${kind.name}.wav';

  @override
  Future<void> play(CueKind kind) async {
    final MmThemePreset p = theme.preset;
    final String path = assetPathFor(p, kind);
    try {
      // `AssetSource` paths are rooted at `assets/` by audioplayers
      // convention; passing `audio/seele/messageIn.wav` resolves to
      // `assets/audio/seele/messageIn.wav` in the bundle.
      await _player.stop();
      await _player.play(AssetSource(path));
    } catch (_) {
      // Asset missing / platform error → graceful degrade so the cue
      // is never silently lost, just less themed.
      unawaited(_fallback.play(kind));
    }
  }

  @override
  Future<void> startLoop(CueKind kind) async {
    final String path = assetPathFor(theme.preset, kind);
    try {
      await _loopPlayer.stop();
      await _loopPlayer.setReleaseMode(ReleaseMode.loop);
      await _loopPlayer.setVolume(_loopVolume);
      await _loopPlayer.play(AssetSource(path));
    } catch (_) {
      // Asset missing / platform error — the scan just runs silent.
      // (No system-sound fallback: it can't loop.)
    }
  }

  @override
  Future<void> stopLoop() async {
    try {
      await _loopPlayer.stop();
    } catch (_) {
      // Already stopped / disposed — nothing to do.
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _loopPlayer.dispose();
  }
}
