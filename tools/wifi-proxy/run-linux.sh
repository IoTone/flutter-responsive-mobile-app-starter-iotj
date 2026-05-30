#!/usr/bin/env bash
# Serve the nmcli scanner. Usage: ./run-linux.sh [port]
set -euo pipefail
cd "$(dirname "$0")"
chmod +x linux/scan.sh
exec python3 serve.py --scan-cmd "./linux/scan.sh" --port "${1:-8765}"
