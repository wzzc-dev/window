#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

usage() {
  cat <<'EOF'
Usage: scripts/smoke_runtime.sh <backend>

Backends:
  macos    Run the macOS native window example on a macOS host.
  web      Verify Web assets, then serve the browser smoke page.
  linux    Run the Linux native Wayland example on a Linux host.
  windows  Run the Windows native Win32 example on a Windows host.

Set WINDOW_RUNTIME_SMOKE_DRY_RUN=1 to print the command and checklist without
launching the runtime.
EOF
}

fail() {
  printf 'Runtime smoke failed: %s\n' "$1" >&2
  exit 1
}

require_backend_host() {
  local backend="$1"
  local actual_host
  actual_host="$(detect_window_actual_host)"
  if [[ "$actual_host" != "$backend" ]]; then
    fail "$backend runtime smoke requires a $backend host; detected $actual_host"
  fi
}

print_checklist() {
  local backend="$1"
  cat <<EOF
Runtime smoke checklist for $backend:
- window/page opens
- resize or redraw event is observed
- representative input event is observed
- runtime exits cleanly
EOF
}

run_or_print() {
  local label="$1"
  shift
  printf 'Command:'
  printf ' %q' "$@"
  printf '\n'
  if [[ "${WINDOW_RUNTIME_SMOKE_DRY_RUN:-0}" == "1" ]]; then
    printf 'Dry run only; command not launched: %s\n' "$label"
  else
    "$@"
  fi
}

backend="${1:-}"
case "$backend" in
  -h|--help|"")
    usage
    exit 0
    ;;
  macos)
    require_backend_host macos
    print_checklist macos
    run_or_print macOS moon run examples/window --target native
    ;;
  web)
    if [[ "${WINDOW_RUNTIME_SMOKE_SKIP_WEB_ASSETS:-0}" == "1" ]]; then
      printf 'Skipping Web asset smoke before runtime dry run\n'
    else
      scripts/check_web_assets.sh
    fi
    print_checklist web
    printf 'Open http://127.0.0.1:8000/examples/window_web/index.html\n'
    run_or_print web node examples/window_web/serve.mjs
    ;;
  linux)
    require_backend_host linux
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
      printf 'Warning: WAYLAND_DISPLAY is not set; run inside a Wayland session or Weston.\n' >&2
    fi
    print_checklist linux
    run_or_print Linux moon run examples/window_linux --target native
    ;;
  windows)
    require_backend_host windows
    print_checklist windows
    run_or_print Windows moon run examples/window_windows --target native
    ;;
  *)
    usage >&2
    fail "unknown backend $backend"
    ;;
esac
