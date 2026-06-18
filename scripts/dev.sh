#!/usr/bin/env bash
# Flutter-only dev session — no Mac backend required.
set -euo pipefail

export TMPDIR="${TMPDIR:-/tmp}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="$ROOT/mobile"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"

echo "═══════════════════════════════════════"
echo "  CarGuard AI — On-device (no backend)"
echo "═══════════════════════════════════════"

cd "$MOBILE"
"$FLUTTER" pub get

DEVICE_ID="$("$FLUTTER" devices 2>/dev/null | grep -i 'iphone' | grep -v simulator | head -1 | awk -F '•' '{print $2}' | xargs || true)"

echo ""
echo "  Hot reload: save any .dart file in Cursor"
echo "  All data + AI runs on the phone — no Mac server needed"
echo ""
echo "  Keep this terminal open. Ctrl+C to stop Flutter."
echo ""

if [ -n "$DEVICE_ID" ]; then
  echo "→ iPhone debug session ($DEVICE_ID)"
  echo "  App launches from here — don't open from home screen icon."
  exec "$FLUTTER" run -d "$DEVICE_ID"
else
  echo "→ No iPhone detected — using macOS"
  exec "$FLUTTER" run -d macos
fi
