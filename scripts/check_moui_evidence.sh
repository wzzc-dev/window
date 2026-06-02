#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

fail() {
  printf 'MoUI evidence helper check failed: %s\n' "$1" >&2
  exit 1
}

require_text() {
  local label="$1"
  local output="$2"
  local text="$3"
  [[ "$output" == *"$text"* ]] ||
    fail "$label output did not contain expected text: $text"
}

last_output=""

expect_success() {
  local label="$1"
  local output status
  shift
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    fail "$label failed with status $status: $output"
  fi
  last_output="$output"
}

expect_failure() {
  local label="$1"
  local output status
  shift
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    fail "$label unexpectedly succeeded: $output"
  fi
  last_output="$output"
}

matching_host_label() {
  case "$1" in
    macos) printf 'macOS' ;;
    linux) printf 'Linux' ;;
    windows) printf 'Windows' ;;
    *) fail "unknown native backend $1" ;;
  esac
}

actual_host="$(detect_window_actual_host)"
case "$actual_host" in
  macos)
    mismatched_backend="linux"
    bad_host_label="macOS"
    ;;
  linux)
    mismatched_backend="windows"
    bad_host_label="Linux"
    ;;
  windows)
    mismatched_backend="linux"
    bad_host_label="Windows"
    ;;
  none)
    mismatched_backend="linux"
    bad_host_label="Windows"
    ;;
  *)
    fail "detect_window_actual_host returned unexpected value $actual_host"
    ;;
esac
mismatched_label="$(matching_host_label "$mismatched_backend")"

platform_gaps_before="$(cksum docs/platform-gaps.md)"

expect_success "pending evidence" \
  scripts/record_moui_evidence.sh linux --status pending
require_text "pending evidence" "$last_output" \
  "linux build/runtime smoke"
require_text "pending evidence" "$last_output" \
  "window opened=pending"

expect_failure "mismatched passed native evidence" \
  scripts/record_moui_evidence.sh "$mismatched_backend" \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes
require_text "mismatched passed native evidence" "$last_output" \
  "passed $mismatched_backend evidence requires a $mismatched_backend host"
require_text "mismatched passed native evidence" "$last_output" \
  "Use --host to name the remote matching host"

expect_success "remote matching-host evidence" \
  scripts/record_moui_evidence.sh "$mismatched_backend" \
    --status passed \
    --host "$mismatched_label CI" \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --consumer-command "external MoUI smoke" \
    --surface yes \
    --redraw yes \
    --resize-scale yes \
    --consumer-input yes \
    --text-input yes \
    --renderer-handle yes \
    --monitor-cursor yes \
    --clean-shutdown yes
require_text "remote matching-host evidence" "$last_output" \
  "on $mismatched_label CI"
require_text "remote matching-host evidence" "$last_output" \
  "representative input=yes"
require_text "remote matching-host evidence" "$last_output" \
  "resize/scale=yes, input=yes"
require_text "remote matching-host evidence" "$last_output" \
  "renderer handle=yes"
require_text "remote matching-host evidence" "$last_output" \
  "text/IME=yes"
require_text "remote matching-host evidence" "$last_output" \
  "monitor/cursor=yes"

expect_failure "remote mismatched-host label" \
  scripts/record_moui_evidence.sh "$mismatched_backend" \
    --status passed \
    --host "$bad_host_label CI" \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes
require_text "remote mismatched-host label" "$last_output" \
  "--host for passed $mismatched_backend evidence must name a matching $mismatched_label host"

expect_success "linux partial evidence stays pending" \
  scripts/record_moui_evidence.sh linux \
    --status pending \
    --window-opened yes \
    --resize-redraw yes \
    --clean-exit yes
require_text "linux partial evidence stays pending" "$last_output" \
  "linux build/runtime smoke"
require_text "linux partial evidence stays pending" "$last_output" \
  "representative input=pending"
require_text "linux partial evidence stays pending" "$last_output" \
  "resize/scale=pending, input=pending"
require_text "linux partial evidence stays pending" "$last_output" \
  "text/IME=pending"
require_text "linux partial evidence stays pending" "$last_output" \
  "monitor/cursor=pending"

expect_success "runtime input does not imply consumer input" \
  scripts/record_moui_evidence.sh web \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes
require_text "runtime input does not imply consumer input" "$last_output" \
  "representative input=yes"
require_text "runtime input does not imply consumer input" "$last_output" \
  "resize/scale=pending, input=pending"
require_text "runtime input does not imply consumer input" "$last_output" \
  "text/IME=pending"
require_text "runtime input does not imply consumer input" "$last_output" \
  "monitor/cursor=pending"

expect_success "documented Web recorder template" \
  scripts/record_moui_evidence.sh web \
    --status passed \
    --commands "bash scripts/check_ci.sh; scripts/smoke_runtime.sh web; browser http://127.0.0.1:8000/examples/moui_web_smoke/index.html" \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --consumer-command "scripts/smoke_runtime.sh web; browser http://127.0.0.1:8000/examples/moui_web_smoke/index.html" \
    --surface yes \
    --redraw yes \
    --resize-scale yes \
    --consumer-input yes \
    --text-input yes \
    --renderer-handle yes \
    --monitor-cursor pending \
    --clean-shutdown yes \
    --notes "page reached PASS with canvas_id=moui-web-smoke-canvas, pointer 24,32, keyboard text a, and no browser console warnings/errors"
require_text "documented Web recorder template" "$last_output" \
  "web build/runtime smoke"
require_text "documented Web recorder template" "$last_output" \
  "renderer handle=yes"
require_text "documented Web recorder template" "$last_output" \
  "text/IME=yes"
require_text "documented Web recorder template" "$last_output" \
  "monitor/cursor=pending"
require_text "documented Web recorder template" "$last_output" \
  "clean shutdown=yes"
require_text "documented Web recorder template" "$last_output" \
  "canvas_id=moui-web-smoke-canvas"

if [[ "$actual_host" == "macos" ]]; then
  expect_success "documented macOS recorder template" \
    scripts/record_moui_evidence.sh macos \
      --status passed \
      --commands "WINDOW_CI_HOST=macos bash scripts/check_ci.sh; scripts/check_moui_macos_smoke.sh --run" \
      --window-opened yes \
      --resize-redraw yes \
      --input yes \
      --clean-exit yes \
      --consumer-command "scripts/check_moui_macos_smoke.sh --run" \
      --surface yes \
      --redraw yes \
      --resize-scale yes \
      --consumer-input yes \
      --text-input yes \
      --renderer-handle yes \
      --monitor-cursor yes \
      --clean-shutdown yes \
      --notes "surface/scale and monitor count are environment-sensitive in CLI-launched AppKit smoke; latest local run printed surface size=1x0 scale=1 and monitors count=0 primary=false current=false, with nonzero handles, cursor Icon(Text), resize/redraw, pointer 24,32, keyboard text a, and Destroyed before finished"
  require_text "documented macOS recorder template" "$last_output" \
    "macos build/runtime smoke"
  require_text "documented macOS recorder template" "$last_output" \
    "renderer handle=yes"
  require_text "documented macOS recorder template" "$last_output" \
    "text/IME=yes"
  require_text "documented macOS recorder template" "$last_output" \
    "monitor/cursor=yes"
  require_text "documented macOS recorder template" "$last_output" \
    "clean shutdown=yes"
  require_text "documented macOS recorder template" "$last_output" \
    "Destroyed before finished"
  require_text "documented macOS recorder template" "$last_output" \
    "cursor Icon(Text)"
else
  expect_failure "documented macOS recorder template requires macOS host" \
    scripts/record_moui_evidence.sh macos \
      --status passed \
      --commands "WINDOW_CI_HOST=macos bash scripts/check_ci.sh; scripts/check_moui_macos_smoke.sh --run" \
      --window-opened yes \
      --resize-redraw yes \
      --input yes \
      --clean-exit yes \
      --consumer-command "scripts/check_moui_macos_smoke.sh --run" \
      --surface yes \
      --redraw yes \
      --resize-scale yes \
      --consumer-input yes \
      --text-input yes \
      --renderer-handle yes \
      --monitor-cursor yes \
      --clean-shutdown yes
  require_text "documented macOS recorder template requires macOS host" "$last_output" \
    "passed macos evidence requires a macos host"
fi

expect_success "documented Linux pending recorder template" \
  scripts/record_moui_evidence.sh linux \
    --status pending \
    --host "Linux Wayland/Weston CI" \
    --commands "WINDOW_CI_HOST=linux bash scripts/check_ci.sh; scripts/smoke_runtime.sh linux; WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run" \
    --window-opened pending \
    --resize-redraw pending \
    --input pending \
    --clean-exit pending \
    --consumer-command "WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run" \
    --surface pending \
    --redraw pending \
    --resize-scale pending \
    --consumer-input pending \
    --text-input pending \
    --renderer-handle pending \
    --monitor-cursor pending \
    --clean-shutdown pending \
    --notes "replace pending values only with observed matching-host Wayland facts, including monitor/current-monitor and cursor probes"
require_text "documented Linux pending recorder template" "$last_output" \
  "linux build/runtime smoke"
require_text "documented Linux pending recorder template" "$last_output" \
  "on Linux Wayland/Weston CI"
require_text "documented Linux pending recorder template" "$last_output" \
  "renderer handle=pending"
require_text "documented Linux pending recorder template" "$last_output" \
  "text/IME=pending"
require_text "documented Linux pending recorder template" "$last_output" \
  "monitor/cursor=pending"
require_text "documented Linux pending recorder template" "$last_output" \
  "clean shutdown=pending"

expect_success "documented Windows pending recorder template" \
  scripts/record_moui_evidence.sh windows \
    --status pending \
    --host "Windows Win32 CI" \
    --commands "WINDOW_CI_HOST=windows bash scripts/check_ci.sh; scripts/smoke_runtime.sh windows; scripts/check_moui_windows_smoke.sh --run" \
    --window-opened pending \
    --resize-redraw pending \
    --input pending \
    --clean-exit pending \
    --consumer-command "scripts/check_moui_windows_smoke.sh --run" \
    --surface pending \
    --redraw pending \
    --resize-scale pending \
    --consumer-input pending \
    --text-input pending \
    --renderer-handle pending \
    --monitor-cursor pending \
    --clean-shutdown pending \
    --notes "replace pending values only with observed matching-host Win32 facts, including monitor/current-monitor and cursor probes"
require_text "documented Windows pending recorder template" "$last_output" \
  "windows build/runtime smoke"
require_text "documented Windows pending recorder template" "$last_output" \
  "on Windows Win32 CI"
require_text "documented Windows pending recorder template" "$last_output" \
  "renderer handle=pending"
require_text "documented Windows pending recorder template" "$last_output" \
  "text/IME=pending"
require_text "documented Windows pending recorder template" "$last_output" \
  "monitor/cursor=pending"
require_text "documented Windows pending recorder template" "$last_output" \
  "clean shutdown=pending"

expect_failure "consumer evidence requires command" \
  scripts/record_moui_evidence.sh web \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --surface yes
require_text "consumer evidence requires command" "$last_output" \
  "consumer evidence fields require --consumer-command"

expect_failure "monitor cursor evidence requires command" \
  scripts/record_moui_evidence.sh web \
    --monitor-cursor yes
require_text "monitor cursor evidence requires command" "$last_output" \
  "consumer evidence fields require --consumer-command"

expect_failure "text input evidence requires command" \
  scripts/record_moui_evidence.sh web \
    --text-input yes
require_text "text input evidence requires command" "$last_output" \
  "consumer evidence fields require --consumer-command"

expect_failure "empty consumer command" \
  scripts/record_moui_evidence.sh web \
    --consumer-command ""
require_text "empty consumer command" "$last_output" \
  "--consumer-command cannot be empty"

expect_failure "incomplete passed evidence" \
  scripts/record_moui_evidence.sh web \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --clean-exit yes
require_text "incomplete passed evidence" "$last_output" \
  "passed evidence requires --input yes"

expect_failure "invalid observed value" \
  scripts/record_moui_evidence.sh web --input maybe
require_text "invalid observed value" "$last_output" \
  "observed values must be yes, no, or pending"

platform_gaps_after="$(cksum docs/platform-gaps.md)"
if [[ "$platform_gaps_after" != "$platform_gaps_before" ]]; then
  fail "record_moui_evidence.sh modified docs/platform-gaps.md"
fi

printf 'MoUI evidence helper check passed: detected %s\n' "$actual_host"
