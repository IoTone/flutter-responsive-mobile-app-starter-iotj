// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
/// Why a frame failed to decode.
///
/// Decoding is **total** (the TC2 invariant): every input yields a
/// [MeshcoreInbound], never an exception. The full taxonomy of decode
/// outcomes is:
///
///  * a typed frame (e.g. `SelfInfoFrame`) — recognised & parsed;
///  * `UnsupportedFrame` — a well-formed frame whose opcode this
///    codec does not model; raw bytes preserved. **Not a failure.**
///  * `DecodeFailure` — the only failure path, with a kind below.
///
/// Hence the only failure kinds are structural: [empty] and
/// [truncated]. An unknown opcode is *not* an error (it becomes an
/// `UnsupportedFrame`), so there is deliberately no
/// `unsupportedOpcode` kind.
enum DecodeErrorKind {
  /// Frame was empty (no opcode byte).
  empty,

  /// Frame ended before a required field could be read.
  truncated,
}

class MeshcoreDecodeError {
  const MeshcoreDecodeError(this.kind, this.message, {this.opcode});

  final DecodeErrorKind kind;
  final String message;

  /// The leading opcode byte, when one was present.
  final int? opcode;

  @override
  String toString() => 'MeshcoreDecodeError(${kind.name}'
      '${opcode != null ? ', op=0x${opcode!.toRadixString(16)}' : ''}): '
      '$message';
}
