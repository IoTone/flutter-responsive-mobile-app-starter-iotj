# WiFi relay proxy

A tiny companion that lets the app scan **nearby WiFi on iOS**, where
Apple gives third-party apps no AP-scanning API. Run it on a **Mac or
Linux** box on the same network: it scans WiFi locally, serves the
result as JSON over HTTP, and advertises itself via Bonjour/mDNS. The
app discovers it (`Settings → Scanner → WiFi relay proxy`) and shows the
APs as if they were local.

> **Caveat:** the proxy reports the *proxy's* RF vicinity, not the
> phone's. It's ideal for a co-located bench/desk setup, not mobile
> recon.

## Contract

- **Bonjour/mDNS service:** type `_iotscan._tcp`, on the HTTP port.
- **HTTP:** `GET /aps` → a JSON array of access points:

  ```json
  [{"ssid":"home","bssid":"a1:b2:..","rssi":-54,"freq":5180,"security":"WPA2"}]
  ```
  `rssi` is dBm (int), `freq` is the centre frequency in MHz (the app
  derives the channel + band). `ssid`/`security` may be empty.

Any device that serves this contract works — the Mac/Linux scripts here
are just reference implementations.

## Run

**macOS** (needs Xcode command-line tools for `swiftc`):
```sh
./run-macos.sh            # builds the CoreWLAN scanner, serves :8765
```
macOS 14+ **requires Location Services** for the scanning process or the
BSSID comes back blank — grant it to your terminal app under
System Settings → Privacy & Security → Location Services. (Note: Apple
retired the old `airport -s` CLI in Sonoma 14.4, so this uses CoreWLAN.)

**Linux** (needs NetworkManager / `nmcli`):
```sh
./run-linux.sh            # serves :8765 using nmcli
```
`iw dev <iface> scan` is an alternative if you don't run NetworkManager.

Then in the app: enable **WiFi relay proxy** in Scanner settings and
start a scan. On iOS you'll get a one-time **Local Network** permission
prompt (declared via `NSBonjourServices` / `NSLocalNetworkUsageDescription`).

## Advertising

`serve.py` auto-advertises using `dns-sd` (macOS, built in) or
`avahi-publish-service` (Linux, `avahi-utils`). If neither is present it
prints a note; advertise `_iotscan._tcp` on the chosen port yourself,
e.g. `dns-sd -R "IoT WiFi Proxy" _iotscan._tcp local 8765`.
