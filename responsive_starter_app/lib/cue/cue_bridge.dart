// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:async';

import '../meshcore/chat_message.dart';
import '../meshcore/meshcore_connection.dart';
import '../meshcore/meshcore_controller.dart';
import 'cue_service.dart';

/// Wires [MeshcoreController] events to [CueService] (R12). Lives
/// app-scoped so cues fire wherever — independent of which screen is
/// foregrounded — and the call site (UI) is free to provide the
/// matching visual parity.
class CueBridge {
  CueBridge(this._mc, this._cue) {
    _prev = _mc.state;
    _wasScanning = _mc.isScanning;
    _mc.addListener(_onChange);
    _msgSub =
        _mc.incomingChannelMessages.listen(_onIncomingChannelMessage);
    _dmSub =
        _mc.incomingDirectMessages.listen(_onIncomingDm);
    _errSub = _mc.taskErrors.listen((_) => _cue.play(CueKind.taskError));
    _advSub = _mc.incomingAdverts.listen(_onAdvert);
  }

  final MeshcoreController _mc;
  final CueService _cue;
  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<ChatMessage>? _dmSub;
  StreamSubscription<String>? _errSub;
  StreamSubscription<bool>? _advSub;
  late MeshcoreConnectionState _prev;
  late bool _wasScanning;

  /// Re-adverts arrive far faster than they should be sounded on a busy
  /// fabric; gate the ambient `advert` ping to at most one per window.
  DateTime _lastAdvertCue = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _advertThrottle = Duration(milliseconds: 1500);

  void _onChange() {
    final MeshcoreConnectionState s = _mc.state;
    if (s != _prev) {
      switch (s) {
        case MeshcoreConnectionState.ready:
          _cue.play(CueKind.linkUp);
        case MeshcoreConnectionState.failed:
          _cue.play(CueKind.alert);
        case MeshcoreConnectionState.reconnecting:
          _cue.play(CueKind.linkDown);
        case MeshcoreConnectionState.disconnected:
        case MeshcoreConnectionState.handshaking:
          break; // no cue
      }
      _prev = s;
    }
    // Scan rising/falling edge → scanStart / taskOk. Detected on any
    // controller notify since isScanning is set & notifyListeners'd by
    // mc.scan() + the scan-window timer.
    final bool nowScanning = _mc.isScanning;
    if (nowScanning != _wasScanning) {
      // Scanning drone runs for the *whole* window: start the loop on the
      // rising edge, stop it + chime taskOk on the falling edge.
      if (nowScanning) {
        _cue.startScanHum();
      } else {
        _cue.stopScanHum();
        _cue.play(CueKind.taskOk);
      }
      _wasScanning = nowScanning;
    }
  }

  /// A live advert was folded into the fabric. `isNew` is true for a
  /// node we'd never heard (→ discovery, the Geiger tick) and false for
  /// a re-advert from a known node (→ advert, the ambient ping). The
  /// stream only fires for over-the-air adverts, so the post-connect
  /// contact-sync dump never reaches here — no machine-gunning.
  void _onAdvert(bool isNew) {
    if (_mc.isDraining) return;
    if (isNew) {
      _cue.play(CueKind.discovery);
      return;
    }
    final DateTime now = DateTime.now();
    if (now.difference(_lastAdvertCue) < _advertThrottle) return;
    _lastAdvertCue = now;
    _cue.play(CueKind.advert);
  }

  void _onIncomingChannelMessage(ChatMessage _) =>
      _cue.play(CueKind.messageIn);

  void _onIncomingDm(ChatMessage _) => _cue.play(CueKind.dmIn);

  void dispose() {
    _cue.stopScanHum(); // don't leave the drone looping if torn down mid-scan
    _mc.removeListener(_onChange);
    _msgSub?.cancel();
    _dmSub?.cancel();
    _errSub?.cancel();
    _advSub?.cancel();
  }
}
