# Responsive IoT 2026

A clean **Flutter starter for Bluetooth LE & WiFi device scanning** — a
"forensic scanner" you can build on. It ships a working app: scan for
nearby BLE devices and WiFi access points, plot them on a signal radar,
inspect details, and connect to BLE devices over GATT. No backend, no
accounts, offline-first.

> Package: `responsive_iot_2026` · bundle id `io.iotone.responsiveiot2026`
> · MIT licensed.

## Features

- **Dashboard** — live scan summary (BLE / WiFi counts, radio state) and
  a single Start/Stop control.
- **Radar** — a radial scope placing devices by signal strength (weaker =
  further out) at a stable per-id bearing, with an animated sweep
  (honours reduce-motion). BLE = dot, WiFi = diamond. Tap to inspect.
- **Devices** — unified list (BLE + WiFi), sorted by RSSI, with a
  per-platform WiFi notice.
- **Device detail** — identifiers, vendor (from the BT company id), live
  signal, advertised services, and a **GATT connect** that discovers
  services/characteristics.
- **Settings** — theme presets, text size, reduce-motion / high-contrast,
  language (English + 日本語), permissions, an RSSI **signal floor**, and
  About.
- **Diagnostics** — a rolling scan-event log with copy-to-clipboard.
- **First-run** onboarding with permission rationale.

## Architecture

Everything scan-related lives under [`lib/scanner/`](lib/scanner) and is
injected, so the controller is fully unit-testable without hardware:

| Piece | Role |
| --- | --- |
| `ScannerController` | `ChangeNotifier` (Provider). Fuses BLE + WiFi, exposes devices/APs/counts/scan state, GATT connection, and a diagnostics log. |
| `BleScanner` / `FlutterBlueScanner` | BLE scan + connect abstraction over `flutter_blue_plus`. Swap in `FakeBleScanner` for tests. |
| `WifiSource` | Pluggable WiFi: `OnDeviceWifiSource` (Android full scan), `ConnectedNetworkSource` (iOS connected-only), `NoopWifiSource`. |
| `SignalDistance` | RSSI → rough distance / radar radial fraction / band. |
| `VendorLookup` | Small offline BT company-id → vendor table (extend it). |

UI is `provider` + `go_router`; theming is a token-based dark theme with
swappable presets; localization uses the standard ARB + `gen-l10n`
pipeline (`lib/l10n/`).

## Platform notes (important)

- **WiFi scanning is asymmetric by OS design:**
  - **Android** does a full nearby-AP scan (`wifi_scan`), but the OS
    **throttles** scans (~4 per 2 min on many devices), so results
    refresh slowly. Requires location permission.
  - **iOS** has **no third-party AP-scanning API** — only the
    *currently-connected* network is visible (`network_info_plus`), and
    no RSSI is exposed. This is an Apple restriction, not a bug. To scan
    nearby WiFi on iOS, use the optional relay proxy (below).
- **Android permissions:** BLE scan/connect + location (+ `NEARBY_WIFI_DEVICES`
  on API 33+). **iOS:** Bluetooth + location usage strings are set.

## Optional: WiFi relay proxy (mDNS)

To get real nearby-WiFi scanning on iOS, run the companion proxy in
[`tools/wifi-proxy/`](../tools/wifi-proxy) on a **Mac or Linux** box on
the same network. It scans WiFi locally and serves the results over a
small JSON endpoint advertised via Bonjour/mDNS; the app discovers it and
shows the APs as if they were local. See that folder's README. (Caveat:
the proxy scans the *proxy's* RF vicinity, not the phone's.)

## Run

```sh
flutter pub get
flutter gen-l10n      # regenerate localizations after editing lib/l10n/*.arb
flutter run
```

## Test

```sh
flutter test
flutter analyze
```

Unit tests cover the controller (BLE ingest, RSSI floor, connection
lifecycle), the signal math, the models, and the vendor lookup.

## Extending

- Add vendors to `VendorLookup` from the Bluetooth SIG assigned numbers.
- Add a new `WifiSource` (e.g. the relay proxy) and call
  `ScannerController.setWifiSource(...)`.
- Add a theme preset in `lib/theme/tokens.dart`.
- Add screens as new `go_router` routes in `lib/app_router.dart`.
