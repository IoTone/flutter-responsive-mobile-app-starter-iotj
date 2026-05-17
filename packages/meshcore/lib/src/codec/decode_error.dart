/// Why a frame failed to decode. Decoding is total: malformed input
/// yields a [DecodeFailure] value, never an exception.
enum DecodeErrorKind {
  /// Frame was empty (no opcode byte).
  empty,

  /// Frame ended before a required field could be read.
  truncated,

  /// Opcode is not one this codec milestone decodes yet.
  unsupportedOpcode,
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
