# meshcore (Dart)

Pure-Dart implementation of the **Meshcore companion-radio protocol**:
framing, codec, models, crypto, and session logic. **No Flutter
dependencies** — the conformance suite runs under `dart test` with no
device or emulator. The Flutter app depends on this package by path and
supplies the concrete BLE transport.

## Source of truth (pinned)

All opcodes, frame layouts, and crypto parameters are transcribed from
the MeshCore firmware repository, pinned to:

| | |
|---|---|
| Tag | `companion-v1.15.0` |
| Commit | `dee3e26ac081a5c668c69b66c16a6544a44ddc5b` |
| Spec file | `docs/companion_protocol.md` |

[Pinned protocol doc](https://github.com/meshcore-dev/MeshCore/blob/dee3e26ac081a5c668c69b66c16a6544a44ddc5b/docs/companion_protocol.md)

The pin is also asserted in `lib/src/codec/constants.dart` and tested.
**Bump it deliberately** (update the constants header, this table, the
CHANGELOG, and re-verify every value), never silently.

### Reference hardware

On-device validation (milestones M5/M6) targets a Flutter **Android**
host plus **Seeed Studio T1000-E** nodes flashed via
<https://meshcore.co.uk/flasher.html>. The flashed T1000-E firmware
version must match the pinned tag above; record it here when the
hardware is set up:

- T1000-E flashed firmware: _TBD (record on first hardware bring-up)_

## Layout

```
lib/
  meshcore.dart               public API barrel
  src/
    codec/constants.dart      transcribed opcodes / UUIDs / framing (pinned)
    codec/byte_cursor.dart    bounds-checked LE read/build primitives
    codec/frame_codec.dart    command encoders + total decode()
    codec/inbound.dart        sealed MeshcoreInbound frame hierarchy
    codec/decode_error.dart   typed decode-failure model
    crypto/channel_crypto.dart  AES-128-ECB + HMAC-SHA256 MAC + channel hash
    model/self_info.dart      SELF_INFO (0x05)
    model/contact.dart        CONTACT (0x03)
    model/channel_message.dart  CHANNEL_MSG_RECV (0x08 / 0x11 V3)
    model/channel_info.dart   CHANNEL_INFO (0x12) + MSG_SENT (0x06)
    transport/transport.dart  abstract MeshcoreTransport (no BLE here)
test/
  constants_test.dart         pin + opcode + framing assertions
  frame_codec_test.dart       M1 vector goldens + programmatic + totality
  channel_codec_test.dart     M2 channel vector goldens + programmatic
  channel_crypto_test.dart    crypto KATs (NIST/RFC) + composition
  vectors/m1_frames.json      M1 conformance vectors
  vectors/m2_channel_frames.json  M2 conformance vectors
```

Implemented: M0 (scaffold/pin/CI), M1 (framing + core codec), **M2**
(channel messaging — send/get/set channel, RX legacy+V3, MSG_SENT —
and the MeshCore channel cipher: AES-128-ECB + truncated HMAC-SHA256
MAC + channel hash, KAT-verified). Contacts/DM crypto, radio config,
and the BLE transport land in later milestones (see
`meshmore-sns-spec.md` → *Meshcore Protocol Implementation Plan*).

> Crypto note: this package uses **pointycastle** (raw AES-ECB +
> sync/deterministic pure Dart), superseding the earlier
> `package:cryptography` choice. The channel secret's upper 16 bytes
> are not carried on the companion link — `channelSecretFromPsk`
> zero-fills them provisionally pending an on-device interop fixture
> (M6).

## Test

```sh
dart pub get
dart test
```
