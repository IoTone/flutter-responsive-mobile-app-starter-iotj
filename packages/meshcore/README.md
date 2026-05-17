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
  meshcore.dart            public API barrel
  src/
    codec/constants.dart   transcribed opcodes / UUIDs / framing (pinned)
    transport/transport.dart  abstract MeshcoreTransport (no BLE here)
test/
  constants_test.dart      pin + opcode + framing assertions
```

Codec, model, crypto, and session layers are added per milestone
(see `meshmore-sns-spec.md` → *Meshcore Protocol Implementation Plan*).

## Test

```sh
dart pub get
dart test
```
