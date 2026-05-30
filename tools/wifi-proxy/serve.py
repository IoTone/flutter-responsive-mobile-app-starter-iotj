#!/usr/bin/env python3
# Copyright (c) 2026 IoTone, Inc. — SPDX-License-Identifier: MIT
"""WiFi relay proxy server.

Serves `GET /aps` as a JSON array of access points (see README contract)
by running a platform scan command, and advertises itself over mDNS so
the Responsive IoT 2026 app can discover it as `_iotscan._tcp`.
"""
import argparse
import json
import shutil
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

SERVICE_TYPE = "_iotscan._tcp"


def make_handler(scan_cmd):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            if self.path.rstrip("/") != "/aps":
                self.send_response(404)
                self.end_headers()
                return
            try:
                out = subprocess.check_output(scan_cmd, shell=True, timeout=25)
                json.loads(out)  # validate it's JSON
                body = out
            except Exception as exc:  # noqa: BLE001
                sys.stderr.write(f"scan failed: {exc}\n")
                body = b"[]"
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body if isinstance(body, bytes) else body.encode())

    return Handler


def advertise(port):
    if shutil.which("dns-sd"):
        return subprocess.Popen(
            ["dns-sd", "-R", "IoT WiFi Proxy", SERVICE_TYPE, "local", str(port)]
        )
    if shutil.which("avahi-publish-service"):
        return subprocess.Popen(
            ["avahi-publish-service", "IoT WiFi Proxy", SERVICE_TYPE, str(port)]
        )
    sys.stderr.write(
        f"No dns-sd/avahi-publish found — advertise {SERVICE_TYPE} on "
        f"port {port} manually.\n"
    )
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--scan-cmd", required=True,
                    help="shell command printing the /aps JSON array")
    ap.add_argument("--port", type=int, default=8765)
    args = ap.parse_args()

    adv = advertise(args.port)
    srv = HTTPServer(("0.0.0.0", args.port), make_handler(args.scan_cmd))
    print(f"Serving /aps on :{args.port}, advertising {SERVICE_TYPE}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if adv:
            adv.terminate()


if __name__ == "__main__":
    main()
