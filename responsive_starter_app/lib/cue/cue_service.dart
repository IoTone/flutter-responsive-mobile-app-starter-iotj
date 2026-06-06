// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/services.dart';

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

/// Default haptic: `HapticFeedback` mapped per cue (system-respecting:
/// silent/vibrate modes are honoured by the OS).
class SystemHapticBackend implements HapticBackend {
  const SystemHapticBackend();
  @override
  Future<void> play(CueKind kind) async {
    try {
      switch (kind) {
        case CueKind.alert:
        case CueKind.taskError:
          await HapticFeedback.heavyImpact();
        case CueKind.send:
        case CueKind.discovery:
        case CueKind.dmIn:
        case CueKind.taskOk:
        case CueKind.boot:
          await HapticFeedback.mediumImpact();
        case CueKind.linkUp:
        case CueKind.linkDown:
        case CueKind.scanStart:
        case CueKind.navNext:
        case CueKind.navPrev:
          await HapticFeedback.selectionClick();
        case CueKind.messageIn:
        case CueKind.advert:
          await HapticFeedback.lightImpact();
      }
    } catch (_) {
      // No platform / no actuator — silent.
    }
  }
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
