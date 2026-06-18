#!/usr/bin/env bash
# Android dev — emulator or USB device, hot reload, no backend.
set -euo pipefail

export TMPDIR="${TMPDIR:-/tmp}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="$ROOT/mobile"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"

echo "═══════════════════════════════════════"
echo "  CarGuard AI — Android (on-device AI)"
echo "═══════════════════════════════════════"

cd "$MOBILE"
"$FLUTTER" pub get

DEVICE_ID="$("$FLUTTER" devices 2>/dev/null | grep -E 'android|emulator' | grep -v 'wireless' | head -1 | awk -F '•' '{print $2}' | xargs || true)"

if [ -z "$DEVICE_ID" ]; then
  echo "→ No Android device — starting emulator…"
  "$FLUTTER" emulators --launch Medium_Phone_API_36.1 || true
  for _ in $(seq 1 40); do
    DEVICE_ID="$("$FLUTTER" devices 2>/dev/null | grep emulator | head -1 | awk -F '•' '{print $2}' | xargs || true)"
    [ -n "$DEVICE_ID" ] && break
    sleep 3
  done
fi

if [ -z "$DEVICE_ID" ]; then
  echo "No Android emulator/device found. Open Android Studio → Device Manager, or plug in a phone with USB debugging."
  exit 1
fi

echo ""
echo "→ Android debug session ($DEVICE_ID)"
echo "  Hot reload: save any .dart file"
echo "  Camera + gallery work on emulator (extended controls → Camera)"
echo ""
exec "$FLUTTER" run -d "$DEVICE_ID"
