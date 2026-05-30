// Copyright (c) 2026 IoTone, Inc. — SPDX-License-Identifier: MIT
// macOS WiFi scanner via CoreWLAN → JSON array on stdout (the /aps
// contract). Build: swiftc scan.swift -o scan-bin
//
// macOS 14+ requires Location Services for the running process or the
// BSSID is redacted (nil). The legacy `airport -s` CLI was retired in
// Sonoma 14.4, so CoreWLAN is the only path.
import Foundation
import CoreWLAN

func channelToMHz(_ ch: Int, band: CWChannelBand) -> Int {
    switch band {
    case .band2GHz: return ch == 14 ? 2484 : 2407 + ch * 5
    case .band5GHz: return 5000 + ch * 5
    default: return 5950 + ch * 5 // 6 GHz (approx)
    }
}

let client = CWWiFiClient.shared()
guard let iface = client.interface() else {
    print("[]")
    exit(0)
}

var out: [[String: Any]] = []
do {
    let networks = try iface.scanForNetworks(withName: nil)
    for n in networks {
        var freq = 0
        if let wch = n.wlanChannel {
            freq = channelToMHz(wch.channelNumber, band: wch.channelBand)
        }
        out.append([
            "ssid": n.ssid ?? "",
            "bssid": n.bssid ?? "",
            "rssi": n.rssiValue,
            "freq": freq,
            "security": "",
        ])
    }
} catch {
    FileHandle.standardError.write("scan error: \(error)\n".data(using: .utf8)!)
}

let data = try JSONSerialization.data(withJSONObject: out)
print(String(data: data, encoding: .utf8) ?? "[]")
