# Simulator Automation

Use `capture_snapshot.sh` to build, install, launch with scripted actions, and grab a screenshot.

## Quick use

```bash
/Users/zachpass/Desktop/Games/Color\ Swap/Krank/Scripts/capture_snapshot.sh
```

## Capture level select screen

```bash
SCREEN=level_select OUT='/tmp/krank_level_select.png' \
/Users/zachpass/Desktop/Games/Color\ Swap/Krank/Scripts/capture_snapshot.sh
```

## With scripted interactions

```bash
LEVEL=1 TOGGLES='A,B,C' OUT='/tmp/krank_after_taps.png' \
/Users/zachpass/Desktop/Games/Color\ Swap/Krank/Scripts/capture_snapshot.sh
```

## Options (env vars)

- `DEVICE_ID` default: first booted simulator
- `SCREEN` `game|level_select` (default: `game`)
- `LEVEL` default: `1` (1-based)
- `TOGGLES` comma-separated switch ids, example: `A,B,C`
- `AUTO_RESET` `0|1`
- `AUTO_NEXT` `0|1`
- `OPEN_SETTINGS` `0|1` (auto-opens settings modal after launch)
- `ACTION_DELAY` default: `0.30`
- `SETTLE_DELAY` default: `1.00`
- `CAPTURE_DELAY` default: `0.80`
- `OUT` default: `/tmp/krank_snapshot.png`
- `SKIP_BUILD` default: `0` (set `1` to skip rebuild/install)

## Notes

- This uses in-app automation arguments to simulate gameplay taps (toggle switches, reset, next).
- Screenshot capture is done with `simctl io screenshot`.
