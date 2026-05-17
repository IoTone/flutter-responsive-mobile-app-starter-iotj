# Changelog

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
