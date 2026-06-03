#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'Documentation smoke check failed: %s\n' "$1" >&2
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

for path in \
  README.mbt.md \
  docs/moui-integration-smoke.md \
  docs/upstream.md \
  docs/testing.md \
  docs/platform-gaps.md \
  docs/ffi-export-allowlist.txt \
  docs/ffi-linux-export-allowlist.txt \
  docs/ffi-windows-export-allowlist.txt \
  docs/ffi-native-wrapper-allowlist.txt \
  scripts/check_ci.sh \
  scripts/check_ci_host.sh \
  scripts/check_runtime_smoke.sh \
  scripts/check_moui_runtime_log.sh \
  scripts/capture_moui_runtime_evidence.sh \
  scripts/check_moui_readiness.sh \
  scripts/check_moui_evidence.sh \
  scripts/check_moon_baseline.sh \
  scripts/record_moui_evidence.sh \
  scripts/check_moui_macos_smoke.sh \
  scripts/check_moui_linux_smoke.sh \
  scripts/check_moui_windows_smoke.sh \
  scripts/check_web_assets.sh \
  scripts/check_moui_web_smoke.sh \
  scripts/smoke_runtime.sh
do
  require_file "$path"
done

for path in \
  scripts/check_ci.sh \
  scripts/check_ci_host.sh \
  scripts/check_runtime_smoke.sh \
  scripts/check_moui_runtime_log.sh \
  scripts/capture_moui_runtime_evidence.sh \
  scripts/check_moui_readiness.sh \
  scripts/check_moui_evidence.sh \
  scripts/check_moon_baseline.sh \
  scripts/record_moui_evidence.sh \
  scripts/check_moui_macos_smoke.sh \
  scripts/check_moui_linux_smoke.sh \
  scripts/check_moui_windows_smoke.sh \
  scripts/check_web_assets.sh \
  scripts/check_moui_web_smoke.sh \
  scripts/smoke_runtime.sh
do
  require_executable "$path"
done

require_text README.mbt.md "docs/platform-gaps.md"
require_text README.mbt.md "docs/moui-integration-smoke.md"
require_text README.mbt.md "bash scripts/check_ci.sh"
require_text README.mbt.md "scripts/check_moon_baseline.sh"
require_text README.mbt.md "scripts/check_moui_macos_smoke.sh"
require_text README.mbt.md "scripts/check_moui_linux_smoke.sh"
require_text README.mbt.md "WINDOW_MOUI_LINUX_REQUIRE_INPUT=1"
require_text README.mbt.md "scripts/check_moui_windows_smoke.sh"
require_text README.mbt.md "scripts/check_moui_web_smoke.sh"
require_text README.mbt.md "scripts/check_moui_runtime_log.sh linux <captured-log>"
require_text README.mbt.md "scripts/check_moui_runtime_log.sh windows <captured-log>"
require_text README.mbt.md "bash scripts/capture_moui_runtime_evidence.sh linux --log"
require_text README.mbt.md "bash scripts/capture_moui_runtime_evidence.sh windows --log"
require_text README.mbt.md "the MoUI consumer page URL"
require_text README.mbt.md "bash scripts/record_moui_evidence.sh"
require_text README.mbt.md "--window-opened yes"
require_text README.mbt.md "--consumer-input yes"
require_text README.mbt.md "--text-input yes"
require_text README.mbt.md "--monitor-cursor yes"
require_text README.mbt.md "--runtime-log yes"
require_text README.mbt.md "--runtime-log-command"
require_text README.mbt.md "--consumer-command"
require_text README.mbt.md "scripts/smoke_runtime.sh macos"
require_text README.mbt.md "WINDOW_RUNTIME_SMOKE_DRY_RUN=1"
require_text README.mbt.md "Dry-run mode can be used on any host"

require_text docs/upstream.md "Current Migration Scope"
require_text docs/upstream.md 'Web backend on the `wasm-gc` target'
require_text docs/upstream.md "Windows preview backend"
require_text docs/upstream.md "Linux preview backend"
require_text docs/upstream.md "docs/platform-gaps.md"
if rg -q --fixed-strings "Only the macOS backend is implemented." docs/upstream.md; then
  fail "docs/upstream.md still contains stale macOS-only backend wording"
fi

require_text docs/testing.md "scripts/check_ci_host.sh"
require_text docs/testing.md "scripts/check_runtime_smoke.sh"
require_text docs/testing.md "scripts/check_moui_runtime_log.sh"
require_text docs/testing.md "bash scripts/capture_moui_runtime_evidence.sh"
require_text docs/testing.md "scripts/check_moui_readiness.sh"
require_text docs/testing.md "scripts/check_moui_evidence.sh"
require_text docs/testing.md "scripts/check_moon_baseline.sh"
require_text docs/testing.md "bash scripts/record_moui_evidence.sh"
require_text docs/testing.md "copyable recorder templates"
require_text docs/testing.md '`--input`, and `--clean-exit`'
require_text docs/testing.md "--consumer-input yes"
require_text docs/testing.md '`--consumer-command` with the'
require_text docs/testing.md "moon fmt --check"
require_text docs/testing.md "bare moon test"
require_text docs/testing.md "moon check --target all --warn-list +73"
require_text docs/testing.md "scripts/check_web_assets.sh"
require_text docs/testing.md "scripts/check_moui_macos_smoke.sh"
require_text docs/testing.md "scripts/check_moui_linux_smoke.sh"
require_text docs/testing.md "WINDOW_MOUI_LINUX_REQUIRE_INPUT=1"
require_text docs/testing.md "scripts/check_moui_windows_smoke.sh"
require_text docs/testing.md "scripts/check_moui_web_smoke.sh"
require_text docs/testing.md "scripts/check_ffi_surface.sh"
require_text docs/testing.md "native export allowlists for macOS,"
require_text docs/testing.md 'requires `destroyed` before `finished`'
require_text docs/testing.md "monitor/current-monitor probes"
require_text docs/testing.md "cursor state"
require_text docs/testing.md "public IME enable/update/disable state probes"
require_text docs/testing.md 'Wayland `wl_output` monitor/current-monitor probes including'
require_text docs/testing.md '`current=true` from surface enter/current-output tracking'
require_text docs/testing.md '`primary_id=0x...`/`current_id=0x...` native monitor ids'
require_text docs/testing.md "surface enter/current-output tracking"
require_text docs/testing.md "HINSTANCE/raw display handle probes"
require_text docs/testing.md "raw display/window identity"
require_text docs/testing.md "Linux event bridge whitebox tests"
require_text docs/testing.md "Wayland configure normalization"
require_text docs/testing.md "keyboard text and modifier family"
require_text docs/testing.md "release semantics"
require_text docs/testing.md "Windows event bridge whitebox tests"
require_text docs/testing.md "WM_DPICHANGED"
require_text docs/testing.md 'invalid `WM_CHAR` code-unit suppression'
require_text docs/testing.md "sync-query handle"
require_text docs/testing.md "gating without requiring a live Win32 GUI"
require_text docs/testing.md "Windows monitor whitebox tests"
require_text docs/testing.md "monitor size/scale normalization"
require_text docs/testing.md "zero-DPI window scale fallback"
require_text docs/testing.md "monitor name conversion returns an empty name"
require_text docs/testing.md "missing raw-id state, and message-window destroy clear"
require_text docs/testing.md "partial loads are released and cleared"
require_text docs/testing.md "Wayland IME/preedit delivery"
require_text docs/testing.md 'monitor/current-monitor probes including `current=true`'
require_text docs/testing.md "moui-web-smoke-canvas"
require_text docs/testing.md 'pointer `24,32`'
require_text docs/testing.md "examples/moui_web_smoke/index.html"
require_text docs/testing.md "scripts/smoke_runtime.sh <backend>"
require_text docs/testing.md "mode can be used on any host"
require_text docs/testing.md "Non-dry-run native runtime"
require_text docs/testing.md "sample-log coverage through"
require_text docs/testing.md "teardown-order failures"
require_text docs/testing.md 'nonzero `current_id`'
require_text docs/testing.md "nonzero Linux Wayland/XDG handles"
require_text docs/testing.md "positive surface size/scale"
require_text docs/testing.md "positive monitor count"
require_text docs/testing.md "delivered resize events after"
require_text docs/testing.md "raw display/window identity"
require_text docs/testing.md "Both Linux runtime paths replay the captured transcript"
require_text docs/testing.md "--linux-input pending-ok"
require_text docs/testing.md "Wayland flush failures"
require_text docs/testing.md "write-ready polling"
require_text docs/testing.md "Windows runtime path replays the"
require_text docs/testing.md "strict Linux input smoke command"
require_text docs/testing.md "WINDOW_CI_HOST=linux bash scripts/check_ci.sh"
require_text docs/testing.md "WINDOW_CI_HOST=windows bash scripts/check_ci.sh"
require_text docs/testing.md 'moon info web --target wasm-gc'
require_text docs/testing.md "docs/moui-integration-smoke.md"
require_text docs/testing.md "Full MoUI consumer evidence records"
require_text docs/testing.md "computed MoUI consumer status"
require_text docs/testing.md "non-prefixed smoke evidence rejection"
require_text docs/testing.md "ordinary logs that merely"
require_text docs/testing.md "Ready and teardown"
require_text docs/testing.md "near-miss values such"
require_text docs/testing.md "--runtime-log yes"
require_text docs/testing.md "--runtime-log-command"
require_text docs/testing.md "passed Linux/Windows evidence"
require_text docs/testing.md "Linux/Windows evidence"
require_text docs/testing.md "matching-host capture helper"
require_text docs/testing.md "--renderer-handle yes"
require_text docs/testing.md "--text-input yes"
require_text docs/testing.md "--monitor-cursor yes"
require_text docs/testing.md "--clean-shutdown yes"

require_text docs/platform-gaps.md 'Treat `Pending` as missing evidence'
require_text docs/platform-gaps.md "docs/moui-integration-smoke.md"
require_text docs/platform-gaps.md "scripts/check_runtime_smoke.sh"
require_text docs/platform-gaps.md "scripts/check_moui_runtime_log.sh"
require_text docs/platform-gaps.md "bash scripts/capture_moui_runtime_evidence.sh"
require_text docs/platform-gaps.md "scripts/check_moui_readiness.sh"
require_text docs/platform-gaps.md "scripts/check_moui_evidence.sh"
require_text docs/platform-gaps.md "scripts/check_moon_baseline.sh"
require_text docs/platform-gaps.md "bash scripts/record_moui_evidence.sh"
require_text docs/platform-gaps.md "scripts/check_ffi_surface.sh"
require_text docs/platform-gaps.md "macOS, Linux, and Windows native FFI"
require_text docs/platform-gaps.md '`--status passed` requires explicit `yes` evidence'
require_text docs/platform-gaps.md "--consumer-input"
require_text docs/platform-gaps.md '`--consumer-command` with the exact downstream command'
require_text docs/platform-gaps.md "scripts/check_moui_macos_smoke.sh"
require_text docs/platform-gaps.md "scripts/check_moui_linux_smoke.sh"
require_text docs/platform-gaps.md "WINDOW_MOUI_LINUX_REQUIRE_INPUT=1"
require_text docs/platform-gaps.md "scripts/check_moui_windows_smoke.sh"
require_text docs/platform-gaps.md "scripts/check_moui_web_smoke.sh"
require_text docs/platform-gaps.md "monitor/current-monitor probes"
require_text docs/platform-gaps.md "cursor state"
require_text docs/platform-gaps.md "text/IME=<yes/no/pending>"
require_text docs/platform-gaps.md "monitor/cursor=<yes/no/pending>"
require_text docs/platform-gaps.md "status=<passed/failed/pending>"
require_text docs/platform-gaps.md "computed MoUI consumer status"
require_text docs/platform-gaps.md "Runtime log: verified=<yes/no/pending>"
require_text docs/platform-gaps.md "--runtime-log yes"
require_text docs/platform-gaps.md "--runtime-log-command"
require_text docs/platform-gaps.md 'cursor probe `Icon(Text)`'
require_text docs/platform-gaps.md "public IME state probes"
require_text docs/platform-gaps.md "Wayland IME/preedit delivery"
require_text docs/platform-gaps.md 'Wayland `wl_output` monitor/current-monitor probes'
require_text docs/platform-gaps.md "surface enter/current-output tracking"
require_text docs/platform-gaps.md '`primary_id=0x...`/`current_id=0x...` native ids'
require_text docs/platform-gaps.md "HWND/HINSTANCE/raw-display handle fields"
require_text docs/platform-gaps.md "raw display/window identity"
require_text docs/platform-gaps.md '`current=true` for the window monitor'
require_text docs/platform-gaps.md "HINSTANCE-backed display handles"
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh macos"
require_text docs/platform-gaps.md "Dry-run mode audits the selected"
require_text docs/platform-gaps.md "mismatched-host"
require_text docs/platform-gaps.md "non-dry-run failures"
require_text docs/platform-gaps.md "offline Linux/Windows runtime log verifier samples"
require_text docs/platform-gaps.md "runtime smoke also replay their captured logs through that verifier"
require_text docs/platform-gaps.md "Captured runtime logs can"
require_text docs/platform-gaps.md "--linux-input pending-ok"
require_text docs/platform-gaps.md "positive surface size/scale"
require_text docs/platform-gaps.md "positive monitor count"
require_text docs/platform-gaps.md "delivered resize events after"
require_text docs/platform-gaps.md "capture helper writes the transcript"
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh web"
require_text docs/platform-gaps.md 'scripts/check_moui_web_smoke.sh` preflight'
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh linux"
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh windows"
require_text docs/platform-gaps.md "WINDOW_CI_HOST=linux bash scripts/check_ci.sh"
require_text docs/platform-gaps.md "WINDOW_CI_HOST=windows bash scripts/check_ci.sh"
require_text docs/platform-gaps.md 'copyable `bash scripts/record_moui_evidence.sh`'
require_text docs/platform-gaps.md 'replace `pending` values only with facts observed on the matching'

require_text scripts/check_ci.sh "bash scripts/check_ci_host.sh"
require_text scripts/check_ci.sh "bash scripts/check_runtime_smoke.sh"
require_text scripts/check_runtime_smoke.sh "expect_log_success linux"
require_text scripts/check_runtime_smoke.sh "expect_log_failure windows"
require_text scripts/check_runtime_smoke.sh "expect_log_order_failure"
require_text scripts/capture_moui_runtime_evidence.sh 'WINDOW_CI_HOST=$backend'
require_text scripts/capture_moui_runtime_evidence.sh "bash scripts/record_moui_evidence.sh"
require_text scripts/capture_moui_runtime_evidence.sh "scripts/check_moui_runtime_log.sh"
require_text scripts/capture_moui_runtime_evidence.sh "--runtime-log yes"
require_text scripts/check_moui_evidence.sh "linux capture dry run"
require_text scripts/check_moui_evidence.sh "mismatched capture requires matching host"
require_text scripts/check_moui_runtime_log.sh "Usage: scripts/check_moui_runtime_log.sh [--linux-input <strict|pending-ok>] <linux|windows> <logfile>"
require_text scripts/check_moui_runtime_log.sh "extract_token_field"
require_text scripts/check_moui_runtime_log.sh "duplicate field"
require_text scripts/check_moui_runtime_log.sh "field size must be WIDTHxHEIGHT"
require_text scripts/check_moui_runtime_log.sh "require_current_monitor_id"
require_text scripts/check_moui_runtime_log.sh "require_surface_probe"
require_text scripts/check_moui_runtime_log.sh "require_resize_delivery"
require_text scripts/check_moui_runtime_log.sh "require_positive_decimal"
require_text scripts/check_moui_runtime_log.sh "MOUILinuxSmoke wl_display"
require_text scripts/check_moui_runtime_log.sh "MOUILinuxSmoke xdg_toplevel"
require_text scripts/check_moui_runtime_log.sh "linux_input_mode"
require_text scripts/check_moui_runtime_log.sh "raw_display identity"
require_text scripts/check_moui_runtime_log.sh 'require_nonzero_hex "$prefix current_id"'
require_text scripts/check_moui_linux_smoke.sh "--linux-input pending-ok"
require_text scripts/check_moui_linux_smoke.sh "bash scripts/check_moui_runtime_log.sh"
require_text scripts/check_moui_linux_smoke.sh "scripts/check_moui_runtime_log.sh linux"
require_text scripts/check_moui_windows_smoke.sh "bash scripts/check_moui_runtime_log.sh"
require_text scripts/check_moui_windows_smoke.sh "scripts/check_moui_runtime_log.sh windows"
require_text scripts/check_ci.sh "bash scripts/check_moui_readiness.sh"
require_text scripts/check_ci.sh "bash scripts/check_moui_evidence.sh"
require_text scripts/check_ci.sh "bash scripts/check_moon_baseline.sh"
require_text scripts/check_ci.sh "moon check --target all --warn-list +73"
require_text scripts/check_ci.sh "bash scripts/check_moui_macos_smoke.sh"
require_text scripts/check_ci.sh "bash scripts/check_moui_linux_smoke.sh"
require_text scripts/check_ci.sh "bash scripts/check_moui_windows_smoke.sh"
require_text scripts/check_ci.sh "bash scripts/check_web_assets.sh"
require_text scripts/check_ci.sh "bash scripts/check_moui_web_smoke.sh"
require_text scripts/check_ci.sh "bash scripts/check_ffi_surface.sh"
require_text scripts/check_ffi_surface.sh "ffi-linux-export-allowlist.txt"
require_text scripts/check_ffi_surface.sh "ffi-windows-export-allowlist.txt"
require_text scripts/check_ffi_surface.sh "check_export_allowlist \"Linux\""
require_text scripts/check_ffi_surface.sh "check_export_allowlist \"Windows\""
require_text scripts/check_ffi_surface.sh "extract_mbw_bindings_from"
require_text scripts/check_ffi_surface.sh "check_binding_exports \"Linux\""
require_text scripts/check_ffi_surface.sh "check_binding_exports \"Windows\""
require_text scripts/check_ffi_surface.sh "check_branch_exports \"Linux\""
require_text scripts/check_ffi_surface.sh "check_branch_exports \"Windows\""
require_text scripts/check_ffi_surface.sh "check_branch_signatures \"Linux\""
require_text scripts/check_ffi_surface.sh "check_branch_signatures \"Windows\""
require_text scripts/check_moui_evidence.sh "documented Web recorder template"
require_text scripts/check_moui_evidence.sh "documented Linux pending recorder template"
require_text scripts/check_moui_evidence.sh "documented Windows pending recorder template"
require_text scripts/check_moui_evidence.sh "--monitor-cursor"
require_text scripts/check_moui_evidence.sh "--text-input"
require_text scripts/check_moui_evidence.sh "remote passed evidence requires runtime log"
require_text scripts/check_moui_evidence.sh "matching-host passed native evidence requires runtime log"
require_text scripts/check_moui_evidence.sh "Runtime log: verified=pending"
require_text scripts/check_moui_evidence.sh "MoUI consumer: status=pending"
require_text scripts/check_moui_evidence.sh "MoUI consumer: status=passed"
require_text scripts/record_moui_evidence.sh "--runtime-log"
require_text scripts/record_moui_evidence.sh "--runtime-log-command"
require_text scripts/record_moui_evidence.sh "Linux/Windows passed evidence requires"
require_text scripts/record_moui_evidence.sh "remote passed"
require_text scripts/check_moui_macos_smoke.sh "require_output_order"
require_text scripts/check_moui_linux_smoke.sh "run_runtime_verifier"
require_text scripts/check_moui_windows_smoke.sh "run_runtime_verifier"
require_text scripts/check_moui_macos_smoke.sh "window.available_monitors()"
require_text scripts/check_moui_linux_smoke.sh "window.available_monitors()"
require_text scripts/check_moui_windows_smoke.sh "window.available_monitors()"
require_text scripts/check_moui_macos_smoke.sh "window.set_cursor_icon(Text)"
require_text scripts/check_moui_linux_smoke.sh "window.set_cursor_icon(Text)"
require_text scripts/check_moui_windows_smoke.sh "window.set_cursor_icon(Text)"
require_text scripts/check_moui_runtime_log.sh "MOUILinuxSmoke: handles wl_display=0x"
require_text scripts/check_moui_runtime_log.sh "MOUILinuxSmoke: monitors count="
require_text scripts/check_moui_runtime_log.sh "primary_id=0x"
require_text scripts/check_moui_runtime_log.sh "current=true"
require_text scripts/check_moui_runtime_log.sh "current_id=0x"
require_text scripts/check_moui_runtime_log.sh "MOUILinuxSmoke: cursor Icon(Text)"
require_text scripts/check_moui_runtime_log.sh "MOUILinuxSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true"
require_text scripts/check_moui_runtime_log.sh "MOUIWindowsSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true"
require_text scripts/check_moui_runtime_log.sh "MOUIWindowsSmoke: handle hwnd=0x"
require_text scripts/check_moui_runtime_log.sh "hinstance=0x"
require_text scripts/check_moui_runtime_log.sh "raw_display=0x"
require_text scripts/check_moui_runtime_log.sh "raw_window=0x"
require_text scripts/check_moui_windows_smoke.sh "raw_display == display"
require_text scripts/check_moui_windows_smoke.sh "raw_window == hwnd"
require_text scripts/check_moui_runtime_log.sh "MOUIWindowsSmoke: monitors count="
require_text scripts/check_moui_runtime_log.sh "primary_id=0x"
require_text scripts/check_moui_runtime_log.sh "current=true"
require_text scripts/check_moui_runtime_log.sh "current_id=0x"
require_text scripts/check_moui_runtime_log.sh "MOUIWindowsSmoke: cursor Icon(Text)"

require_text docs/moui-integration-smoke.md "MoUI Consumer Evidence"
require_text docs/moui-integration-smoke.md "bash scripts/check_ci.sh"
require_text docs/moui-integration-smoke.md "scripts/check_moui_readiness.sh"
require_text docs/moui-integration-smoke.md "scripts/check_moui_evidence.sh"
require_text docs/moui-integration-smoke.md "scripts/check_moui_runtime_log.sh <linux|windows> <captured-log>"
require_text docs/moui-integration-smoke.md "scripts/check_moon_baseline.sh"
require_text docs/moui-integration-smoke.md "bash scripts/record_moui_evidence.sh"
require_text docs/moui-integration-smoke.md '`--window-opened yes`'
require_text docs/moui-integration-smoke.md "--runtime-log yes"
require_text docs/moui-integration-smoke.md "--runtime-log-command"
require_text docs/moui-integration-smoke.md "--consumer-input yes"
require_text docs/moui-integration-smoke.md '`--consumer-command` with the exact downstream command'
require_text docs/moui-integration-smoke.md "separate MoUI consumer status"
require_text docs/moui-integration-smoke.md "native Linux/Windows consumer readiness still needs"
require_text docs/moui-integration-smoke.md "scripts/check_moui_macos_smoke.sh"
require_text docs/moui-integration-smoke.md "scripts/check_moui_linux_smoke.sh"
require_text docs/moui-integration-smoke.md "WINDOW_MOUI_LINUX_REQUIRE_INPUT=1"
require_text docs/moui-integration-smoke.md "scripts/check_moui_windows_smoke.sh"
require_text docs/moui-integration-smoke.md "scripts/check_moui_web_smoke.sh"
require_text docs/moui-integration-smoke.md "canvas_id=moui-web-smoke-canvas"
require_text docs/moui-integration-smoke.md 'keyboard text `a`'
require_text docs/moui-integration-smoke.md "Copyable recorder commands"
require_text docs/moui-integration-smoke.md "--consumer-command \"scripts/smoke_runtime.sh web; browser http://127.0.0.1:8000/examples/moui_web_smoke/index.html\""
require_text docs/moui-integration-smoke.md "--text-input yes"
require_text docs/moui-integration-smoke.md "--text-input pending"
require_text docs/moui-integration-smoke.md "surface/scale and monitor count are environment-sensitive in CLI-launched AppKit smoke"
require_text docs/moui-integration-smoke.md "latest local run printed surface size=1x0 scale=1 and monitors count=0 primary=false current=false"
require_text docs/moui-integration-smoke.md "with nonzero handles, cursor Icon(Text), resize/redraw, pointer 24,32"
require_text docs/moui-integration-smoke.md "--host \"Linux Wayland/Weston CI\""
require_text docs/moui-integration-smoke.md "--host \"Windows Win32 CI\""
require_text docs/moui-integration-smoke.md "representative keyboard text a"
require_text docs/moui-integration-smoke.md "IME probe enabled/update/disable"
require_text docs/moui-integration-smoke.md "hint/purpose enable/update probes"
require_text docs/moui-integration-smoke.md "public IME probe enable/update/disable"
require_text docs/moui-integration-smoke.md "HWND/HINSTANCE/raw_display/raw_window handle fields"
require_text docs/moui-integration-smoke.md "Window::rwh_06_display_handle()"
require_text docs/moui-integration-smoke.md "Window::rwh_06_window_handle()"
require_text docs/moui-integration-smoke.md "raw display/window identity"
require_text docs/moui-integration-smoke.md 'monitor/current-monitor probes'
require_text docs/moui-integration-smoke.md '`primary=true`'
require_text docs/moui-integration-smoke.md '`current=true` from surface enter/current-output tracking'
require_text docs/moui-integration-smoke.md '`primary_id=0x...`/`current_id=0x...` native monitor ids'
require_text docs/moui-integration-smoke.md "primary_id/current_id native ids"
require_text docs/moui-integration-smoke.md "surface enter/current-output tracking"
require_text docs/moui-integration-smoke.md "destroy requested"
require_text docs/moui-integration-smoke.md "Destroyed before finished"
require_text docs/moui-integration-smoke.md 'nonzero `primary_id` and `current_id`'
require_text docs/moui-integration-smoke.md "positive surface size and scale"
require_text docs/moui-integration-smoke.md "positive monitor count"
require_text docs/moui-integration-smoke.md "delivered resize events after"
require_text docs/moui-integration-smoke.md "raw display/window identity"
require_text docs/moui-integration-smoke.md "scripts/smoke_runtime.sh web"
require_text docs/moui-integration-smoke.md "scripts/smoke_runtime.sh <backend>"
require_text docs/moui-integration-smoke.md 'moon info web --target wasm-gc'
require_text docs/moui-integration-smoke.md "Window::content_view_handle()"
require_text docs/moui-integration-smoke.md "Window::canvas_id()"
require_text docs/moui-integration-smoke.md "keyboard text or IME commit text"
require_text docs/moui-integration-smoke.md "monitor/current-monitor probes"
require_text docs/moui-integration-smoke.md "cursor state"
require_text docs/moui-integration-smoke.md "cursor Icon(Text)"
require_text docs/moui-integration-smoke.md "--monitor-cursor yes"
require_text docs/moui-integration-smoke.md "--monitor-cursor pending"
require_text docs/moui-integration-smoke.md "present_rgba_pixels"

printf 'Documentation smoke check passed\n'
