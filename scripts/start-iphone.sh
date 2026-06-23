#!/usr/bin/env bash
set -euo pipefail

export TMPDIR="${TMPDIR:-/tmp}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="$ROOT/mobile"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"

MODE="release"
DEVICE_ID=""
FRESH_INSTALL=false

for arg in "$@"; do
  case "$arg" in
    --dev) MODE="debug" ;;
    --release) MODE="release" ;;
    --fresh) FRESH_INSTALL=true ;;
    *)
      if [ -z "$DEVICE_ID" ]; then
        DEVICE_ID="$arg"
      fi
      ;;
  esac
done

if [ "$MODE" = "debug" ]; then
  echo "==> CarGuard AI — iPhone DEBUG (hot reload, launch via this terminal only)"
  echo ""
  echo "    ⚠️  DEBUG builds CRASH if you tap the home-screen icon."
  echo "    Only launch from this terminal. For normal use, run without --dev."
else
  echo "==> CarGuard AI — iPhone RELEASE (safe to open from home screen)"
fi
echo "    On-device: SQLite + ML Kit — no Mac backend required"
echo ""
echo "    Why first launch sometimes 'crashes':"
echo "    • Debug build + home-screen tap → iOS blocks it (not a real app bug)"
echo "    • Fix: use release (this script default) or launch debug only from terminal"
echo ""
echo "    Trust tips (free Apple ID):"
echo "    • USB 'Trust This Computer' — once per cable/Mac until iOS forgets"
echo "    • Developer cert trust — Settings → General → VPN & Device Management"
echo "    • Free profiles expire every ~7 days — rerun this script, don't use --fresh"
echo "    • Avoid --fresh unless the app won't install (re-trust required after uninstall)"
echo ""

cd "$MOBILE"
"$FLUTTER" pub get

if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID="$("$FLUTTER" devices 2>/dev/null | grep -i 'iphone' | grep -v 'simulator' | head -1 | awk -F '•' '{print $2}' | xargs || true)"
fi

if [ -z "$DEVICE_ID" ]; then
  echo ""
  echo "No physical iPhone detected. Connect via USB, unlock, tap Trust This Computer,"
  echo "and enable Developer Mode: Settings → Privacy & Security → Developer Mode."
  "$FLUTTER" devices
  exit 1
fi

if [ "$FRESH_INSTALL" = true ]; then
  echo "==> Removing old app (you will need to trust developer cert again on phone)..."
  "$FLUTTER" install --uninstall-only -d "$DEVICE_ID" || true
fi

echo "==> Installing on device: $DEVICE_ID"
if [ "$MODE" = "debug" ]; then
  echo "    Hot reload: save .dart files in Cursor or press 'r' in this terminal"
  echo "    Keep phone unlocked. Do NOT open the app from the home screen."
  if ! "$FLUTTER" run -d "$DEVICE_ID"; then
    echo ""
    echo "==> Debug attach failed — installing RELEASE so home-screen icon works..."
    "$FLUTTER" install -d "$DEVICE_ID" --release
    echo "    Done. Open CarGuard AI from your home screen."
  fi
else
  echo "    Building & installing release (home-screen safe)..."
  "$FLUTTER" build ios --release
  "$FLUTTER" install -d "$DEVICE_ID" --release
  echo ""
  echo "    ✓ Installed. Open CarGuard AI from your home screen."
fi
