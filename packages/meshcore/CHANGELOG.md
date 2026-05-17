# Changelog

## 0.0.6 — M4 (device / radio configuration, R7)

Layouts from `examples/companion_radio/MyMesh.cpp` at the pin.

- Commands: `setRadioParams` (0x0B, freq/bw ×1000 + SF/CR + optional
  repeat), `setRadioTxPower` (0x0C, int8 dBm), `setAdvertLatLon`
  (0x0E, lat/lon ×1e6 + optional alt), `setOtherParams` (0x26),
  `setTuningParams` (0x15, ×1000), `deviceQuery` (0x16,
  app_target_ver), `getBatteryStorage` (0x14).
- Decoders: `RESP_CODE_DEVICE_INFO` (0x0D, 82-byte: fw/limits/BLE
  PIN/build/manufacturer/version/flags; on-wire `max_contacts/2`
  doubled back) and `RESP_CODE_BATT_AND_STORAGE` (0x0C).
- Models `RadioParams`/`DeviceInfo`/`BatteryStorage`; frames
  `DeviceInfoFrame`/`BatteryStorageFrame`.
- Conformance: `vectors/m4_config_frames.json` (encode incl. negative
  int8 TX power, scaled freq/bw/tuning; battery decode) + programmatic
  DEVICE_INFO golden + totality + a SET_RADIO_PARAMS↔SELF_INFO
  scale round-trip. 97 tests green. Satisfies R7 protocol surface.

## 0.0.5 — M3b (Ed25519 verify + ed25519_key_exchange + DM crypto)

Crypto half of M3. Completes M3.

- Dependency: **cryptography** added for ASYMMETRIC primitives
  (pure-Dart `DartEd25519`/`DartX25519`; pointycastle 3.9.x ships no
  Ed25519/X25519). pointycastle stays for symmetric (AES-ECB/HMAC/
  SHA). Two libs, split by capability — neither covers both.
- `MeshcoreIdentityCrypto`: Ed25519 `verifySignature`/`verifyAdvert`;
  `edPublicKeyToMontgomeryU` (pure-Dart BigInt `(1+y)/(1-y) mod p`);
  `ed25519KeyExchange` (orlp/ed25519 composition: clamp(prv64[0:32])
  scalar + Montgomery-u of peer pub → X25519, raw output);
  `expandedPrivateKeyFromSeed` (orlp `SHA512(seed)`+clamp),
  `ed25519PublicKeyFromSeed`.
- `MeshcoreDmCrypto`: derive 32-byte ECDH secret + DM payload
  encrypt/decrypt delegating to the M2 `encryptThenMac`/
  `macThenDecrypt`. DM has NO open tail question (full 32-byte
  secret).
- Conformance: RFC 8032 §7.1 Ed25519-verify KATs (+tamper), RFC 7748
  §5.2 X25519 KAT, and **offline libsodium-generated** KATs
  (`vectors/m3b_x25519_kat.json`, via pynacl) anchoring the ed→u
  conversion + full key-exchange + DH symmetry; DM round-trip;
  end-to-end advert verify with a real signature. 81 tests green.
- Open item unchanged: exact-bytes match to a *real MeshCore device*
  is the M6 interop fixture; libsodium oracle gives high confidence
  (standard birational map + X25519; libsodium is the reference).

## 0.0.4 — M3a (DM/contact/advert codec + public-channel constants)

Codec half of M3 (the Ed25519/ECDH crypto half is M3b). All layouts
transcribed from `MyMesh.cpp` / `Mesh.cpp` / `AdvertDataHelpers.h` at
the pin.

- Commands: `sendTextMessage` (0x02), `sendSelfAdvert` (0x07),
  `setAdvertName` (0x08), `addUpdateContact` (0x09, 148-byte frame).
- Decoders: `CONTACT_MSG_RECV` (0x07) + V3 (0x10) incl. the signed
  variant (`txt_type==2` → 4-byte signature prefix); `ADVERTISEMENT`
  push (0x80) → pubkey/ts/sig + app_data (flags, latlon, feat1/2,
  name) and the exact Ed25519 `signedMessage`
  (`pub_key ‖ ts ‖ app_data`).
- New frames `ContactMessageFrame`/`AdvertFrame`; models
  `ContactMessage`/`Advert`. `Contact` now stores raw signed
  micro-degrees (`latitudeMicros`/`longitudeMicros`, double getters)
  so a decoded contact re-encodes byte-exactly.
- Constants: 6-byte pubkey prefix, signed-msg type, advert
  type/flag masks (`AdvertDataHelpers.h`), and the **sourced public
  channel** (`docs/qr_codes.md`): `kPublicChannelName="Public"`,
  `kPublicChannelPsk=8b3387e9c5cdea6ac9e5edbaa115cd72` — resolves the
  M2 "no public constants" gap (no fabrication; cited).
- Conformance: `vectors/m3_contact_advert_frames.json` + programmatic
  ADD_UPDATE_CONTACT round-trip (shared 148B layout) + ADVERT golden
  (incl. signedMessage) + totality + public-channel/channel-hash
  oracle. 70 tests green.

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
