# Meshmore SNS — project status

_Snapshot as of v1.0.138+1 (branch `meshmore-sns`)._

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
- **sns-cells** social heat map — time-decayed message density with
  **last-hour counts** on each square; **place echoes** (R54 inferred-
  place ◇ markers with last-hour ×count, edge-pinned when off-frame,
  + a dismissible "Places" list); a **scale stop** chip (Metro ~20 km /
  Region ~300 km / Mesh fit-all) so distant nodes (Seattle, Vancouver
  BC) can be framed instead of edge-pinned.
- Globe, equal-grid (OSM tiles), street map, fabric survey, mesh tree
  (force-directed, hop slider, Flood as first-class), **Fuji-san**
  elevation profile.

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
- **Telemetry sharing** is a permission (Off/Contacts/Anyone per
  base/loc/env); the radio firmware answers other nodes' scans itself
  (`onContactRequest`, contact-only, base is the master gate). For
  "Contacts" mode, the Node detail sheet grants **per-contact telemetry
  permissions** (writes `contact.flags` via ADD_UPDATE_CONTACT) — the
  only lever the app has on the responder side.

**Battery (R16)**
- Voltage → SoC via per-device OCV curve; observed-drain regression +
  rated-capacity cross-check; time-to-empty + confidence; persisted
  voltage history; dedicated Battery screen + dashboard summary.

**Docs (R53) — Docs tab (6th primary view)**
- Offline reader for three sections: **Protocol** (MeshCore companion
  radio protocol), **Firmware** (MeshCore README, matched to the
  connected device's fw version), and **App** (self-authored).
- Offline-first snapshots baked in (`assets/docs/`), refreshed
  opportunistically from GitHub (`meshcore-dev/MeshCore`) and cached
  (SharedPreferences); App section never hits the network.
- Futuristic monospace rendering (tracked-caps headings + accent
  rules); markdown parsed with the `markdown` package, rendered to
  widgets in-app (images → alt text). Fetch seam is injectable/tested.

**Skin system (R55) — design-system foundation**
- A **skin is a bundle**, not just a palette: `MmSkin` = colour
  (`MmTokens`) + `MmType` + `MmShape` (sharp/rounded/**chamfer**) +
  `MmOrnament` (scanlines, corner brackets, hazard-stripe headers),
  resolved per preset via `mmSkinFor` and read through **`context.skin`**
  (high-contrast forces SEELE).
- **Branded component library** (`lib/ui/`): `MmPanel`, `MmSectionHeader`,
  `MmReadout`, `MmStatusPill`, `MmListRow`, `MmScaffold` +
  `SkinChromePainter` (CRT scanlines + L brackets, suppressed under
  reduce-motion). `context.skin` falls back to SEELE when no
  `ThemeController` is above it, so migrating a screen never forces its
  test harness to wire one.
- **Two migration mechanisms, both proven:**
  1. **Per-skin layout fork** (for screens whose *metaphor* differs):
     the Dashboard is hosted by `DashboardHost`, which dispatches the
     **NERV Terminal** telemetry-grid vs the **SEELE monolith** from one
     `DashboardModel` (slot data).
  2. **Component-driven reskin** (one screen, all skins, no fork): the
     **Nodes** view is wrapped in `MmScaffold` and renders rows via
     `MmListRow` (chamfered panel cards + scanline under NERV, flat
     hairline rows under SEELE) — same code, reskinned by bundle.
  Switch live in Personalization. _Slice + first list migration; more
  screens to follow._

**Platform / settings / a11y**
- About → **Open-source licenses & attributions** (`showLicensePage`):
  bundled-asset licenses registered with `LicenseRegistry` — MeshCore
  docs (MIT), GeoNames cities (CC-BY 4.0), Natural Earth (public
  domain), OpenStreetMap (ODbL) — alongside all package licenses.
- Region presets (R39, baked-in), location settings, diagnostics +
  raw-frame log, personalization (themes, font scale, reduce-motion,
  high-contrast), voice/TTS (R5), per-theme audio cues (R12).

## Known constraints & caveats

- Most recent UI/paint changes are **verified by `flutter analyze` +
  the test suite, not a device render** — eyeball on hardware.
- **Environment telemetry is NOT available on the test device's current
  firmware (confirmed 2026-06-03 on hardware).** The T1000-E's BME280
  needs the MeshCore *sensor firmware* build; standard companion firmware
  sends only battery/GPS. Two independent signals confirmed this:
  1. Self-telemetry replies carry an **empty** CayenneLPP payload
     (`[telem] … types=` blank — no `0x67`/`0x68`/`0x73`).
  2. Writing a non-zero **Environment** value in device config
     (`SET_OTHER_PARAMS`) does not stick — the device **clamps the env
     bits back to 0** and echoes a `SelfInfo` with env=0. A firmware
     with the sensor in its telemetry path would accept the class.
  The app's encode (byte position, no clobber of base/loc) and decode
  (env at SelfInfo byte 46) were both verified correct — this is purely
  a device-side limitation, not an app bug. Resolution is to flash a
  MeshCore sensor firmware build; **no app change can surface data the
  radio never emits.** (BME280 also reads a few °C warm — sits by the
  electronics.) Further firmware investigation is the user's to pursue.
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
  trends / history + sparkline) is shelved** — the test device's
  firmware emits no environment telemetry (see constraints above), so
  there is no source to build history on. The decode/poller/WX chain is
  complete and will light up automatically if a sensor-firmware node
  joins the fabric. Re-open Phase 3 only once a node is confirmed
  transmitting `0x67`-class telemetry.
- **Settings toggle contrast** ✅ (v1.0.125+1) — `segmentedButtonTheme`
  + `chipTheme` give selected controls a solid-accent fill app-wide.

## Backlog (flagged, not started)

- **Real per-feature app docs ("online-help-md")** _(noted, not started)._
  The Docs → App section currently points at `assets/docs/app.md`, a
  single **summary** doc. Replace it with proper per-feature help —
  a new `online-help-md` doc set **with screenshots** — documenting each
  feature, not one overview page. Leave `app.md` in place for now; build
  the real docs as a follow-up. (Docs tab now sits **after** Settings.)


- **R54 — message-derived place inference ("place echoes")** — follow-
  ups only. Scans channel banter for place names/coords, region-scoped
  to the known location, and plots ≥80%-confidence ghost markers on the
  SNS grid. **All three sub-tasks shipped:** (a) ballpark placement
  engine (`lib/sns/place_inference.dart`), (b) per-channel toggle in the
  channel-edit dialog (default on for public #1; `PlaceInferencePrefs`),
  (c) `CityLookup` forward name index + `CityGazetteer` adapter +
  `InferredPlaceStore` (TTL/reinforcement) + dashed-◇ markers on the
  sns-cells painter. ~31 SNS tests. **Remaining follow-ups:** tap-a-
  marker → source-snippet/dismiss UI; the X→Y connector line; and the
  optional finer neighbourhood gazetteer (currently city-centre +
  directional offset only). See spec R54.


- **lobospeak** — closed-network robot control plane over MeshCore
  binary req/resp (design doc exists in `meshmore-sns/`). The big one.
- **F2** — map alternatives. **F3** — AI integrations. (Both flagged
  only; need specifics before design.)
- `responsive-iot-2026` generic starter branch — complete & local-only;
  not pushed to origin.
