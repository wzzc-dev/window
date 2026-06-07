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

record_evidence() {
  bash scripts/record_moui_evidence.sh "$@"
}

capture_evidence() {
  bash scripts/capture_moui_runtime_evidence.sh "$@"
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

fake_linux_uname_dir="$(mktemp -d "${TMPDIR:-/tmp}/moui-fake-linux-uname.XXXXXX")"
trap 'rm -rf "$fake_linux_uname_dir"' EXIT
cat >"$fake_linux_uname_dir/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s)
    printf 'Linux\n'
    ;;
  -m)
    printf 'x86_64\n'
    ;;
  *)
    printf 'Linux\n'
    ;;
esac
EOF
chmod +x "$fake_linux_uname_dir/uname"
fake_linux_path="$fake_linux_uname_dir:$PATH"

platform_gaps_before="$(cksum docs/platform-gaps.md)"

expect_success "pending evidence" \
  record_evidence linux --status pending
require_text "pending evidence" "$last_output" \
  "linux build/runtime smoke"
require_text "pending evidence" "$last_output" \
  "window opened=pending"

expect_failure "mismatched passed native evidence" \
  record_evidence "$mismatched_backend" \
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
  record_evidence "$mismatched_backend" \
    --status passed \
    --host "$mismatched_label CI" \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh $mismatched_backend captured.log" \
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
  "Runtime log: verified=yes"
require_text "remote matching-host evidence" "$last_output" \
  "scripts/check_moui_runtime_log.sh $mismatched_backend captured.log"
require_text "remote matching-host evidence" "$last_output" \
  "MoUI consumer: status=passed"
require_text "remote matching-host evidence" "$last_output" \
  "resize/scale=yes, input=yes"
require_text "remote matching-host evidence" "$last_output" \
  "renderer handle=yes"
require_text "remote matching-host evidence" "$last_output" \
  "text/IME=yes"
require_text "remote matching-host evidence" "$last_output" \
  "monitor/cursor=yes"

expect_failure "matching-host passed native evidence requires runtime log" \
  env PATH="$fake_linux_path" bash scripts/record_moui_evidence.sh linux \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes
require_text "matching-host passed native evidence requires runtime log" "$last_output" \
  "passed linux evidence requires --runtime-log yes after scripts/check_moui_runtime_log.sh linux"

expect_success "matching-host passed native evidence accepts runtime log" \
  env PATH="$fake_linux_path" bash scripts/record_moui_evidence.sh linux \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh linux captured.log"
require_text "matching-host passed native evidence accepts runtime log" "$last_output" \
  "Runtime log: verified=yes"

expect_failure "remote mismatched-host label" \
  record_evidence "$mismatched_backend" \
    --status passed \
    --host "$bad_host_label CI" \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh $mismatched_backend captured.log"
require_text "remote mismatched-host label" "$last_output" \
  "--host for passed $mismatched_backend evidence must name a matching $mismatched_label host"

expect_failure "remote passed evidence requires runtime log" \
  record_evidence "$mismatched_backend" \
    --status passed \
    --host "$mismatched_label CI" \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes
require_text "remote passed evidence requires runtime log" "$last_output" \
  "remote passed $mismatched_backend evidence requires --runtime-log yes"

expect_failure "runtime log requires command" \
  record_evidence "$mismatched_backend" \
    --runtime-log yes
require_text "runtime log requires command" "$last_output" \
  "runtime log evidence requires --runtime-log-command"

expect_failure "runtime log command must run verifier" \
  record_evidence "$mismatched_backend" \
    --runtime-log yes \
    --runtime-log-command "cat captured.log"
require_text "runtime log command must run verifier" "$last_output" \
  "runtime log evidence for $mismatched_backend requires --runtime-log-command to run scripts/check_moui_runtime_log.sh $mismatched_backend"

expect_failure "runtime log command must invoke verifier" \
  record_evidence "$mismatched_backend" \
    --runtime-log yes \
    --runtime-log-command "echo scripts/check_moui_runtime_log.sh $mismatched_backend captured.log"
require_text "runtime log command must invoke verifier" "$last_output" \
  "as the command invocation"

expect_failure "runtime log command rejects shell suffix" \
  record_evidence "$mismatched_backend" \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh $mismatched_backend captured.log; cat captured.log"
require_text "runtime log command rejects shell suffix" "$last_output" \
  "as the command invocation"

expect_failure "runtime log command rejects extra args" \
  record_evidence "$mismatched_backend" \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh $mismatched_backend captured.log extra"
require_text "runtime log command rejects extra args" "$last_output" \
  "as the command invocation"

expect_failure "runtime log command rejects placeholder path" \
  record_evidence "$mismatched_backend" \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh $mismatched_backend <captured-log>"
require_text "runtime log command rejects placeholder path" "$last_output" \
  "as the command invocation"

expect_failure "runtime log command rejects variable path" \
  record_evidence "$mismatched_backend" \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh $mismatched_backend \$LOG"
require_text "runtime log command rejects variable path" "$last_output" \
  "as the command invocation"

expect_success "runtime log command accepts bash verifier" \
  record_evidence "$mismatched_backend" \
    --runtime-log yes \
    --runtime-log-command "bash scripts/check_moui_runtime_log.sh $mismatched_backend captured.log"
require_text "runtime log command accepts bash verifier" "$last_output" \
  "Runtime log: verified=yes"

expect_success "runtime log command accepts strict linux verifier" \
  record_evidence linux \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh --linux-input strict linux captured.log"
require_text "runtime log command accepts strict linux verifier" "$last_output" \
  "Runtime log: verified=yes"

expect_success "runtime log command accepts escaped log path" \
  record_evidence "$mismatched_backend" \
    --runtime-log yes \
    --runtime-log-command "bash scripts/check_moui_runtime_log.sh $mismatched_backend /tmp/moui\\ runtime.log"
require_text "runtime log command accepts escaped log path" "$last_output" \
  "Runtime log: verified=yes"

expect_failure "passed linux evidence rejects pending-ok verifier" \
  record_evidence linux \
    --status passed \
    --host "Linux CI" \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh --linux-input pending-ok linux captured.log"
require_text "passed linux evidence rejects pending-ok verifier" "$last_output" \
  "passed linux evidence requires strict runtime log verification without --linux-input pending-ok"

expect_success "linux partial evidence stays pending" \
  record_evidence linux \
    --status pending \
    --window-opened yes \
    --resize-redraw yes \
    --clean-exit yes
require_text "linux partial evidence stays pending" "$last_output" \
  "linux build/runtime smoke"
require_text "linux partial evidence stays pending" "$last_output" \
  "representative input=pending"
require_text "linux partial evidence stays pending" "$last_output" \
  "MoUI consumer: status=pending"
require_text "linux partial evidence stays pending" "$last_output" \
  "resize/scale=pending, input=pending"
require_text "linux partial evidence stays pending" "$last_output" \
  "text/IME=pending"
require_text "linux partial evidence stays pending" "$last_output" \
  "monitor/cursor=pending"

expect_success "runtime input does not imply consumer input" \
  record_evidence web \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes
require_text "runtime input does not imply consumer input" "$last_output" \
  "representative input=yes"
require_text "runtime input does not imply consumer input" "$last_output" \
  "MoUI consumer: status=pending"
require_text "runtime input does not imply consumer input" "$last_output" \
  "resize/scale=pending, input=pending"
require_text "runtime input does not imply consumer input" "$last_output" \
  "text/IME=pending"
require_text "runtime input does not imply consumer input" "$last_output" \
  "monitor/cursor=pending"

expect_success "documented Web recorder template" \
  record_evidence web \
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
  "MoUI consumer: status=passed"
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
    record_evidence macos \
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
    "MoUI consumer: status=passed"
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
    record_evidence macos \
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
  record_evidence linux \
    --status pending \
    --host "Linux Wayland/Weston CI" \
    --commands "WINDOW_CI_HOST=linux bash scripts/check_ci.sh; scripts/smoke_runtime.sh linux; WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run; scripts/check_moui_runtime_log.sh linux <captured-log>" \
    --window-opened pending \
    --resize-redraw pending \
    --input pending \
    --clean-exit pending \
    --runtime-log pending \
    --runtime-log-command "scripts/check_moui_runtime_log.sh linux <captured-log>" \
    --consumer-command "WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run" \
    --surface pending \
    --redraw pending \
    --resize-scale pending \
    --consumer-input pending \
    --text-input pending \
    --renderer-handle pending \
    --monitor-cursor pending \
    --clean-shutdown pending \
    --notes "replace pending values only with observed matching-host Wayland facts, including wl_output monitor/current-monitor current=true with primary_id/current_id native ids, cursor probes, public IME probe enable/update/disable, representative keyboard text a before ready with pointer evidence, destroy requested, and Destroyed before finished"
require_text "documented Linux pending recorder template" "$last_output" \
  "linux build/runtime smoke"
require_text "documented Linux pending recorder template" "$last_output" \
  "on Linux Wayland/Weston CI"
require_text "documented Linux pending recorder template" "$last_output" \
  "MoUI consumer: status=pending"
require_text "documented Linux pending recorder template" "$last_output" \
  "renderer handle=pending"
require_text "documented Linux pending recorder template" "$last_output" \
  "text/IME=pending"
require_text "documented Linux pending recorder template" "$last_output" \
  "monitor/cursor=pending"
require_text "documented Linux pending recorder template" "$last_output" \
  "clean shutdown=pending"
require_text "documented Linux pending recorder template" "$last_output" \
  "Runtime log: verified=pending"
require_text "documented Linux pending recorder template" "$last_output" \
  "scripts/check_moui_runtime_log.sh linux <captured-log>"
require_text "documented Linux pending recorder template" "$last_output" \
  "keyboard text a"
require_text "documented Linux pending recorder template" "$last_output" \
  "before ready with pointer evidence"
require_text "documented Linux pending recorder template" "$last_output" \
  "wl_output monitor/current-monitor current=true"
require_text "documented Linux pending recorder template" "$last_output" \
  "primary_id/current_id native ids"
require_text "documented Linux pending recorder template" "$last_output" \
  "public IME probe enable/update/disable"
require_text "documented Linux pending recorder template" "$last_output" \
  "destroy requested"
require_text "documented Linux pending recorder template" "$last_output" \
  "Destroyed before finished"

expect_success "documented Windows passed recorder template" \
  record_evidence windows \
    --status passed \
    --host "Windows Win32 CI" \
    --commands "WINDOW_CI_HOST=windows bash scripts/check_ci.sh; scripts/check_moui_windows_smoke.sh --run; scripts/check_moui_runtime_log.sh windows artifacts/moui-windows-runtime.log" \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh windows artifacts/moui-windows-runtime.log" \
    --consumer-command "scripts/check_moui_windows_smoke.sh --run" \
    --surface yes \
    --redraw yes \
    --resize-scale yes \
    --consumer-input yes \
    --text-input yes \
    --renderer-handle yes \
    --monitor-cursor yes \
    --clean-shutdown yes \
    --notes "matching-host Win32 runtime accepted by scripts/check_moui_runtime_log.sh windows artifacts/moui-windows-runtime.log; observed HWND/HINSTANCE/raw_display/raw_window handle fields, monitor/current-monitor current=true with primary_id/current_id native ids, cursor Icon(Text), IME probe enabled/update/disable with hint/purpose enable/update probes, pointer/keyboard/ime text a before ready, resize/redraw, destroy requested, and Destroyed before finished"
require_text "documented Windows passed recorder template" "$last_output" \
  "windows build/runtime smoke"
require_text "documented Windows passed recorder template" "$last_output" \
  "on Windows Win32 CI"
require_text "documented Windows passed recorder template" "$last_output" \
  "MoUI consumer: status=passed"
require_text "documented Windows passed recorder template" "$last_output" \
  "renderer handle=yes"
require_text "documented Windows passed recorder template" "$last_output" \
  "text/IME=yes"
require_text "documented Windows passed recorder template" "$last_output" \
  "monitor/cursor=yes"
require_text "documented Windows passed recorder template" "$last_output" \
  "clean shutdown=yes"
require_text "documented Windows passed recorder template" "$last_output" \
  "Runtime log: verified=yes"
require_text "documented Windows passed recorder template" "$last_output" \
  "scripts/check_moui_runtime_log.sh windows artifacts/moui-windows-runtime.log"
require_text "documented Windows passed recorder template" "$last_output" \
  "HWND/HINSTANCE/raw_display/raw_window handle fields"
require_text "documented Windows passed recorder template" "$last_output" \
  "primary_id/current_id native ids"
require_text "documented Windows passed recorder template" "$last_output" \
  "cursor Icon(Text)"
require_text "documented Windows passed recorder template" "$last_output" \
  "IME probe enabled/update/disable with hint/purpose enable/update probes"
require_text "documented Windows passed recorder template" "$last_output" \
  "ime text a"
require_text "documented Windows passed recorder template" "$last_output" \
  "pointer/keyboard/ime text a before ready"
require_text "documented Windows passed recorder template" "$last_output" \
  "resize/redraw"
require_text "documented Windows passed recorder template" "$last_output" \
  "destroy requested"
require_text "documented Windows passed recorder template" "$last_output" \
  "Destroyed before finished"

expect_failure "consumer evidence requires command" \
  record_evidence web \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --surface yes
require_text "consumer evidence requires command" "$last_output" \
  "consumer evidence fields require --consumer-command"

expect_failure "monitor cursor evidence requires command" \
  record_evidence web \
    --monitor-cursor yes
require_text "monitor cursor evidence requires command" "$last_output" \
  "consumer evidence fields require --consumer-command"

expect_failure "text input evidence requires command" \
  record_evidence web \
    --text-input yes
require_text "text input evidence requires command" "$last_output" \
  "consumer evidence fields require --consumer-command"

expect_failure "empty consumer command" \
  record_evidence web \
    --consumer-command ""
require_text "empty consumer command" "$last_output" \
  "--consumer-command cannot be empty"

expect_failure "empty runtime log command" \
  record_evidence linux \
    --runtime-log-command ""
require_text "empty runtime log command" "$last_output" \
  "--runtime-log-command cannot be empty"

expect_failure "empty commands" \
  record_evidence linux \
    --commands ""
require_text "empty commands" "$last_output" \
  "--commands cannot be empty"

expect_failure "empty host" \
  record_evidence linux \
    --host ""
require_text "empty host" "$last_output" \
  "--host cannot be empty"

expect_success "web monitor cursor pending accepted" \
  record_evidence web \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --consumer-command "web MoUI smoke" \
    --surface yes \
    --redraw yes \
    --resize-scale yes \
    --consumer-input yes \
    --text-input yes \
    --renderer-handle yes \
    --monitor-cursor pending \
    --clean-shutdown yes
require_text "web monitor cursor pending accepted" "$last_output" \
  "MoUI consumer: status=passed"

expect_success "native monitor cursor pending keeps consumer pending" \
  record_evidence linux \
    --status passed \
    --host "Linux CI" \
    --window-opened yes \
    --resize-redraw yes \
    --input yes \
    --clean-exit yes \
    --runtime-log yes \
    --runtime-log-command "scripts/check_moui_runtime_log.sh linux captured.log" \
    --consumer-command "Linux MoUI smoke" \
    --surface yes \
    --redraw yes \
    --resize-scale yes \
    --consumer-input yes \
    --text-input yes \
    --renderer-handle yes \
    --monitor-cursor pending \
    --clean-shutdown yes
require_text "native monitor cursor pending keeps consumer pending" "$last_output" \
  "MoUI consumer: status=pending"

expect_success "consumer failure status" \
  record_evidence web \
    --consumer-command "web MoUI smoke" \
    --surface no
require_text "consumer failure status" "$last_output" \
  "MoUI consumer: status=failed"

expect_failure "incomplete passed evidence" \
  record_evidence web \
    --status passed \
    --window-opened yes \
    --resize-redraw yes \
    --clean-exit yes
require_text "incomplete passed evidence" "$last_output" \
  "passed evidence requires --input yes"

expect_failure "invalid observed value" \
  record_evidence web --input maybe
require_text "invalid observed value" "$last_output" \
  "observed values must be yes, no, or pending"

expect_success "linux capture dry run" \
  capture_evidence linux --dry-run
require_text "linux capture dry run" "$last_output" \
  "MoUI linux runtime evidence capture dry run"
require_text "linux capture dry run" "$last_output" \
  "env WINDOW_CI_HOST=linux bash scripts/check_ci.sh"
require_text "linux capture dry run" "$last_output" \
  "env WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run"
require_text "linux capture dry run" "$last_output" \
  "scripts/check_moui_runtime_log.sh linux"
require_text "linux capture dry run" "$last_output" \
  "Evidence helper: bash scripts/record_moui_evidence.sh linux --status passed"
require_text "linux capture dry run" "$last_output" \
  "--commands"
require_text "linux capture dry run" "$last_output" \
  "artifacts/moui-linux-runtime.log"
require_text "linux capture dry run" "$last_output" \
  "--runtime-log yes"
require_text "linux capture dry run" "$last_output" \
  "--consumer-command"

expect_success "windows capture dry run" \
  capture_evidence windows \
    --dry-run \
    --log /tmp/moui-windows.log \
    --host "Windows Win32 CI" \
    --date 2026-06-02 \
    --notes "reviewed Win32 dry-run evidence command"
require_text "windows capture dry run" "$last_output" \
  "MoUI windows runtime evidence capture dry run"
require_text "windows capture dry run" "$last_output" \
  "env WINDOW_CI_HOST=windows bash scripts/check_ci.sh"
require_text "windows capture dry run" "$last_output" \
  "scripts/check_moui_windows_smoke.sh --run"
require_text "windows capture dry run" "$last_output" \
  "scripts/check_moui_runtime_log.sh windows /tmp/moui-windows.log"
require_text "windows capture dry run" "$last_output" \
  "Evidence helper: bash scripts/record_moui_evidence.sh windows --status passed"
require_text "windows capture dry run" "$last_output" \
  "--host Windows\\ Win32\\ CI"
require_text "windows capture dry run" "$last_output" \
  "--date 2026-06-02"
require_text "windows capture dry run" "$last_output" \
  "--notes reviewed\\ Win32\\ dry-run\\ evidence\\ command"
require_text "windows capture dry run" "$last_output" \
  "> /tmp/moui-windows.log 2>&1"
require_text "windows capture dry run" "$last_output" \
  "--runtime-log yes"
require_text "windows capture dry run" "$last_output" \
  "--consumer-command scripts/check_moui_windows_smoke.sh --run"

expect_failure "capture requires log outside dry run" \
  capture_evidence linux
require_text "capture requires log outside dry run" "$last_output" \
  "--log is required"

expect_failure "capture rejects unknown option" \
  capture_evidence linux --dry-run --unknown
require_text "capture rejects unknown option" "$last_output" \
  "unknown option --unknown"

expect_failure "capture rejects placeholder log path" \
  capture_evidence linux --dry-run --log "<captured-log>"
require_text "capture rejects placeholder log path" "$last_output" \
  "--log must name a concrete captured transcript path"

expect_failure "capture rejects shell log path" \
  capture_evidence linux --dry-run --log "artifacts/moui.log;cat"
require_text "capture rejects shell log path" "$last_output" \
  "--log path cannot contain shell syntax"

expect_failure "mismatched capture requires matching host" \
  capture_evidence "$mismatched_backend" --log /tmp/moui-mismatched.log
require_text "mismatched capture requires matching host" "$last_output" \
  "runtime evidence capture requires a $mismatched_backend host"

platform_gaps_after="$(cksum docs/platform-gaps.md)"
if [[ "$platform_gaps_after" != "$platform_gaps_before" ]]; then
  fail "record_moui_evidence.sh modified docs/platform-gaps.md"
fi

printf 'MoUI evidence helper check passed: detected %s\n' "$actual_host"
