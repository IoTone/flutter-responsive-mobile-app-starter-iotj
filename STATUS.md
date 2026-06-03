# Meshmore SNS — project status

_Snapshot as of v1.0.122+1 (branch `meshmore-sns`)._

An offline-first Flutter companion app for MeshCore LoRa mesh radios
over BLE. Mesh-first, no backend. Sibling branch `responsive-iot-2026`
holds a de-branded generic BLE/WiFi scanner starter derived from this
codebase.

## Architecture

- **`MeshcoreController`** (`lib/meshcore/`) — the Provider-exposed
  facade over the BLE link + MeshCore companion protocol. Owns nodes,
  chat/DM, channels, telemetry, battery, location, delivery tracking.
  Transport is injectable, so the whole controller is `flutter test`-
  covered with a fake (~296 app-wide tests).
- **`packages/meshcore`** — pure-Dart protocol codec (frames/opcodes,
  CayenneLPP, channel/identity crypto). No Flutter deps.
- UI: `provider` + `go_router`; token-based themes; ARB + `gen-l10n`
  localization (EN + JA, in lock-step).

## Feature inventory

**Connection & shell**
- BLE scan / pair / connect, auto-reconnect (backoff), background
  keep-alive (Android FGS), reconnect on resume.
- Dashboard (R8): peers-in-range, radio/location readouts, battery
  readout (taps → Battery screen), recent activity, **tappable device
  rename** (R52) with re-advertise + SelfInfo refresh.

**Chat (R6/R20)**
- Channel + DM chat; per-message **delivery status** (sending → sent →
  delivered / failed), handling the firmware's ACK-before-SENT ordering.
- Channel sender attribution via the "name: " text prefix.
- Channels: name + PSK, **#hashtag-derived** public channels (SHA256),
  hex PSK, shake-to-derive; QR share.

**Nodes / fabric**
- Nodes list with proximity badges, DM counts, tags (R28), favorites,
  per-row **temperature chip** when telemetry is present.
- Node detail sheet: identity, signal, hops (Direct / N-via / **Flood**
  / unknown), per-node telemetry (altitude + **temp/humidity/pressure**),
  on-tap telemetry query (contacts only).

**Hyperlocal grid (R18/R25/R27) — 9 view modes**
- **Radial "radar"** — range rings (Room…Wide…**City…Region**, Region
  auto-frames the known extent), signal/bearing placement, compass rose
  + heading needle, **north-up/heading-up toggle**, prominent top
  **heading HUD**.
- **Weather (WX)** — environment telemetry at a glance: summary band
  (nodes reporting + min/avg/max temperature on a cold→hot ramp) + a
  warmest-first list of reporting nodes with temp/humidity/pressure +
  freshness; tap → node detail.
- Globe, equal-grid (OSM tiles), street map, fabric survey, mesh tree
  (force-directed, hop slider, Flood as first-class), sns-cells social
  heat map, **Fuji-san** elevation profile.

**Telemetry & sensors**
- Self + peer telemetry via `CMD_SEND_TELEMETRY_REQ` / `0x8B`.
- Decodes GPS (alt) + **environment (temperature/humidity/pressure)**;
  surfaced in node detail, Nodes rows, the Fuji-san self chip, and the
  Weather view.
- **Background telemetry poller** (opt-in, App settings → "Gather node
  telemetry", default on): politely cycles synced contacts (one req per
  ~10 s, hop/distance-tiered, 3 attempts/contact, 15-min refresh, then
  quiet). Off = no telemetry traffic from us.
- Self-telemetry zero-prefix replies normalized to our own key; a
  `[telem]` diag log dumps received LPP types.
- Fuji-san polls **self** telemetry on load / on UPDATE (+ a phone-GPS
  one-shot so altitude resolves even when the device omits GPS alt).

**Battery (R16)**
- Voltage → SoC via per-device OCV curve; observed-drain regression +
  rated-capacity cross-check; time-to-empty + confidence; persisted
  voltage history; dedicated Battery screen + dashboard summary.

**Platform / settings / a11y**
- Region presets (R39, baked-in), location settings, diagnostics +
  raw-frame log, personalization (themes, font scale, reduce-motion,
  high-contrast), voice/TTS (R5), per-theme audio cues (R12).

## Known constraints & caveats

- Most recent UI/paint changes are **verified by `flutter analyze` +
  the test suite, not a device render** — eyeball on hardware.
- **Environment/altitude telemetry depends on device firmware emitting
  it.** The T1000-E's BME280 needs the MeshCore *sensor firmware* build
  to be reported; standard companion firmware often sends only
  battery/GPS. The `[telem]` log confirms what a node actually sends.
  BME280 reads a few degrees warm (sits by the electronics).
- Peer telemetry is **contact-only** (firmware drops requests for
  advert-only nodes); the background poller respects that.
- **The whole temperature chain (poller → decode → Weather view) is
  unverified on hardware** — it only shows data if a node's firmware
  actually transmits environment telemetry. Confirm via the WX view /
  `[telem]` logs before relying on it.
- The PUSH_CODE_ACK (0x82) wire format isn't in firmware docs we hold;
  decoded as the documented u32 tag, degrades to "sent" if a device
  differs.

## In progress / next

- **Telemetry & weather thrust:** Phase 1 (background poller) ✅ and
  Phase 2 (Weather view) ✅ shipped. **Phase 3 (per-node temperature
  trends / history + sparkline) is paused** until temperature is
  confirmed flowing on hardware — building history on an unverified
  source is premature. Fallback if temp isn't sent: a sensor-firmware
  detection/hint instead.

## Backlog (flagged, not started)

- **lobospeak** — closed-network robot control plane over MeshCore
  binary req/resp (design doc exists in `meshmore-sns/`). The big one.
- **F2** — map alternatives. **F3** — AI integrations. (Both flagged
  only; need specifics before design.)
- `responsive-iot-2026` generic starter branch — complete & local-only;
  not pushed to origin.
