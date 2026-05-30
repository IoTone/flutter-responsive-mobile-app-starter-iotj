#!/usr/bin/env bash
# Copyright (c) 2026 IoTone, Inc. — SPDX-License-Identifier: MIT
# Linux WiFi scanner via nmcli → JSON array on stdout (the /aps
# contract). Requires NetworkManager. nmcli SIGNAL is 0–100%, converted
# to a rough dBm.
set -euo pipefail

nmcli -t -f SSID,BSSID,SIGNAL,FREQ,SECURITY dev wifi list --rescan yes \
  2>/dev/null | python3 - <<'PY'
import sys, json

def split_escaped(line):
    # nmcli -t uses ':' as field sep and escapes literal ':' as '\:'.
    parts, cur, i = [], '', 0
    while i < len(line):
        c = line[i]
        if c == '\\' and i + 1 < len(line):
            cur += line[i + 1]; i += 2; continue
        if c == ':':
            parts.append(cur); cur = ''; i += 1; continue
        cur += c; i += 1
    parts.append(cur)
    return parts

out = []
for line in sys.stdin:
    line = line.rstrip('\n')
    if not line:
        continue
    p = split_escaped(line)
    if len(p) < 5:
        continue
    ssid, bssid, signal, freq, security = p[0], p[1], p[2], p[3], p[4]
    try:
        pct = int(signal)
    except ValueError:
        pct = 0
    rssi = int(pct / 2) - 100  # rough percent → dBm
    try:
        mhz = int(freq.split()[0])
    except (ValueError, IndexError):
        mhz = 0
    out.append({"ssid": ssid, "bssid": bssid, "rssi": rssi,
                "freq": mhz, "security": security})

print(json.dumps(out))
PY
