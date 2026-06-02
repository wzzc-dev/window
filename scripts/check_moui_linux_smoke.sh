#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

fail() {
  printf 'MoUI Linux smoke check failed: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/check_moui_linux_smoke.sh [--run] [--require-input]

Without --run, build and statically verify the Linux MoUI smoke artifact on a
Linux host. With --run, launch the built Wayland executable and require it to
  print the surface, Wayland handles, present, resize, redraw, ready,
  destroyed, and finished sentinel lines. Representative Wayland input is
  logged when supplied by the compositor or operator. Use --require-input, or set
WINDOW_MOUI_LINUX_REQUIRE_INPUT=1, to require pointer and keyboard evidence.
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
  local exe="$1"
  local output_file timeout_sec pid status output
  timeout_sec="${WINDOW_MOUI_LINUX_SMOKE_TIMEOUT_SEC:-15}"
  output_file="$(mktemp "${TMPDIR:-/tmp}/moui-linux-smoke.XXXXXX")"
  set +e
  env WINDOW_MOUI_LINUX_REQUIRE_INPUT="$require_input" \
    "$exe" >"$output_file" 2>&1 &
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
  require_output "$output" "MOUILinuxSmoke: surface"
  require_output "$output" "MOUILinuxSmoke: handles"
  require_output "$output" "MOUILinuxSmoke: present result=0"
  require_output "$output" "MOUILinuxSmoke: monitors"
  require_output "$output" "MOUILinuxSmoke: cursor"
  require_output "$output" "MOUILinuxSmoke: resize"
  require_output "$output" "MOUILinuxSmoke: redraw pre_present_notify"
  require_output "$output" "MOUILinuxSmoke: ready"
  require_output "$output" "MOUILinuxSmoke: destroyed"
  require_output "$output" "MOUILinuxSmoke: finished"
  require_output_order "$output" "MOUILinuxSmoke: destroyed" "MOUILinuxSmoke: finished"
  if [[ "$require_input" == "1" ]]; then
    require_output "$output" "MOUILinuxSmoke: ready input=observed"
  fi
  if [[ "$output" == *"MOUILinuxSmoke: failed"* ]]; then
    fail "runtime reported failure"
  fi
}

run_mode=0
require_input="${WINDOW_MOUI_LINUX_REQUIRE_INPUT:-0}"
for arg in "$@"; do
  case "$arg" in
    --run)
      run_mode=1
      ;;
    --require-input)
      run_mode=1
      require_input=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown argument $arg"
      ;;
  esac
done
if [[ -n "$require_input" && "$require_input" != "0" ]]; then
  require_input=1
else
  require_input=0
fi

actual_host="$(detect_window_actual_host)"
host="$(detect_window_ci_host)"
if [[ "$host" != "linux" ]]; then
  if [[ "$run_mode" == "1" ]]; then
    fail "Linux runtime smoke requires a Linux host; detected $actual_host"
  fi
  printf 'Skipping MoUI Linux smoke check on %s host\n' "$host"
  exit 0
fi

if [[ "$run_mode" == "1" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  printf 'Warning: WAYLAND_DISPLAY is not set; run inside a Wayland session or Weston.\n' >&2
fi

pkg="examples/moui_linux_smoke"
main="$pkg/main.mbt"
manifest="$pkg/moon.pkg"
exe="_build/native/debug/build/examples/moui_linux_smoke/moui_linux_smoke.exe"

moon build "$pkg" --target native >/dev/null

require_file "$main"
require_file "$manifest"
require_file "$exe"
require_text "$manifest" '"native-stub": [ "config_native.c" ]'
require_text "$main" "native_require_input"
require_text "$main" "event_loop.set_control_flow(Wait)"
require_text "$main" "try_create_window_with_linux_attributes"
require_text "$main" "WindowAttributesLinux::default().with_app_id"
require_text "$main" "window.wl_display()"
require_text "$main" "window.wl_surface()"
require_text "$main" "window.xdg_surface()"
require_text "$main" "window.xdg_toplevel()"
require_text "$main" "window.present_rgba_pixels"
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
require_text "$main" "MOUILinuxSmoke: ready"
require_text "$main" "MOUILinuxSmoke: core ready input=required"
require_text "$main" "Destroyed"
require_text "$main" "SurfaceResized"
require_text "$main" "RedrawRequested"

if [[ "$run_mode" == "1" ]]; then
  run_runtime_smoke "$exe"
  if [[ "$require_input" == "1" ]]; then
    printf 'MoUI Linux runtime smoke passed: %s\n' "$exe"
  else
    printf 'MoUI Linux core runtime smoke passed: %s\n' "$exe"
  fi
else
  printf 'MoUI Linux smoke build check passed: %s\n' "$exe"
fi
