# Changelog

## 0.0.1 — M0 (scaffold)

- Pure-Dart package scaffold, Flutter-free.
- Firmware source-of-truth pinned: tag `companion-v1.15.0`,
  commit `dee3e26ac081a5c668c69b66c16a6544a44ddc5b`.
- Seeded `constants.dart` from the pinned `docs/companion_protocol.md`:
  BLE service/characteristic UUIDs, framing rules, core command and
  response/push opcodes, SNR-byte conversion.
- Abstract `MeshcoreTransport` interface (BLE impl lives in the app).
- Conformance harness bootstrapped (`dart test`).
