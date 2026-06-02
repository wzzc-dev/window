#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'MoUI readiness check failed: %s\n' "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file $path"
}

require_executable() {
  local path="$1"
  require_file "$path"
  [[ -x "$path" ]] || fail "$path is not executable"
}

require_text() {
  local path="$1"
  local text="$2"
  rg -q --fixed-strings -- "$text" "$path" ||
    fail "$path does not mention expected text: $text"
}

reject_text() {
  local path="$1"
  local text="$2"
  if rg -q --fixed-strings -- "$text" "$path"; then
    fail "$path contains forbidden text: $text"
  fi
}

for path in \
  docs/moui-integration-smoke.md \
  docs/platform-gaps.md \
  docs/testing.md \
  README.mbt.md \
  examples/moui_macos_smoke/main.mbt \
  examples/moui_web_smoke/index.html \
  examples/moui_web_smoke/main.mbt \
  examples/moui_linux_smoke/main.mbt \
  examples/moui_linux_smoke/config_native.c \
  examples/moui_windows_smoke/main.mbt \
  examples/moui_windows_smoke/input_native.c \
  scripts/check_moui_macos_smoke.sh \
  scripts/check_moui_web_smoke.sh \
  scripts/check_moui_linux_smoke.sh \
  scripts/check_moui_windows_smoke.sh \
  scripts/record_moui_evidence.sh \
  scripts/smoke_runtime.sh
do
  require_file "$path"
done

for path in \
  scripts/check_moui_macos_smoke.sh \
  scripts/check_moui_web_smoke.sh \
  scripts/check_moui_linux_smoke.sh \
  scripts/check_moui_windows_smoke.sh \
  scripts/record_moui_evidence.sh \
  scripts/smoke_runtime.sh
do
  require_executable "$path"
done

require_text docs/platform-gaps.md "| macOS | Passed"
require_text docs/platform-gaps.md "| Web | Passed"
require_text docs/platform-gaps.md "| Linux | Pending matching Linux host"
require_text docs/platform-gaps.md "| Windows | Pending matching Windows host"
require_text docs/platform-gaps.md 'Treat `Pending` as missing evidence'
require_text docs/platform-gaps.md "MoUI-ready only after its build smoke and runtime smoke have both been observed"
reject_text docs/platform-gaps.md "| Linux | Passed"
reject_text docs/platform-gaps.md "| Windows | Passed"

require_text docs/moui-integration-smoke.md "Do not mark a backend runtime smoke as passed unless"
require_text docs/moui-integration-smoke.md "WINDOW_MOUI_LINUX_REQUIRE_INPUT=1"
require_text docs/moui-integration-smoke.md "Window::content_view_handle()"
require_text docs/moui-integration-smoke.md "Window::canvas_id()"
require_text docs/moui-integration-smoke.md "keyboard text or IME commit text"
require_text docs/moui-integration-smoke.md "monitor/current-monitor probes"
require_text docs/moui-integration-smoke.md "cursor state"
require_text docs/moui-integration-smoke.md "cursor Icon(Text)"
require_text docs/moui-integration-smoke.md "present_rgba_pixels"
require_text docs/moui-integration-smoke.md "Win32 keyboard, mouse, and IME delivery"
require_text docs/moui-integration-smoke.md "Destroyed"
require_text docs/moui-integration-smoke.md "scripts/record_moui_evidence.sh <backend>"
require_text docs/moui-integration-smoke.md "Copyable recorder commands"
require_text docs/moui-integration-smoke.md "--host \"Linux Wayland/Weston CI\""
require_text docs/moui-integration-smoke.md "--host \"Windows Win32 CI\""
require_text docs/moui-integration-smoke.md "--consumer-command \"scripts/check_moui_macos_smoke.sh --run\""
require_text docs/moui-integration-smoke.md "browser http://127.0.0.1:8000/examples/moui_web_smoke/index.html"

require_text scripts/check_moui_web_smoke.sh "canvas_id=moui-web-smoke-canvas size=640x360"
require_text scripts/check_moui_web_smoke.sh "MOUISmoke: pointer x=24 y=32"
require_text scripts/check_moui_web_smoke.sh "MOUISmoke: keyboard text=a"
require_text examples/moui_web_smoke/index.html "requiredEvidence"
require_text examples/moui_web_smoke/index.html "MOUISmoke: surface canvas_id=moui-web-smoke-canvas size=640x360"
require_text examples/moui_web_smoke/index.html "MOUISmoke: pointer x=24 y=32"
require_text examples/moui_web_smoke/index.html "MOUISmoke: keyboard text=a"

require_text scripts/check_moui_macos_smoke.sh "window.available_monitors()"
require_text scripts/check_moui_macos_smoke.sh "window.current_monitor()"
require_text scripts/check_moui_macos_smoke.sh "window.set_cursor_icon(Text)"
require_text examples/moui_macos_smoke/main.mbt "MOUIMacSmoke: monitors"
require_text examples/moui_macos_smoke/main.mbt "MOUIMacSmoke: cursor"

require_text scripts/check_moui_linux_smoke.sh "MoUI Linux core runtime smoke passed"
require_text scripts/check_moui_linux_smoke.sh "MoUI Linux runtime smoke passed"
require_text scripts/check_moui_linux_smoke.sh "--require-input"
require_text scripts/check_moui_linux_smoke.sh "WINDOW_MOUI_LINUX_REQUIRE_INPUT"
require_text scripts/check_moui_linux_smoke.sh "require_output_order"
require_text scripts/check_moui_linux_smoke.sh "window.available_monitors()"
require_text scripts/check_moui_linux_smoke.sh "window.current_monitor()"
require_text scripts/check_moui_linux_smoke.sh "window.set_cursor_icon(Text)"
require_text examples/moui_linux_smoke/main.mbt "MOUILinuxSmoke: ready input=pending"
require_text examples/moui_linux_smoke/main.mbt "MOUILinuxSmoke: ready input=observed"
require_text examples/moui_linux_smoke/main.mbt "MOUILinuxSmoke: monitors"
require_text examples/moui_linux_smoke/main.mbt "MOUILinuxSmoke: cursor"
require_text examples/moui_linux_smoke/main.mbt "event_loop.set_control_flow(Wait)"
require_text examples/moui_linux_smoke/main.mbt "Destroyed"

require_text scripts/check_moui_windows_smoke.sh "MOUIWindowsSmoke: ime text=a"
require_text scripts/check_moui_macos_smoke.sh "require_output_order"
require_text scripts/check_moui_windows_smoke.sh "require_output_order"
require_text scripts/check_moui_windows_smoke.sh "window.available_monitors()"
require_text scripts/check_moui_windows_smoke.sh "window.current_monitor()"
require_text scripts/check_moui_windows_smoke.sh "window.set_cursor_icon(Text)"
require_text examples/moui_windows_smoke/main.mbt "Ime(Commit(text))"
require_text examples/moui_windows_smoke/main.mbt "MOUIWindowsSmoke: monitors"
require_text examples/moui_windows_smoke/main.mbt "MOUIWindowsSmoke: cursor"
require_text examples/moui_windows_smoke/input_native.c "WM_CHAR"
require_text examples/moui_windows_smoke/main.mbt "Destroyed"

require_text scripts/smoke_runtime.sh "Automated Linux MoUI core smoke"
require_text scripts/smoke_runtime.sh "Automated Windows MoUI smoke"
require_text scripts/smoke_runtime.sh "scripts/check_moui_web_smoke.sh"
require_text scripts/smoke_runtime.sh "examples/moui_web_smoke/index.html for MoUI consumer evidence"
require_text scripts/record_moui_evidence.sh "prints to stdout only"
require_text scripts/record_moui_evidence.sh "native-backend evidence must be generated on the matching host"
require_text scripts/record_moui_evidence.sh "Use --host to name the remote matching host"
require_text scripts/record_moui_evidence.sh 'requires explicit `yes` values'
require_text scripts/record_moui_evidence.sh "--consumer-input"
require_text scripts/record_moui_evidence.sh "--text-input"
require_text scripts/record_moui_evidence.sh "--monitor-cursor"
require_text scripts/record_moui_evidence.sh "consumer evidence fields require --consumer-command"
require_text scripts/record_moui_evidence.sh "change backend status"
require_text scripts/check_moui_evidence.sh "documented Web recorder template"
require_text scripts/check_moui_evidence.sh "documented Linux pending recorder template"
require_text scripts/check_moui_evidence.sh "documented Windows pending recorder template"
require_text docs/testing.md "Smoke Matrix"
require_text docs/testing.md "scripts/record_moui_evidence.sh <backend>"
require_text docs/testing.md "--host \"Linux Weston CI\""
require_text docs/platform-gaps.md "scripts/record_moui_evidence.sh <backend>"
require_text docs/platform-gaps.md 'pass `--host` with the'
require_text docs/platform-gaps.md 'matching host description so the entry cannot be confused with local smoke'
require_text README.mbt.md "docs/moui-integration-smoke.md"
require_text README.mbt.md "scripts/record_moui_evidence.sh"

printf 'MoUI readiness check passed\n'
