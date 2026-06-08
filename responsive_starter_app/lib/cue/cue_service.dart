// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/services.dart';

import '../theme/mm_tokens.dart';
import '../theme/theme_controller.dart';

/// Event categories the app dispatches as cues (R12). Audible packs
/// (per-theme, R12 brief) and haptic mappings derive from these.
enum CueKind {
  /// A channel message arrived (anonymous-source by protocol).
  messageIn,

  /// A DM arrived (sender attributable by pubkey prefix).
  dmIn,

  /// A new node joined the fabric (advert / first contact).
  discovery,

  /// A re-advert heard from a node we already knew — ambient mesh life,
  /// distinct from `discovery` (a *new* node) and rate-limited so a busy
  /// fabric doesn't machine-gun it.
  advert,

  /// We sent something (send confirmation cue).
  send,

  /// App came up — played once on the splash/boot as the shell mounts.
  boot,

  /// Swiped forward to the next top-level view (PageView, →).
  navNext,

  /// Swiped back to the previous top-level view (PageView, ←).
  navPrev,

  /// The radio link came up (`ready`).
  linkUp,

  /// The radio link went away or is reconnecting.
  linkDown,

  /// Critical: device error / handshake failure.
  alert,

  /// Long-running task **kicked off** (scan / advert / connect attempt).
  scanStart,

  /// Long-running task **succeeded** (scan window elapsed, advert
  /// acknowledged, etc.).
  taskOk,

  /// Long-running task **failed** (send threw, scan timed out without
  /// any inbound, connect attempt failed). Less harsh than `alert`;
  /// alert is reserved for protocol-level critical errors.
  taskError,
}

/// Pluggable audio backend. The default uses built-in system sounds —
/// per-theme asset packs (R12: "Mission Control" / "Velocity" / etc.)
/// plug in by implementing this interface once their assets exist.
abstract class AudioPack {
  Future<void> play(CueKind kind);

  /// Start a **looping** cue that sustains until [stopLoop] — used for
  /// the scanning drone, which should run for the whole scan window, not
  /// fire once. Packs that can't loop (system sounds) no-op.
  Future<void> startLoop(CueKind kind);

  /// Stop whatever [startLoop] started.
  Future<void> stopLoop();
}

/// Pluggable haptic backend.
abstract class HapticBackend {
  Future<void> play(CueKind kind);
}

/// Default audio: the two built-in `SystemSound` types. Cheap, asset-
/// free, present on every platform. Per-concept packs (audioplayers +
/// short WAVs per theme) supersede this when authored.
class SystemSoundAudioPack implements AudioPack {
  const SystemSoundAudioPack();
  @override
  Future<void> play(CueKind kind) async {
    try {
      final SystemSoundType s = (kind == CueKind.alert ||
              kind == CueKind.linkDown ||
              kind == CueKind.taskError)
          ? SystemSoundType.alert
          : SystemSoundType.click;
      await SystemSound.play(s);
    } catch (_) {
      // No platform / no audio output — silent, by design.
    }
  }

  // System sounds are one-shot — there's nothing to loop, so the
  // scanning drone simply stays silent on this fallback pack.
  @override
  Future<void> startLoop(CueKind kind) async {}
  @override
  Future<void> stopLoop() async {}
}

/// A single haptic pulse intensity. Multi-pulse patterns sequence these
/// with a short gap, so a theme can have a "double-tap" or "triple" feel —
/// the **haptic is part of the skin**, not just the sound (R12 deepening).
enum HapticHit { selection, light, medium, heavy }

/// Cues grouped by haptic intent. Each theme maps these tiers to its own
/// pattern, so the *feel* of "a DM arrived" or "critical" differs per skin.
enum _HTier { ambient, dm, arrival, positive, negative, critical, nav }

_HTier _tierOf(CueKind k) => switch (k) {
      CueKind.messageIn || CueKind.advert => _HTier.ambient,
      CueKind.dmIn => _HTier.dm,
      CueKind.discovery => _HTier.arrival,
      CueKind.linkUp ||
      CueKind.taskOk ||
      CueKind.send ||
      CueKind.boot =>
        _HTier.positive,
      CueKind.linkDown || CueKind.taskError => _HTier.negative,
      CueKind.alert => _HTier.critical,
      CueKind.navNext ||
      CueKind.navPrev ||
      CueKind.scanStart =>
        _HTier.nav,
    };

// Per-theme haptic "feel". SEELE grave/single, NERV terse multi-tick,
// AG-HUD snappy doubles, Hyperlocal soft/calm (never heavy), DR Pop punchy
// rhythmic, Recon crisp-minimal (it's built to run silent → haptic carries
// the parity, so it stays distinct but light).
const Map<_HTier, List<HapticHit>> _seeleHaptics = <_HTier, List<HapticHit>>{
  _HTier.ambient: <HapticHit>[HapticHit.medium],
  _HTier.dm: <HapticHit>[HapticHit.heavy],
  _HTier.arrival: <HapticHit>[HapticHit.medium, HapticHit.medium],
  _HTier.positive: <HapticHit>[HapticHit.medium],
  _HTier.negative: <HapticHit>[HapticHit.heavy],
  _HTier.critical: <HapticHit>[HapticHit.heavy, HapticHit.heavy],
  _HTier.nav: <HapticHit>[HapticHit.selection],
};
const Map<_HTier, List<HapticHit>> _nervHaptics = <_HTier, List<HapticHit>>{
  _HTier.ambient: <HapticHit>[HapticHit.selection],
  _HTier.dm: <HapticHit>[HapticHit.light, HapticHit.light],
  _HTier.arrival: <HapticHit>[
    HapticHit.light,
    HapticHit.light,
    HapticHit.light
  ],
  _HTier.positive: <HapticHit>[HapticHit.medium],
  _HTier.negative: <HapticHit>[HapticHit.heavy],
  _HTier.critical: <HapticHit>[
    HapticHit.heavy,
    HapticHit.heavy,
    HapticHit.heavy
  ],
  _HTier.nav: <HapticHit>[HapticHit.selection],
};
const Map<_HTier, List<HapticHit>> _agHudHaptics = <_HTier, List<HapticHit>>{
  _HTier.ambient: <HapticHit>[HapticHit.light],
  _HTier.dm: <HapticHit>[HapticHit.medium, HapticHit.light],
  _HTier.arrival: <HapticHit>[HapticHit.medium, HapticHit.medium],
  _HTier.positive: <HapticHit>[HapticHit.medium, HapticHit.medium],
  _HTier.negative: <HapticHit>[HapticHit.heavy],
  _HTier.critical: <HapticHit>[HapticHit.heavy, HapticHit.heavy],
  _HTier.nav: <HapticHit>[HapticHit.selection],
};
const Map<_HTier, List<HapticHit>> _hyperHaptics = <_HTier, List<HapticHit>>{
  _HTier.ambient: <HapticHit>[HapticHit.light],
  _HTier.dm: <HapticHit>[HapticHit.medium],
  _HTier.arrival: <HapticHit>[HapticHit.medium],
  _HTier.positive: <HapticHit>[HapticHit.light],
  _HTier.negative: <HapticHit>[HapticHit.medium],
  _HTier.critical: <HapticHit>[HapticHit.medium, HapticHit.medium],
  _HTier.nav: <HapticHit>[HapticHit.selection],
};
const Map<_HTier, List<HapticHit>> _drPopHaptics = <_HTier, List<HapticHit>>{
  _HTier.ambient: <HapticHit>[HapticHit.light, HapticHit.light],
  _HTier.dm: <HapticHit>[HapticHit.medium, HapticHit.medium],
  _HTier.arrival: <HapticHit>[HapticHit.medium, HapticHit.light],
  _HTier.positive: <HapticHit>[HapticHit.medium, HapticHit.medium],
  _HTier.negative: <HapticHit>[HapticHit.heavy],
  _HTier.critical: <HapticHit>[
    HapticHit.heavy,
    HapticHit.heavy,
    HapticHit.heavy
  ],
  _HTier.nav: <HapticHit>[HapticHit.light],
};
const Map<_HTier, List<HapticHit>> _reconHaptics = <_HTier, List<HapticHit>>{
  _HTier.ambient: <HapticHit>[HapticHit.selection],
  _HTier.dm: <HapticHit>[HapticHit.selection, HapticHit.selection],
  _HTier.arrival: <HapticHit>[HapticHit.medium],
  _HTier.positive: <HapticHit>[HapticHit.medium],
  _HTier.negative: <HapticHit>[HapticHit.medium],
  _HTier.critical: <HapticHit>[HapticHit.heavy],
  _HTier.nav: <HapticHit>[HapticHit.selection],
};
// No theme wired (e.g. the default const backend in tests) — a neutral
// profile close to the app's prior flat mapping.
const Map<_HTier, List<HapticHit>> _defaultHaptics = <_HTier, List<HapticHit>>{
  _HTier.ambient: <HapticHit>[HapticHit.light],
  _HTier.dm: <HapticHit>[HapticHit.medium],
  _HTier.arrival: <HapticHit>[HapticHit.medium],
  _HTier.positive: <HapticHit>[HapticHit.medium],
  _HTier.negative: <HapticHit>[HapticHit.heavy],
  _HTier.critical: <HapticHit>[HapticHit.heavy],
  _HTier.nav: <HapticHit>[HapticHit.selection],
};

const Map<MmThemePreset, Map<_HTier, List<HapticHit>>> _hapticProfiles =
    <MmThemePreset, Map<_HTier, List<HapticHit>>>{
  MmThemePreset.seele: _seeleHaptics,
  MmThemePreset.nerv: _nervHaptics,
  MmThemePreset.agHud: _agHudHaptics,
  MmThemePreset.hyperlocal: _hyperHaptics,
  MmThemePreset.drPop: _drPopHaptics,
  MmThemePreset.recon: _reconHaptics,
};

/// The per-theme haptic pattern for a cue (pure — exported for tests).
/// `preset == null` → the neutral default profile.
List<HapticHit> hapticPatternFor(MmThemePreset? preset, CueKind kind) =>
    (_hapticProfiles[preset] ?? _defaultHaptics)[_tierOf(kind)]!;

/// Default haptic: per-theme `HapticFeedback` patterns (system-respecting:
/// silent/vibrate modes are honoured by the OS). Reads `theme.preset` at
/// play time, so a theme switch changes the *feel* immediately — mirroring
/// how [AssetAudioPack] changes the sound. With no [theme] it uses the
/// neutral default profile.
class SystemHapticBackend implements HapticBackend {
  const SystemHapticBackend({
    this.theme,
    this.stepGap = const Duration(milliseconds: 70),
  });

  /// Read for the active preset; null → neutral default patterns.
  final ThemeController? theme;

  /// Spacing between pulses in a multi-hit pattern (double/triple taps).
  final Duration stepGap;

  @override
  Future<void> play(CueKind kind) async {
    final List<HapticHit> pattern = hapticPatternFor(theme?.preset, kind);
    try {
      for (int i = 0; i < pattern.length; i++) {
        if (i > 0) await Future<void>.delayed(stepGap);
        await _fire(pattern[i]);
      }
    } catch (_) {
      // No platform / no actuator — silent.
    }
  }

  Future<void> _fire(HapticHit h) => switch (h) {
        HapticHit.selection => HapticFeedback.selectionClick(),
        HapticHit.light => HapticFeedback.lightImpact(),
        HapticHit.medium => HapticFeedback.mediumImpact(),
        HapticHit.heavy => HapticFeedback.heavyImpact(),
      };
}

/// Dispatches an event → (theme-driven audio) + (always-on haptic),
/// with visual parity expected at the call site (R12/R13). Gating:
/// audio plays only when `theme.audioMaster` is true AND
/// `theme.visualHapticOnly` is false; haptic plays for every cue and
/// the OS honours silent/vibrate.
class CueService {
  CueService({
    required this.theme,
    AudioPack? audio,
    HapticBackend? haptic,
  })  : audio = audio ?? const SystemSoundAudioPack(),
        haptic = haptic ?? const SystemHapticBackend();

  final ThemeController theme;
  final AudioPack audio;
  final HapticBackend haptic;

  Future<void> play(CueKind kind) async {
    if (theme.audioMaster && !theme.visualHapticOnly) {
      unawaited(audio.play(kind));
    }
    unawaited(haptic.play(kind));
  }

  /// Begin the sustained scanning drone (loops [CueKind.scanStart] for
  /// the duration of the scan). Audio honours the same gate as [play];
  /// a single light haptic marks the start regardless.
  Future<void> startScanHum() async {
    if (theme.audioMaster && !theme.visualHapticOnly) {
      unawaited(audio.startLoop(CueKind.scanStart));
    }
    unawaited(haptic.play(CueKind.scanStart));
  }

  /// End the scanning drone. Idempotent — safe to call even if no hum
  /// is playing (e.g. audio was muted when the scan began).
  Future<void> stopScanHum() async {
    unawaited(audio.stopLoop());
  }
}
