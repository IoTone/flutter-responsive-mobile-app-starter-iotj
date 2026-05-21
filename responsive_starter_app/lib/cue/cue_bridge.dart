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
    _mc.addListener(_onChange);
    _msgSub =
        _mc.incomingChannelMessages.listen(_onIncomingChannelMessage);
    _dmSub =
        _mc.incomingDirectMessages.listen(_onIncomingDm);
  }

  final MeshcoreController _mc;
  final CueService _cue;
  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<ChatMessage>? _dmSub;
  late MeshcoreConnectionState _prev;

  void _onChange() {
    final MeshcoreConnectionState s = _mc.state;
    if (s == _prev) return;
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

  void _onIncomingChannelMessage(ChatMessage _) =>
      _cue.play(CueKind.messageIn);

  void _onIncomingDm(ChatMessage _) => _cue.play(CueKind.dmIn);

  void dispose() {
    _mc.removeListener(_onChange);
    _msgSub?.cancel();
    _dmSub?.cancel();
  }
}
