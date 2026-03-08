#!/usr/bin/env bash
set -euo pipefail

DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
PROJECT="/Users/zachpass/Desktop/Games/Color Swap/Krank/Krank.xcodeproj"
SCHEME="Krank"
BUNDLE_ID="otinv.Krank"
DERIVED_DATA="/tmp/krank-derived"

DEVICE_ID="${DEVICE_ID:-booted}"
SCREEN="${SCREEN:-game}"
LEVEL="${LEVEL:-1}"
TOGGLES="${TOGGLES:-}"
AUTO_RESET="${AUTO_RESET:-0}"
AUTO_NEXT="${AUTO_NEXT:-0}"
OPEN_SETTINGS="${OPEN_SETTINGS:-0}"
ACTION_DELAY="${ACTION_DELAY:-0.30}"
SETTLE_DELAY="${SETTLE_DELAY:-1.00}"
CAPTURE_DELAY="${CAPTURE_DELAY:-0.80}"
OUT="${OUT:-/tmp/krank_snapshot.png}"
SKIP_BUILD="${SKIP_BUILD:-0}"

export DEVELOPER_DIR

if [[ "$DEVICE_ID" == "booted" ]]; then
  DEVICE_ID="$(xcrun simctl list devices | sed -n 's/.*(\([0-9A-F-]\{36\}\)) (Booted).*/\1/p' | head -n1)"
  if [[ -z "$DEVICE_ID" ]]; then
    echo "No booted simulator found. Boot one in Xcode first." >&2
    exit 1
  fi
fi

if [[ "$SKIP_BUILD" != "1" ]]; then
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "id=$DEVICE_ID" -derivedDataPath "$DERIVED_DATA" build >/tmp/krank_build.log
fi

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Krank.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH" >/tmp/krank_install.log

args=()
if [[ "$SCREEN" == "level_select" ]]; then
  args+=("--auto-level-select-only")
else
  args+=("--auto-play" "--auto-level=$LEVEL" "--auto-delay=$ACTION_DELAY" "--auto-settle=$SETTLE_DELAY")
  if [[ -n "$TOGGLES" ]]; then
    args+=("--auto-toggle=$TOGGLES")
  fi
  if [[ "$AUTO_RESET" == "1" ]]; then
    args+=("--auto-reset")
  fi
  if [[ "$AUTO_NEXT" == "1" ]]; then
    args+=("--auto-next")
  fi
  if [[ "$OPEN_SETTINGS" == "1" ]]; then
    args+=("--auto-open-settings")
  fi
fi

xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" "${args[@]}" >/tmp/krank_launch.log

python3 - <<PY
import time
delay = float("$CAPTURE_DELAY")
if "$SCREEN" != "level_select":
    delay += float("$SETTLE_DELAY")
    delay += float("$ACTION_DELAY") * (len("$TOGGLES".split(",")) if "$TOGGLES" else 0)
time.sleep(delay)
PY

mkdir -p "$(dirname "$OUT")"
xcrun simctl io "$DEVICE_ID" screenshot "$OUT" >/tmp/krank_screenshot.log

echo "Saved snapshot: $OUT"
echo "Device: $DEVICE_ID"
echo "Screen: $SCREEN"
echo "Launch args: ${args[*]}"
