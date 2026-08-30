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
Usage: scripts/check_moui_linux_smoke.sh [--run] [--require-input] [--require-data-device]

Without --run, build and statically verify the Linux MoUI smoke artifact on a
Linux host. With --run, launch the built Wayland executable and require it to
  print the surface, Wayland handles, present, resize, redraw, ready,
  destroyed, and finished sentinel lines. Representative Wayland input is
  logged when supplied by the compositor or operator. Use --require-input, or set
WINDOW_MOUI_LINUX_REQUIRE_INPUT=1, to require pointer and keyboard evidence.
Use --require-data-device, or set WINDOW_MOUI_LINUX_REQUIRE_DATA_DEVICE=1, to
require Wayland clipboard selection and drag/drop capability evidence.
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

run_runtime_verifier() {
  local output_file="$1"
  local monitor_args=()
  if [[ "$require_current_monitor" != "1" ]]; then
    monitor_args=(--linux-monitor pending-ok)
  fi
  if [[ "$require_input" == "1" ]]; then
    bash scripts/check_moui_runtime_log.sh "${monitor_args[@]}" \
      linux "$output_file" >/dev/null
  else
    bash scripts/check_moui_runtime_log.sh --linux-input pending-ok \
      "${monitor_args[@]}" linux "$output_file" >/dev/null
  fi
}

run_runtime_smoke() {
  local exe="$1"
  local output_file timeout_sec pid status
  timeout_sec="${WINDOW_MOUI_LINUX_SMOKE_TIMEOUT_SEC:-15}"
  output_file="$(mktemp "${TMPDIR:-/tmp}/moui-linux-smoke.XXXXXX")"
  trap 'rm -f "${output_file:-}"' EXIT
  set +e
  env WINDOW_MOUI_LINUX_REQUIRE_INPUT="$require_input" \
    WINDOW_MOUI_LINUX_REQUIRE_DATA_DEVICE="$require_data_device" \
    WINDOW_MOUI_LINUX_REQUIRE_CURRENT_MONITOR="$require_current_monitor" \
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
    fail "runtime smoke timed out after ${timeout_sec}s"
  fi
  set -e
  cat "$output_file"
  [[ "$status" -eq 0 ]] || fail "runtime exited with status $status"
  run_runtime_verifier "$output_file"
  if [[ "$require_data_device" == "1" ]]; then
    require_text "$output_file" "MOUILinuxSmoke: data-device clipboard=true clipboard_roundtrip=true drag_drop=true require=true"
  fi
  rm -f "$output_file"
  trap - EXIT
}

run_mode=0
require_input="${WINDOW_MOUI_LINUX_REQUIRE_INPUT:-0}"
require_data_device="${WINDOW_MOUI_LINUX_REQUIRE_DATA_DEVICE:-0}"
# Default 1 (strict). Set to 0 only on compositors that never deliver
# wl_surface.enter, i.e. the WSLg Weston RDP backend (ADR 0032).
require_current_monitor="${WINDOW_MOUI_LINUX_REQUIRE_CURRENT_MONITOR:-1}"
for arg in "$@"; do
  case "$arg" in
    --run)
      run_mode=1
      ;;
    --require-input)
      run_mode=1
      require_input=1
      ;;
    --require-data-device)
      run_mode=1
      require_data_device=1
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
if [[ -n "$require_data_device" && "$require_data_device" != "0" ]]; then
  require_data_device=1
else
  require_data_device=0
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

pkg="modules/window/examples/moui_linux_smoke"
main="$pkg/main.mbt"
manifest="$pkg/moon.pkg"
exe="_build/native/debug/build/wzzc-dev/window/examples/moui_linux_smoke/moui_linux_smoke.exe"

moon build "$pkg" --target native >/dev/null

if [[ ! -f "$exe" && -f "$workspace_exe" ]]; then
  exe="$workspace_exe"
fi

require_file "$main"
require_file "$manifest"
require_file "$exe"
require_text "$manifest" '"native-stub": [ "config_native.c" ]'
require_text "$main" "native_require_input"
require_text "$main" "native_require_data_device"
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
require_text "$main" "monitor.native_id()"
require_text "$main" "primary_id=0x"
require_text "$main" "current_id=0x"
require_text "$main" "self.saw_monitor = log_monitor_probe"
require_text "$main" "self.require_current_monitor"
require_text "$main" "native_require_current_monitor"
require_text "$main" "window.set_cursor_icon(Text)"
require_text "$main" "window.cursor()"
require_text "$main" "self.saw_cursor = log_cursor_probe(window)"
require_text "$main" "cursor=\{self.saw_cursor}"
require_text "$main" "window.request_ime_update(Enable(enable))"
require_text "$main" "window.request_ime_update(Update(update_data))"
require_text "$main" "window.request_ime_update(Disable)"
require_text "$main" "window.ime_capabilities()"
require_text "$main" "window.ime_hints()"
require_text "$main" "window.ime_purpose()"
require_text "$main" "with_hint_and_purpose"
require_text "$main" "window.ime_surrounding_text()"
require_text "$main" "window.ime_cursor_area_position()"
require_text "$main" "window.ime_cursor_area_size()"
require_text "$main" "MOUILinuxSmoke: ime probe enabled=\{enabled} hint="
require_text "$main" "updated_hint=\{updated_hint_ok}"
require_text "$main" "@linux.clipboard_available()"
require_text "$main" "@linux.write_clipboard_text"
require_text "$main" "@linux.read_clipboard_text()"
require_text "$main" "@linux.drag_drop_available()"
require_text "$main" "MOUILinuxSmoke: data-device clipboard="
require_text "$main" "self.saw_data_device_probe = log_data_device_probe"
require_text "$main" "window.pre_present_notify()"
require_text "$main" "PointerMoved"
require_text "$main" "KeyboardInput"
require_text "$main" "key_event.text()"
require_text "$main" "MOUILinuxSmoke: keyboard text="
require_text "$main" "MOUILinuxSmoke: ready"
require_text "$main" "window.drop()"
require_text "$main" "MOUILinuxSmoke: destroy requested"
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
