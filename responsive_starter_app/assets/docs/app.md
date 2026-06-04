# Meshmore SNS

An **offline-first companion app** for MeshCore LoRa mesh radios, paired
over Bluetooth Low Energy. No accounts, no servers, no internet
dependency — everything you see is read straight off the mesh through
your connected device.

> This page ships inside the app. The **Protocol** and **Firmware** docs
> next to it are snapshots of the upstream MeshCore documentation, cached
> for offline reading and refreshed from GitHub when you're online.

## What it does

Meshmore SNS turns a MeshCore companion radio into a social, glanceable
network you can actually see and feel:

- **Dashboard** — peers in range, radio + location readouts, a battery
  estimate, and recent mesh activity at a glance. Tap your name to
  rename the device (it re-advertises on the mesh).
- **Chat** — channel chat and direct messages, each with a delivery
  status (sending → sent → delivered / failed). Channels can be plain
  name+PSK, `#hashtag`-derived public channels, hex-PSK, or shake-to-
  derive, and shared by QR.
- **Nodes** — every node you've heard, with proximity badges, message
  counts, tags, and favourites. Tap any node for identity, signal, hop
  path, and telemetry.
- **Hyperlocal grid** — nine ways to see the fabric around you,
  including a radial "radar" with range rings and a heading HUD, a
  globe, OSM map tiles, a force-directed mesh tree, and a weather (WX)
  view of environment telemetry.
- **Battery** — a real state-of-charge estimate from the radio's
  voltage, with a time-to-empty projection.

## How it works

- **`MeshcoreController`** is the heart of the app: it owns the BLE
  link and speaks the MeshCore **companion radio protocol** (see the
  Protocol doc). It tracks nodes, chats, channels, telemetry, battery,
  and location, and exposes them to the UI.
- The protocol codec is a **pure-Dart package** with no Flutter
  dependencies, so the whole stack is unit-tested against a fake
  transport.
- The UI is Flutter, with a swipe-between-views shell, a light/dark
  set of "futuristic" themes, and full English + Japanese localisation.

## Offline-first by design

Region radio presets, device power profiles, the world map outline,
and these docs are **baked into the app** so it works with no
connectivity. The only network traffic is opportunistic: OSM map tiles
and refreshing these documentation snapshots when you happen to be
online. Your mesh data never leaves your device.

## Telemetry & sensors

The app requests and decodes telemetry from your own radio and from
contacts: GPS altitude and **environment readings** (temperature,
humidity, pressure) when the device's firmware provides them.

> **Note:** environment readings only appear if the radio's firmware
> build includes an environment sensor in its telemetry path. Many
> stock companion builds report only battery and GPS. The Firmware doc
> and the device's telemetry mode tell you what your hardware emits.

## Privacy

Meshmore SNS has no backend and collects nothing. Identities, channel
keys, message history, and tags live only in your phone's local
storage. Sharing happens over the radio, on your terms.

---

_Meshmore SNS — IoTone, Inc. Licensed MIT. Built with Flutter._
