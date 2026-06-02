#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

fail() {
  printf 'MoUI evidence record failed: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/record_moui_evidence.sh <backend> [options]

Generate a platform-gaps evidence entry for a matching-host smoke run. The
script prints to stdout only; paste the result into docs/platform-gaps.md after
reviewing whether the evidence is strong enough to change backend status.
`--status passed` requires explicit `yes` values for window creation,
resize/redraw, representative input, and clean exit.
Any observed MoUI consumer evidence requires `--consumer-command`.

Backends:
  macos | web | linux | windows

Options:
  --status <passed|failed|pending>
  --host <description>
  --date <YYYY-MM-DD>
  --commands <command summary>
  --window-opened <yes|no|pending>
  --resize-redraw <yes|no|pending>
  --input <yes|no|pending>
  --clean-exit <yes|no|pending>
  --consumer-command <command or pending>
  --surface <yes|no|pending>
  --redraw <yes|no|pending>
  --resize-scale <yes|no|pending>
  --consumer-input <yes|no|pending>
  --text-input <yes|no|pending>
  --renderer-handle <yes|no|pending>
  --monitor-cursor <yes|no|pending>
  --clean-shutdown <yes|no|pending>
  --notes <free-form notes>

Passed native-backend evidence must be generated on the matching host, or use
--host to name the remote matching host where the smoke was actually observed.
EOF
}

matching_host_label() {
  case "$1" in
    macos) printf 'macOS' ;;
    linux) printf 'Linux' ;;
    windows) printf 'Windows' ;;
    web) printf 'Web' ;;
  esac
}

actual_host_description() {
  local detected
  detected="$(detect_window_actual_host)"
  case "$detected" in
    macos)
      printf 'macOS (%s)' "$(uname -m 2>/dev/null || printf unknown)"
      ;;
    linux)
      if command -v lsb_release >/dev/null 2>&1; then
        printf 'Linux (%s)' "$(lsb_release -ds 2>/dev/null || uname -m)"
      else
        printf 'Linux (%s)' "$(uname -m 2>/dev/null || printf unknown)"
      fi
      ;;
    windows)
      printf 'Windows (%s)' "${OS:-unknown}"
      ;;
    *)
      printf 'unknown host (%s)' "$(uname -s 2>/dev/null || printf unknown)"
      ;;
  esac
}

default_commands() {
  local backend="$1"
  case "$backend" in
    macos)
      printf 'WINDOW_CI_HOST=macos bash scripts/check_ci.sh; scripts/check_moui_macos_smoke.sh --run'
      ;;
    web)
      printf 'bash scripts/check_ci.sh; scripts/check_moui_web_smoke.sh; browser MoUI smoke page'
      ;;
    linux)
      printf 'WINDOW_CI_HOST=linux bash scripts/check_ci.sh; scripts/smoke_runtime.sh linux; WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run'
      ;;
    windows)
      printf 'WINDOW_CI_HOST=windows bash scripts/check_ci.sh; scripts/smoke_runtime.sh windows; scripts/check_moui_windows_smoke.sh --run'
      ;;
  esac
}

valid_yes_no_pending() {
  case "$1" in
    yes|no|pending) return 0 ;;
    *) return 1 ;;
  esac
}

require_passed_observed_yes() {
  local option="$1"
  local value="$2"
  if [[ "$status" == "passed" && "$value" != "yes" ]]; then
    fail "passed evidence requires $option yes; got $value"
  fi
}

consumer_evidence_observed() {
  [[ "$surface" != "pending" ||
    "$redraw" != "pending" ||
    "$resize_scale" != "pending" ||
    "$consumer_input" != "pending" ||
    "$text_input" != "pending" ||
    "$renderer_handle" != "pending" ||
    "$monitor_cursor" != "pending" ||
    "$clean_shutdown" != "pending" ]]
}

backend="${1:-}"
if [[ -z "$backend" || "$backend" == "-h" || "$backend" == "--help" ]]; then
  usage
  exit 0
fi
shift

case "$backend" in
  macos|web|linux|windows)
    ;;
  *)
    usage >&2
    fail "unknown backend $backend"
    ;;
esac

status="pending"
host="$(actual_host_description)"
host_was_overridden=0
record_date="$(date +%F)"
commands="$(default_commands "$backend")"
window_opened="pending"
resize_redraw="pending"
input="pending"
clean_exit="pending"
consumer_command="pending"
surface="pending"
redraw="pending"
resize_scale="pending"
consumer_input="pending"
text_input="pending"
renderer_handle="pending"
monitor_cursor="pending"
clean_shutdown="pending"
notes="toolchain/compositor/runtime details pending"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --status)
      [[ "$#" -ge 2 ]] || fail "--status requires a value"
      status="$2"
      shift 2
      ;;
    --host)
      [[ "$#" -ge 2 ]] || fail "--host requires a value"
      host="$2"
      host_was_overridden=1
      shift 2
      ;;
    --date)
      [[ "$#" -ge 2 ]] || fail "--date requires a value"
      record_date="$2"
      shift 2
      ;;
    --commands)
      [[ "$#" -ge 2 ]] || fail "--commands requires a value"
      commands="$2"
      shift 2
      ;;
    --window-opened)
      [[ "$#" -ge 2 ]] || fail "--window-opened requires a value"
      window_opened="$2"
      shift 2
      ;;
    --resize-redraw)
      [[ "$#" -ge 2 ]] || fail "--resize-redraw requires a value"
      resize_redraw="$2"
      shift 2
      ;;
    --input)
      [[ "$#" -ge 2 ]] || fail "--input requires a value"
      input="$2"
      shift 2
      ;;
    --clean-exit)
      [[ "$#" -ge 2 ]] || fail "--clean-exit requires a value"
      clean_exit="$2"
      shift 2
      ;;
    --consumer-command)
      [[ "$#" -ge 2 ]] || fail "--consumer-command requires a value"
      consumer_command="$2"
      shift 2
      ;;
    --surface)
      [[ "$#" -ge 2 ]] || fail "--surface requires a value"
      surface="$2"
      shift 2
      ;;
    --redraw)
      [[ "$#" -ge 2 ]] || fail "--redraw requires a value"
      redraw="$2"
      shift 2
      ;;
    --resize-scale)
      [[ "$#" -ge 2 ]] || fail "--resize-scale requires a value"
      resize_scale="$2"
      shift 2
      ;;
    --consumer-input)
      [[ "$#" -ge 2 ]] || fail "--consumer-input requires a value"
      consumer_input="$2"
      shift 2
      ;;
    --text-input)
      [[ "$#" -ge 2 ]] || fail "--text-input requires a value"
      text_input="$2"
      shift 2
      ;;
    --renderer-handle)
      [[ "$#" -ge 2 ]] || fail "--renderer-handle requires a value"
      renderer_handle="$2"
      shift 2
      ;;
    --monitor-cursor)
      [[ "$#" -ge 2 ]] || fail "--monitor-cursor requires a value"
      monitor_cursor="$2"
      shift 2
      ;;
    --clean-shutdown)
      [[ "$#" -ge 2 ]] || fail "--clean-shutdown requires a value"
      clean_shutdown="$2"
      shift 2
      ;;
    --notes)
      [[ "$#" -ge 2 ]] || fail "--notes requires a value"
      notes="$2"
      shift 2
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

case "$status" in
  passed|failed|pending)
    ;;
  *)
    fail "invalid --status $status (expected passed, failed, or pending)"
    ;;
esac

for value in \
  "$window_opened" \
  "$resize_redraw" \
  "$input" \
  "$clean_exit" \
  "$surface" \
  "$redraw" \
  "$resize_scale" \
  "$consumer_input" \
  "$text_input" \
  "$renderer_handle" \
  "$monitor_cursor" \
  "$clean_shutdown"
do
  valid_yes_no_pending "$value" ||
    fail "observed values must be yes, no, or pending; got $value"
done

if [[ ! "$record_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  fail "--date must use YYYY-MM-DD"
fi

if [[ "$consumer_command" =~ ^[[:space:]]*$ ]]; then
  fail "--consumer-command cannot be empty"
fi

if consumer_evidence_observed && [[ "$consumer_command" == "pending" ]]; then
  fail "consumer evidence fields require --consumer-command"
fi

require_passed_observed_yes "--window-opened" "$window_opened"
require_passed_observed_yes "--resize-redraw" "$resize_redraw"
require_passed_observed_yes "--input" "$input"
require_passed_observed_yes "--clean-exit" "$clean_exit"

actual_host="$(detect_window_actual_host)"
if [[ "$status" == "passed" && "$backend" != "web" && "$actual_host" != "$backend" ]]; then
  if [[ "$host_was_overridden" != "1" ]]; then
    fail "passed $backend evidence requires a $backend host; detected $actual_host. Use --host to name the remote matching host if this records external evidence."
  fi
  expected_label="$(matching_host_label "$backend")"
  if [[ "$host" != *"$expected_label"* ]]; then
    fail "--host for passed $backend evidence must name a matching $expected_label host"
  fi
fi

cat <<EOF
- ${backend} build/runtime smoke on ${host}, ${record_date}: ${status}.
  Commands: ${commands}.
  Observed: window opened=${window_opened}, resize/redraw=${resize_redraw},
  representative input=${input}, clean exit=${clean_exit}.
  MoUI consumer: command=${consumer_command}, surface=${surface},
  redraw=${redraw}, resize/scale=${resize_scale}, input=${consumer_input},
  text/IME=${text_input}, renderer handle=${renderer_handle},
  monitor/cursor=${monitor_cursor}, clean shutdown=${clean_shutdown}.
  Notes: ${notes}.
EOF
