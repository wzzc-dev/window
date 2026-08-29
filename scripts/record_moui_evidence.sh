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
Linux/Windows passed evidence requires `--runtime-log yes` after validating the
captured transcript.
Any observed MoUI consumer evidence requires `--consumer-command`. Output
includes a computed MoUI consumer status so runtime-only evidence is not
confused with downstream consumer readiness.

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
  --runtime-log <yes|no|pending>
  --runtime-log-command <command or pending>
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

consumer_status() {
  local result="passed"
  local value
  for value in \
    "$surface" \
    "$redraw" \
    "$resize_scale" \
    "$consumer_input" \
    "$text_input" \
    "$renderer_handle" \
    "$clean_shutdown"
  do
    if [[ "$value" == "no" ]]; then
      printf 'failed'
      return
    fi
    if [[ "$value" != "yes" ]]; then
      result="pending"
    fi
  done

  if [[ "$monitor_cursor" == "no" ]]; then
    printf 'failed'
    return
  fi
  if [[ "$backend" != "web" && "$monitor_cursor" != "yes" ]]; then
    result="pending"
  fi

  if [[ "$consumer_command" == "pending" ]]; then
    result="pending"
  fi
  printf '%s' "$result"
}

runtime_log_command_runs_verifier() {
  local command="$1"
  local log_backend="$2"
  local verifier="scripts/check_moui_runtime_log.sh"
  local -a args
  local index

  if runtime_log_command_has_shell_syntax "$command"; then
    return 1
  fi

  IFS=' ' read -a args <<<"$command"
  if [[ "${#args[@]}" -eq 0 ]]; then
    return 1
  fi

  index=0
  if [[ "${args[$index]:-}" == "bash" ]]; then
    index=$((index + 1))
  fi

  if [[ "${args[$index]:-}" != "$verifier" ]]; then
    return 1
  fi
  index=$((index + 1))

  case "$log_backend" in
    linux)
      if [[ "${args[$index]:-}" == "--linux-input" ]]; then
        case "${args[$((index + 1))]:-}" in
          strict|pending-ok)
            index=$((index + 2))
            ;;
          *)
            return 1
            ;;
        esac
      fi
      [[ "${args[$index]:-}" == "linux" ]] || return 1
      ;;
    windows)
      [[ "${args[$index]:-}" == "windows" ]] || return 1
      ;;
    *)
      return 1
      ;;
  esac

  index=$((index + 1))
  runtime_log_path_token_is_concrete "${args[$index]:-}" || return 1
  index=$((index + 1))
  [[ "$index" -eq "${#args[@]}" ]]
}

runtime_log_command_has_shell_syntax() {
  local command="$1"
  local backtick='`'
  [[ "$command" == *$'\n'* ||
    "$command" == *$'\r'* ||
    "$command" == *";"* ||
    "$command" == *"|"* ||
    "$command" == *"&"* ||
    "$command" == *">"* ||
    "$command" == *"<"* ||
    "$command" == *"("* ||
    "$command" == *")"* ||
    "$command" == *"$backtick"* ||
    "$command" == *'$'* ||
    "$command" == *'$('* ||
    "$command" == *'${'* ]]
}

runtime_log_path_token_is_concrete() {
  local token="$1"
  [[ -n "$token" && "$token" != "pending" && "$token" != "<captured-log>" ]]
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
runtime_log="pending"
runtime_log_command="pending"
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
    --runtime-log)
      [[ "$#" -ge 2 ]] || fail "--runtime-log requires a value"
      runtime_log="$2"
      shift 2
      ;;
    --runtime-log-command)
      [[ "$#" -ge 2 ]] || fail "--runtime-log-command requires a value"
      runtime_log_command="$2"
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
  "$runtime_log" \
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

if [[ "$host" =~ ^[[:space:]]*$ ]]; then
  fail "--host cannot be empty"
fi

if [[ "$commands" =~ ^[[:space:]]*$ ]]; then
  fail "--commands cannot be empty"
fi

if [[ "$consumer_command" =~ ^[[:space:]]*$ ]]; then
  fail "--consumer-command cannot be empty"
fi

if [[ "$runtime_log_command" =~ ^[[:space:]]*$ ]]; then
  fail "--runtime-log-command cannot be empty"
fi

if [[ "$runtime_log" != "pending" && "$runtime_log_command" == "pending" ]]; then
  fail "runtime log evidence requires --runtime-log-command"
fi

if [[ "$runtime_log" == "yes" && ( "$backend" == "linux" || "$backend" == "windows" ) ]]; then
  expected_runtime_log_command="scripts/check_moui_runtime_log.sh $backend"
  if ! runtime_log_command_runs_verifier "$runtime_log_command" "$backend"; then
    fail "runtime log evidence for $backend requires --runtime-log-command to run $expected_runtime_log_command as the command invocation"
  fi
fi

if [[ "$status" == "passed" && "$backend" == "linux" &&
  "$runtime_log" == "yes" &&
  "$runtime_log_command" == *"--linux-input pending-ok"* ]]; then
  fail "passed linux evidence requires strict runtime log verification without --linux-input pending-ok"
fi

if consumer_evidence_observed && [[ "$consumer_command" == "pending" ]]; then
  fail "consumer evidence fields require --consumer-command"
fi

require_passed_observed_yes "--window-opened" "$window_opened"
require_passed_observed_yes "--resize-redraw" "$resize_redraw"
require_passed_observed_yes "--input" "$input"
require_passed_observed_yes "--clean-exit" "$clean_exit"

consumer_status_value="$(consumer_status)"

actual_host="$(detect_window_actual_host)"
if [[ "$status" == "passed" && "$backend" != "web" && "$actual_host" != "$backend" ]]; then
  if [[ "$host_was_overridden" != "1" ]]; then
    fail "passed $backend evidence requires a $backend host; detected $actual_host. Use --host to name the remote matching host if this records external evidence."
  fi
  expected_label="$(matching_host_label "$backend")"
  if [[ "$host" != *"$expected_label"* ]]; then
    fail "--host for passed $backend evidence must name a matching $expected_label host"
  fi
  if [[ "$backend" == "linux" || "$backend" == "windows" ]]; then
    if [[ "$runtime_log" != "yes" ]]; then
      fail "remote passed $backend evidence requires --runtime-log yes after scripts/check_moui_runtime_log.sh $backend"
    fi
    if [[ "$runtime_log_command" == "pending" ]]; then
      fail "remote passed $backend evidence requires --runtime-log-command"
    fi
  fi
fi

if [[ "$status" == "passed" && ( "$backend" == "linux" || "$backend" == "windows" ) ]]; then
  if [[ "$runtime_log" != "yes" ]]; then
    fail "passed $backend evidence requires --runtime-log yes after scripts/check_moui_runtime_log.sh $backend"
  fi
  if [[ "$runtime_log_command" == "pending" ]]; then
    fail "passed $backend evidence requires --runtime-log-command"
  fi
fi

cat <<EOF
- ${backend} build/runtime smoke on ${host}, ${record_date}: ${status}.
  Commands: ${commands}.
  Observed: window opened=${window_opened}, resize/redraw=${resize_redraw},
  representative input=${input}, clean exit=${clean_exit}.
  Runtime log: verified=${runtime_log}, command=${runtime_log_command}.
  MoUI consumer: status=${consumer_status_value}, command=${consumer_command}, surface=${surface},
  redraw=${redraw}, resize/scale=${resize_scale}, input=${consumer_input},
  text/IME=${text_input}, renderer handle=${renderer_handle},
  monitor/cursor=${monitor_cursor}, clean shutdown=${clean_shutdown}.
  Notes: ${notes}.
EOF
