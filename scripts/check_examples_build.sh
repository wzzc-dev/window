#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WINDOW_ROOT="$ROOT/modules/window"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

host="$(detect_window_ci_host)"

while IFS= read -r pkg; do
  example="${pkg%/moon.pkg}"
  name="$(basename "$example")"
  target="native"
  case "$host" in
    linux|windows)
      # Generic examples import the macOS backend package, whose native stubs
      # only compile on Darwin; restrict non-Darwin hosts to the examples that
      # match or are host-agnostic.
      case "$name" in
        window_linux|moui_linux_smoke|x11_embed)
          [[ "$host" == "linux" ]] || { echo "Skipping $name on $host host"; continue; }
          ;;
        window_windows|moui_windows_smoke)
          [[ "$host" == "windows" ]] || { echo "Skipping $name on $host host"; continue; }
          ;;
        window_web|moui_web_smoke)
          target="wasm-gc"
          ;;
        mobile_hosted_smoke)
          echo "Skipping $name on $host host (mobile native stubs need a Darwin host)"
          continue
          ;;
        *)
          echo "Skipping $name on $host host (imports the macOS backend)"
          continue
          ;;
      esac
      ;;
  esac
  if rg -q '"is-main"[[:space:]]*:[[:space:]]*true' "$pkg"; then
    moon run --build-only "$example" --target "$target"
  fi
done < <(find "$WINDOW_ROOT/examples" -name moon.pkg -maxdepth 2 -print | sort)
