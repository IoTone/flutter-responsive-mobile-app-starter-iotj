# Changelog

## 0.0.3 — M2 (channel messaging + channel AES)

- Dependency: **pointycastle** added. MeshCore needs raw AES-128-ECB
  (which `package:cryptography` deliberately omits) and a conformance
  library wants sync/deterministic/pure-Dart primitives. Supersedes the
  earlier `cryptography` choice for this package (see spec → Risks).
- Channel/cipher constants from `src/MeshCore.h` / `src/Mesh.h`:
  `kCipherKeySize` 16, `kCipherBlockSize` 16, `kCipherMacSize` 2,
  `kChannelSecretSize` 32 (`GroupChannel.secret` = PUB_KEY_SIZE),
  `kChannelPskSize` 16 (companion-carried), `kTxtTypePlain`,
  `kPathLenFlood` 0xFF.
- Encoders: `sendChannelTextMessage`, `getChannel`, `setChannel`
  (50-byte fixed frame). Decoders: `RESP_CODE_SENT` (0x06),
  `CHANNEL_MSG_RECV` (0x08) + V3 (0x11, SNR), `CHANNEL_INFO` (0x12).
  New frames: `MsgSentFrame`, `ChannelMessageFrame`, `ChannelInfoFrame`;
  models `ChannelMessage`, `ChannelInfo`, `MsgSent`.
- `MeshcoreChannelCrypto`: faithful port of `Utils::encrypt/decrypt/
  encryptThenMAC/MACThenDecrypt` + channel hash — AES-128-ECB
  (zero-padded final block), HMAC-SHA256 truncated to 2 bytes keyed
  over the full 32-byte secret, `channelHash = SHA256(secret)[0]`.
  `channelSecretFromPsk` zero-fills the upper 16 bytes (PROVISIONAL —
  not carried on the companion link; confirm via M6 interop fixture).
- Conformance: `vectors/m2_channel_frames.json` + programmatic
  SET_CHANNEL/CHANNEL_INFO goldens + totality tests; crypto KATs
  anchored to published vectors (NIST AES-128-ECB, SHA-256 "abc",
  RFC 4231 HMAC-SHA256 case 2) plus encryptThenMac composition /
  round-trip / tamper-rejection. 57 tests green.

## 0.0.2 — M1 (framing + core codec)

- Added source-verified commands from `MyMesh.cpp` (pinned commit):
  `CMD_GET_CONTACTS` (0x04), `CMD_GET_DEVICE_TIME` (0x05),
  `CMD_SET_DEVICE_TIME` (0x06); renamed 0x0A to `syncNextMessage`
  (`CMD_SYNC_NEXT_MESSAGE`). Added field-size constants
  (`kPubKeySize`, `kMaxPathSize`, `kContactNameSize`).
- `ByteCursor` / `FrameBuilder`: bounds-checked little-endian
  read/build primitives.
- Encoders: `appStart`, `getContacts`, `getDeviceTime`,
  `setDeviceTime`, `syncNextMessage`.
- Total decoder `MeshcoreFrameCodec.decode` (never throws): OK, ERROR,
  CONTACTS_START, CONTACT (148B), END_OF_CONTACTS, SELF_INFO,
  CURR_TIME, NO_MORE_MESSAGES; sealed `MeshcoreInbound` hierarchy;
  `UnsupportedFrame` preserves unknown opcodes; `DecodeFailure` for
  empty/truncated input.
- Models: `SelfInfo`, `Contact` (with `activePath`).
- Conformance suite: JSON vector goldens
  (`test/vectors/m1_frames.json`) for encode/decode, programmatic
  SELF_INFO/CONTACT goldens with full-field + frame-length assertions,
  and totality (empty/truncated) tests. 28 tests green.

## 0.0.1 — M0 (scaffold)

- Pure-Dart package scaffold, Flutter-free.
- Firmware source-of-truth pinned: tag `companion-v1.15.0`,
  commit `dee3e26ac081a5c668c69b66c16a6544a44ddc5b`.
- Seeded `constants.dart` from the pinned `docs/companion_protocol.md`:
  BLE service/characteristic UUIDs, framing rules, core command and
  response/push opcodes, SNR-byte conversion.
- Abstract `MeshcoreTransport` interface (BLE impl lives in the app).
- Conformance harness bootstrapped (`dart test`).
