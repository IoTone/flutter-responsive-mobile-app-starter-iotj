#!/usr/bin/env bash
# Build the CoreWLAN scanner and serve it. Usage: ./run-macos.sh [port]
set -euo pipefail
cd "$(dirname "$0")"
swiftc macos/scan.swift -o macos/scan-bin
exec python3 serve.py --scan-cmd "./macos/scan-bin" --port "${1:-8765}"
