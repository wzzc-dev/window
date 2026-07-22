#!/usr/bin/env bash
set -euo pipefail

PKG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$PKG_ROOT/template"

for path in \
  "$TEMPLATE/Info.plist" \
  "$TEMPLATE/Sources/main.m" \
  "$TEMPLATE/Sources/MBWHostedAppDelegate.h" \
  "$TEMPLATE/Sources/MBWHostedAppDelegate.m"
do
  [[ -f "$path" ]] || {
    echo "missing iOS hosted template file: $path" >&2
    exit 1
  }
done

plutil -lint "$TEMPLATE/Info.plist" >/dev/null
rg -q 'mbw_ios_host_on_surface_init' "$TEMPLATE/Sources/MBWHostedAppDelegate.m"
rg -q 'mbw_ios_start_event_loop' "$TEMPLATE/Sources/MBWHostedAppDelegate.m"
rg -q 'MBWHostedAppDelegate' "$TEMPLATE/Sources/main.m"
rg -q 'APP_DELEGATE=.*Sources/MBWHostedAppDelegate.m' "$PKG_ROOT/scripts/build-hosted-sim-app.sh"

echo "ios hosted template: ok"
