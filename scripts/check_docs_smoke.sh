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
  scripts/check_ci.sh \
  scripts/check_ci_host.sh \
  scripts/check_runtime_smoke.sh \
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
require_text README.mbt.md "the MoUI consumer page URL"
require_text README.mbt.md "scripts/record_moui_evidence.sh"
require_text README.mbt.md "--window-opened yes"
require_text README.mbt.md "--consumer-input yes"
require_text README.mbt.md "--text-input yes"
require_text README.mbt.md "--monitor-cursor yes"
require_text README.mbt.md "--consumer-command"
require_text README.mbt.md "scripts/smoke_runtime.sh macos"
require_text README.mbt.md "WINDOW_RUNTIME_SMOKE_DRY_RUN=1"

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
require_text docs/testing.md "scripts/check_moui_readiness.sh"
require_text docs/testing.md "scripts/check_moui_evidence.sh"
require_text docs/testing.md "scripts/check_moon_baseline.sh"
require_text docs/testing.md "scripts/record_moui_evidence.sh"
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
require_text docs/testing.md 'requires `destroyed` before `finished`'
require_text docs/testing.md "monitor/current-monitor probes"
require_text docs/testing.md "cursor state"
require_text docs/testing.md "moui-web-smoke-canvas"
require_text docs/testing.md 'pointer `24,32`'
require_text docs/testing.md "examples/moui_web_smoke/index.html"
require_text docs/testing.md "scripts/smoke_runtime.sh <backend>"
require_text docs/testing.md "WINDOW_CI_HOST=linux bash scripts/check_ci.sh"
require_text docs/testing.md "WINDOW_CI_HOST=windows bash scripts/check_ci.sh"
require_text docs/testing.md 'moon info web --target wasm-gc'
require_text docs/testing.md "docs/moui-integration-smoke.md"
require_text docs/testing.md "Full MoUI consumer evidence records"
require_text docs/testing.md "--renderer-handle yes"
require_text docs/testing.md "--text-input yes"
require_text docs/testing.md "--monitor-cursor yes"
require_text docs/testing.md "--clean-shutdown yes"

require_text docs/platform-gaps.md 'Treat `Pending` as missing evidence'
require_text docs/platform-gaps.md "docs/moui-integration-smoke.md"
require_text docs/platform-gaps.md "scripts/check_runtime_smoke.sh"
require_text docs/platform-gaps.md "scripts/check_moui_readiness.sh"
require_text docs/platform-gaps.md "scripts/check_moui_evidence.sh"
require_text docs/platform-gaps.md "scripts/check_moon_baseline.sh"
require_text docs/platform-gaps.md "scripts/record_moui_evidence.sh"
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
require_text docs/platform-gaps.md 'cursor probe `Icon(Text)`'
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh macos"
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh web"
require_text docs/platform-gaps.md 'scripts/check_moui_web_smoke.sh` preflight'
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh linux"
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh windows"
require_text docs/platform-gaps.md "WINDOW_CI_HOST=linux bash scripts/check_ci.sh"
require_text docs/platform-gaps.md "WINDOW_CI_HOST=windows bash scripts/check_ci.sh"
require_text docs/platform-gaps.md 'copyable `record_moui_evidence.sh`'
require_text docs/platform-gaps.md 'replace `pending` values only with facts observed on the matching'

require_text scripts/check_ci.sh "bash scripts/check_ci_host.sh"
require_text scripts/check_ci.sh "bash scripts/check_runtime_smoke.sh"
require_text scripts/check_ci.sh "bash scripts/check_moui_readiness.sh"
require_text scripts/check_ci.sh "bash scripts/check_moui_evidence.sh"
require_text scripts/check_ci.sh "bash scripts/check_moon_baseline.sh"
require_text scripts/check_ci.sh "moon check --target all --warn-list +73"
require_text scripts/check_ci.sh "bash scripts/check_moui_macos_smoke.sh"
require_text scripts/check_ci.sh "bash scripts/check_moui_linux_smoke.sh"
require_text scripts/check_ci.sh "bash scripts/check_moui_windows_smoke.sh"
require_text scripts/check_ci.sh "bash scripts/check_web_assets.sh"
require_text scripts/check_ci.sh "bash scripts/check_moui_web_smoke.sh"
require_text scripts/check_moui_evidence.sh "documented Web recorder template"
require_text scripts/check_moui_evidence.sh "documented Linux pending recorder template"
require_text scripts/check_moui_evidence.sh "documented Windows pending recorder template"
require_text scripts/check_moui_evidence.sh "--monitor-cursor"
require_text scripts/check_moui_evidence.sh "--text-input"
require_text scripts/check_moui_macos_smoke.sh "require_output_order"
require_text scripts/check_moui_linux_smoke.sh "require_output_order"
require_text scripts/check_moui_windows_smoke.sh "require_output_order"
require_text scripts/check_moui_macos_smoke.sh "window.available_monitors()"
require_text scripts/check_moui_linux_smoke.sh "window.available_monitors()"
require_text scripts/check_moui_windows_smoke.sh "window.available_monitors()"
require_text scripts/check_moui_macos_smoke.sh "window.set_cursor_icon(Text)"
require_text scripts/check_moui_linux_smoke.sh "window.set_cursor_icon(Text)"
require_text scripts/check_moui_windows_smoke.sh "window.set_cursor_icon(Text)"

require_text docs/moui-integration-smoke.md "MoUI Consumer Evidence"
require_text docs/moui-integration-smoke.md "bash scripts/check_ci.sh"
require_text docs/moui-integration-smoke.md "scripts/check_moui_readiness.sh"
require_text docs/moui-integration-smoke.md "scripts/check_moui_evidence.sh"
require_text docs/moui-integration-smoke.md "scripts/check_moon_baseline.sh"
require_text docs/moui-integration-smoke.md "scripts/record_moui_evidence.sh"
require_text docs/moui-integration-smoke.md '`--window-opened yes`'
require_text docs/moui-integration-smoke.md "--consumer-input yes"
require_text docs/moui-integration-smoke.md '`--consumer-command` with the exact downstream command'
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
