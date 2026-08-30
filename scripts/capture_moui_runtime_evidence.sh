#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

fail() {
  printf 'MoUI runtime evidence capture failed: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/capture_moui_runtime_evidence.sh <linux|windows> --log <path> [options]

Run the matching-host Linux/Windows MoUI evidence path end to end:
  1. run the matching WINDOW_CI_HOST branch,
  2. capture the strict runtime smoke transcript,
  3. verify the captured transcript with scripts/check_moui_runtime_log.sh,
  4. print a passed evidence entry with bash scripts/record_moui_evidence.sh.

The script writes the transcript to --log and prints the generated evidence
entry to stdout. It does not edit docs/platform-gaps.md. Non-dry-run capture
requires the matching host.

Options:
  --log <path>        Captured runtime transcript path (required unless dry-run).
  --host <label>      Host label for the evidence entry.
  --date <YYYY-MM-DD> Evidence date override.
  --notes <text>      Evidence notes override.
  --dry-run           Print commands without launching CI or runtime smoke.
EOF
}

format_command() {
  local first=1 arg
  for arg in "$@"; do
    if [[ "$first" == "1" ]]; then
      first=0
    else
      printf ' '
    fi
    printf '%q' "$arg"
  done
}

require_matching_host() {
  local actual_host
  actual_host="$(detect_window_actual_host)"
  if [[ "$actual_host" != "$backend" ]]; then
    fail "$backend runtime evidence capture requires a $backend host; detected $actual_host"
  fi
}

log_path_has_shell_syntax() {
  local path="$1"
  local backtick='`'
  [[ "$path" == *$'\n'* ||
    "$path" == *$'\r'* ||
    "$path" == *";"* ||
    "$path" == *"|"* ||
    "$path" == *"&"* ||
    "$path" == *">"* ||
    "$path" == *"<"* ||
    "$path" == *"("* ||
    "$path" == *")"* ||
    "$path" == *"$backtick"* ||
    "$path" == *'$'* ]]
}

require_concrete_log_path() {
  local path="$1"
  if [[ -z "$path" || "$path" == "pending" || "$path" == "<captured-log>" ]]; then
    fail "--log must name a concrete captured transcript path"
  fi
  if log_path_has_shell_syntax "$path"; then
    fail "--log path cannot contain shell syntax"
  fi
}

default_notes() {
  case "$1" in
    linux)
      printf 'captured by scripts/capture_moui_runtime_evidence.sh on a matching Linux Wayland/Weston host; strict input smoke observed representative keyboard text a before ready with pointer evidence, and the transcript was accepted by scripts/check_moui_runtime_log.sh'
      if [[ "${WINDOW_MOUI_LINUX_MONITOR_MODE:-strict}" == "pending-ok" ]]; then
        printf ' --linux-monitor pending-ok; current-monitor identity exempted because the compositor delivers no wl_surface.enter (ADR 0032), monitor enumeration and primary identity still verified'
      fi
      ;;
    windows)
      printf 'captured by scripts/capture_moui_runtime_evidence.sh on a matching Windows Win32 host; runtime smoke observed HWND/HINSTANCE/raw handle identity plus pointer/keyboard/ime text a before ready, and the transcript was accepted by scripts/check_moui_runtime_log.sh'
      ;;
  esac
}

backend="${1:-}"
if [[ -z "$backend" || "$backend" == "-h" || "$backend" == "--help" ]]; then
  usage
  exit 0
fi
shift

case "$backend" in
  linux|windows)
    ;;
  *)
    usage >&2
    fail "unknown backend $backend"
    ;;
esac

log_file=""
host=""
host_overridden=0
record_date=""
date_overridden=0
notes="$(default_notes "$backend")"
dry_run="${WINDOW_MOUI_EVIDENCE_DRY_RUN:-0}"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --log|--output)
      [[ "$#" -ge 2 ]] || fail "$1 requires a value"
      log_file="$2"
      shift 2
      ;;
    --host)
      [[ "$#" -ge 2 ]] || fail "--host requires a value"
      host="$2"
      host_overridden=1
      shift 2
      ;;
    --date)
      [[ "$#" -ge 2 ]] || fail "--date requires a value"
      record_date="$2"
      date_overridden=1
      shift 2
      ;;
    --notes)
      [[ "$#" -ge 2 ]] || fail "--notes requires a value"
      notes="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown option $1"
      ;;
  esac
done

if [[ -z "$log_file" ]]; then
  if [[ "$dry_run" == "1" ]]; then
    log_file="artifacts/moui-$backend-runtime.log"
  else
    fail "--log is required"
  fi
fi
require_concrete_log_path "$log_file"

ci_command=(env "WINDOW_CI_HOST=$backend" bash scripts/check_ci.sh)
case "$backend" in
  linux)
    runtime_command=(env WINDOW_MOUI_LINUX_REQUIRE_INPUT=1)
    if [[ "${WINDOW_MOUI_LINUX_MONITOR_MODE:-strict}" == "pending-ok" ]]; then
      runtime_command+=(WINDOW_MOUI_LINUX_REQUIRE_CURRENT_MONITOR=0)
    fi
    runtime_command+=(scripts/check_moui_linux_smoke.sh --run)
    ;;
  windows)
    runtime_command=(scripts/check_moui_windows_smoke.sh --run)
    ;;
esac
# WSLg Weston never delivers wl_surface.enter, so the current-monitor identity
# assertion is relaxed there; native Wayland hosts keep strict mode (ADR 0032).
log_monitor_args=()
if [[ "$backend" == "linux" && "${WINDOW_MOUI_LINUX_MONITOR_MODE:-strict}" == "pending-ok" ]]; then
  log_monitor_args=(--linux-monitor pending-ok)
fi
log_command=(scripts/check_moui_runtime_log.sh "${log_monitor_args[@]}" "$backend" "$log_file")
log_exec_command=(bash scripts/check_moui_runtime_log.sh "${log_monitor_args[@]}" "$backend" "$log_file")

ci_command_text="$(format_command "${ci_command[@]}")"
runtime_command_text="$(format_command "${runtime_command[@]}")"
log_command_text="$(format_command "${log_command[@]}")"
quoted_log_file="$(format_command "$log_file")"
commands="${ci_command_text}; ${runtime_command_text} > ${quoted_log_file} 2>&1; ${log_command_text}"

record_args=(
  "$backend"
  --status passed
  --commands "$commands"
  --window-opened yes
  --resize-redraw yes
  --input yes
  --clean-exit yes
  --runtime-log yes
  --runtime-log-command "$log_command_text"
  --consumer-command "$runtime_command_text"
  --surface yes
  --redraw yes
  --resize-scale yes
  --consumer-input yes
  --text-input yes
  --renderer-handle yes
  --monitor-cursor yes
  --clean-shutdown yes
  --notes "$notes"
)
if [[ "$host_overridden" == "1" ]]; then
  record_args+=(--host "$host")
fi
if [[ "$date_overridden" == "1" ]]; then
  record_args+=(--date "$record_date")
fi
record_command=(bash scripts/record_moui_evidence.sh "${record_args[@]}")
record_command_text="$(format_command "${record_command[@]}")"

if [[ "$dry_run" == "1" ]]; then
  printf 'MoUI %s runtime evidence capture dry run\n' "$backend"
  printf 'Log: %s\n' "$log_file"
  printf 'Command: %s\n' "$ci_command_text"
  printf 'Command: %s > %s 2>&1\n' "$runtime_command_text" "$quoted_log_file"
  printf 'Command: %s\n' "$log_command_text"
  printf 'Evidence helper: %s\n' "$record_command_text"
  printf 'Evidence runtime log: --runtime-log yes --runtime-log-command %s\n' "$log_command_text"
  printf 'Evidence consumer command: --consumer-command %s\n' "$runtime_command_text"
  printf 'Evidence consumer fields: surface/redraw/resize-scale/input/text/renderer-handle/monitor-cursor/clean-shutdown=yes\n'
  printf 'Dry run only; commands not launched\n'
  exit 0
fi

require_matching_host
log_dir="$(dirname "$log_file")"
if [[ "$log_dir" != "." ]]; then
  mkdir -p "$log_dir"
fi

printf 'Running matching-host CI: %s\n' "$ci_command_text" >&2
"${ci_command[@]}"

printf 'Capturing runtime transcript: %s\n' "$log_file" >&2
set +e
"${runtime_command[@]}" >"$log_file" 2>&1
runtime_status=$?
set -e

printf '%s\n' "----- captured MoUI $backend runtime transcript: $log_file -----"
cat "$log_file"
printf '%s\n' "----- end captured MoUI $backend runtime transcript -----"

if [[ "$runtime_status" -ne 0 ]]; then
  fail "runtime smoke exited with status $runtime_status; transcript saved to $log_file"
fi

"${log_exec_command[@]}"

printf 'MoUI %s runtime evidence entry:\n' "$backend"
bash scripts/record_moui_evidence.sh "${record_args[@]}"
