#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

example_backend() {
  local pkg="$1"
  if rg -q '"wzzc-dev/window/web"' "$pkg"; then
    printf 'web\n'
  elif rg -q '"wzzc-dev/window/macos"' "$pkg"; then
    printf 'macos\n'
  elif rg -q '"wzzc-dev/window/linux"' "$pkg"; then
    printf 'linux\n'
  elif rg -q '"wzzc-dev/window/windows"' "$pkg"; then
    printf 'windows\n'
  else
    printf 'native\n'
  fi
}

host="$(detect_window_ci_host)"

while IFS= read -r pkg; do
  example="${pkg%/moon.pkg}"
  if rg -q '"is-main"[[:space:]]*:[[:space:]]*true' "$pkg"; then
    backend="$(example_backend "$pkg")"
    case "$backend" in
      web)
        moon build "$example" --target wasm-gc
        ;;
      native)
        moon run --build-only "$example" --target native
        ;;
      "$host")
        moon run --build-only "$example" --target native
        ;;
      *)
        echo "Skipping $example: $backend example on $host host"
        ;;
    esac
  fi
done < <(find examples -maxdepth 2 -name moon.pkg -print | sort)
