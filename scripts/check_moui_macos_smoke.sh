#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

fail() {
  printf 'MoUI macOS smoke check failed: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/check_moui_macos_smoke.sh [--run]

Without --run, build and statically verify the macOS MoUI smoke artifact on a
macOS host. With --run, execute the AppKit smoke through moon run and require it to
  print the surface, handle, resize, redraw, pointer, keyboard, ready,
  destroyed, and finished sentinel lines.
EOF
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file $path"
}

require_text() {
  local path="$1"
  local text="$2"
  rg -q --fixed-strings "$text" "$path" ||
    fail "$path does not contain expected text: $text"
}

require_output() {
  local output="$1"
  local text="$2"
  [[ "$output" == *"$text"* ]] ||
    fail "runtime output did not contain expected text: $text"
}

require_output_order() {
  local output="$1"
  local first="$2"
  local second="$3"
  local after_first="${output#*"$first"}"
  if [[ "$after_first" == "$output" || "$after_first" != *"$second"* ]]; then
    fail "runtime output did not contain $first before $second"
  fi
}

run_runtime_smoke() {
  local output_file timeout_sec pid status output
  timeout_sec="${WINDOW_MOUI_MACOS_SMOKE_TIMEOUT_SEC:-15}"
  output_file="$(mktemp "${TMPDIR:-/tmp}/moui-macos-smoke.XXXXXX")"
  set +e
  "$@" >"$output_file" 2>&1 &
  pid=$!
  status=0
  for ((i = 0; i < timeout_sec * 10; i += 1)); do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid"
      status=$?
      break
    fi
    sleep 0.1
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    set -e
    printf '%s\n' "$(cat "$output_file")"
    rm -f "$output_file"
    fail "runtime smoke timed out after ${timeout_sec}s"
  fi
  set -e
  output="$(cat "$output_file")"
  rm -f "$output_file"
  printf '%s\n' "$output"
  [[ "$status" -eq 0 ]] || fail "runtime exited with status $status"
  require_output "$output" "MOUIMacSmoke: surface"
  require_output "$output" "MOUIMacSmoke: handles"
  require_output "$output" "MOUIMacSmoke: monitors"
  require_output "$output" "MOUIMacSmoke: cursor"
  require_output "$output" "MOUIMacSmoke: resize"
  require_output "$output" "MOUIMacSmoke: redraw pre_present_notify"
  require_output "$output" "MOUIMacSmoke: pointer"
  require_output "$output" "MOUIMacSmoke: keyboard"
  require_output "$output" "MOUIMacSmoke: ready"
  require_output "$output" "MOUIMacSmoke: destroyed"
  require_output "$output" "MOUIMacSmoke: finished"
  require_output_order "$output" "MOUIMacSmoke: destroyed" "MOUIMacSmoke: finished"
  if [[ "$output" == *"MOUIMacSmoke: failed"* ]]; then
    fail "runtime reported failure"
  fi
}

run_mode=0
case "${1:-}" in
  "")
    ;;
  --run)
    run_mode=1
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    fail "unknown argument $1"
    ;;
esac

actual_host="$(detect_window_actual_host)"
host="$(detect_window_ci_host)"
if [[ "$host" != "macos" ]]; then
  if [[ "$run_mode" == "1" ]]; then
    fail "macOS runtime smoke requires a macOS host; detected $actual_host"
  fi
  printf 'Skipping MoUI macOS smoke check on %s host\n' "$host"
  exit 0
fi

pkg="examples/moui_macos_smoke"
main="$pkg/main.mbt"
manifest="$pkg/moon.pkg"
stub="$pkg/input_native.m"
run_command=(moon run "$pkg" --target native)

moon build "$pkg" --target native >/dev/null

require_file "$main"
require_file "$manifest"
require_file "$stub"
require_text "$manifest" '"native-stub": [ "input_native.m" ]'
require_text "$manifest" '"cc-link-flags": "-framework AppKit -framework Foundation -lobjc"'
require_text "$stub" "mbw_moui_macos_smoke_send_input"
require_text "$main" "window.content_view_handle()"
require_text "$main" "window.window_handle()"
require_text "$main" "window.surface_size()"
require_text "$main" "window.scale_factor()"
require_text "$main" "window.available_monitors()"
require_text "$main" "window.primary_monitor()"
require_text "$main" "window.current_monitor()"
require_text "$main" "window.set_cursor_icon(Text)"
require_text "$main" "window.cursor()"
require_text "$main" "window.pre_present_notify()"
require_text "$main" "PointerMoved"
require_text "$main" "KeyboardInput"
require_text "$main" "MOUIMacSmoke: ready"
require_text "$main" "Destroyed"
require_text "$main" "SurfaceResized"
require_text "$main" "RedrawRequested"

if [[ "$run_mode" == "1" ]]; then
  run_runtime_smoke "${run_command[@]}"
  printf 'MoUI macOS runtime smoke passed: %s\n' "${run_command[*]}"
else
  printf 'MoUI macOS smoke build check passed: %s\n' "$pkg"
fi
