#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../mobile"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"
DEVICE="${1:-chrome}"
"$FLUTTER" pub get
if [ "$DEVICE" = "chrome" ]; then
  exec "$FLUTTER" run -d chrome --web-port=3000
else
  exec "$FLUTTER" run -d "$DEVICE"
fi
