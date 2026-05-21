// Copyright (c) 2026 IoTone, Inc.
// SPDX-License-Identifier: MIT
import 'dart:convert';
import 'dart:typed_data';

/// Thrown internally by [ByteCursor] on a bounds violation. The public
/// `decode` entry point catches this and turns it into a typed
/// decode-failure value — decoding never throws to callers.
class FrameTruncated implements Exception {
  FrameTruncated(this.needed, this.available, this.context);
  final int needed;
  final int available;
  final String context;

  @override
  String toString() =>
      'FrameTruncated: needed $needed byte(s) for "$context" '
      'but only $available remain';
}

/// Little-endian, bounds-checked sequential reader over a frame.
///
/// All Meshcore multi-byte integers are little-endian (per the pinned
/// `companion_protocol.md`). CayenneLPP (big-endian) is not handled here.
class ByteCursor {
  ByteCursor(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int _pos = 0;

  int get position => _pos;
  int get remaining => _bytes.length - _pos;
  bool get atEnd => _pos >= _bytes.length;

  void _need(int n, String ctx) {
    if (remaining < n) throw FrameTruncated(n, remaining, ctx);
  }

  int u8(String ctx) {
    _need(1, ctx);
    return _bytes[_pos++];
  }

  /// Signed 8-bit (used for the scaled SNR byte in V3 receive frames).
  int i8(String ctx) {
    _need(1, ctx);
    final int v = _bytes[_pos++];
    return v < 128 ? v : v - 256;
  }

  int u16(String ctx) {
    _need(2, ctx);
    final int v = _data.getUint16(_pos, Endian.little);
    _pos += 2;
    return v;
  }

  int u32(String ctx) {
    _need(4, ctx);
    final int v = _data.getUint32(_pos, Endian.little);
    _pos += 4;
    return v;
  }

  /// Signed 32-bit (used for scaled lat/lon, which can be negative).
  int i32(String ctx) {
    _need(4, ctx);
    final int v = _data.getInt32(_pos, Endian.little);
    _pos += 4;
    return v;
  }

  Uint8List bytes(int n, String ctx) {
    _need(n, ctx);
    final Uint8List out = Uint8List.sublistView(_bytes, _pos, _pos + n);
    _pos += n;
    return Uint8List.fromList(out);
  }

  /// Remaining bytes as a UTF-8 string (lenient — invalid sequences
  /// become U+FFFD rather than throwing). Used for trailing name/text.
  String utf8ToEnd(String ctx) {
    final Uint8List rest = bytes(remaining, ctx);
    return utf8.decode(rest, allowMalformed: true);
  }

  /// Fixed-width field decoded as UTF-8, trimmed at the first NUL.
  String fixedCString(int n, String ctx) {
    final Uint8List raw = bytes(n, ctx);
    int end = raw.indexOf(0);
    if (end < 0) end = raw.length;
    return utf8.decode(
      Uint8List.sublistView(raw, 0, end),
      allowMalformed: true,
    );
  }
}

/// Little-endian frame builder.
class FrameBuilder {
  final BytesBuilder _b = BytesBuilder(copy: false);

  void u8(int v) {
    assert(v >= 0 && v <= 0xFF, 'u8 out of range: $v');
    _b.addByte(v & 0xFF);
  }

  void u32(int v) {
    final ByteData d = ByteData(4)..setUint32(0, v, Endian.little);
    _b.add(d.buffer.asUint8List());
  }

  /// Signed 32-bit little-endian (scaled lat/lon).
  void i32(int v) {
    final ByteData d = ByteData(4)..setInt32(0, v, Endian.little);
    _b.add(d.buffer.asUint8List());
  }

  void raw(List<int> v) => _b.add(v);

  /// Append UTF-8 bytes of [s] (no length prefix, no NUL terminator —
  /// the companion protocol delimits trailing strings by frame length).
  void utf8String(String s) => _b.add(utf8.encode(s));

  /// Append [n] zero bytes (reserved fields).
  void zeros(int n) => _b.add(Uint8List(n));

  /// Append exactly [size] bytes: [src] truncated if longer, or
  /// zero-padded on the right if shorter (fixed C-buffer fields like
  /// the 32-byte channel name and 16-byte secret in SET_CHANNEL).
  void fixed(List<int> src, int size) {
    final Uint8List buf = Uint8List(size);
    final int n = src.length < size ? src.length : size;
    buf.setRange(0, n, src);
    _b.add(buf);
  }

  Uint8List build() => _b.toBytes();
}
