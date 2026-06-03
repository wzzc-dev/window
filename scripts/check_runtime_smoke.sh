#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

fail() {
  printf 'Runtime smoke helper check failed: %s\n' "$1" >&2
  exit 1
}

require_text() {
  local label="$1"
  local output="$2"
  local text="$3"
  [[ "$output" == *"$text"* ]] ||
    fail "$label output did not contain expected text: $text"
}

run_dry_smoke() {
  local backend="$1"
  WINDOW_RUNTIME_SMOKE_DRY_RUN=1 \
    WINDOW_RUNTIME_SMOKE_SKIP_WEB_ASSETS=1 \
    scripts/smoke_runtime.sh "$backend" 2>&1
}

run_live_smoke() {
  local backend="$1"
  WINDOW_RUNTIME_SMOKE_SKIP_WEB_ASSETS=1 \
    scripts/smoke_runtime.sh "$backend" 2>&1
}

write_sample_log() {
  local backend="$1"
  local path="$2"
  local linux_input_mode="${3:-strict}"
  case "$backend" in
    linux)
      cat >"$path" <<'EOF'
MOUILinuxSmoke: surface size=320x180 scale=1
MOUILinuxSmoke: handles wl_display=0x101 wl_surface=0x202 xdg_surface=0x303 xdg_toplevel=0x404
MOUILinuxSmoke: present result=0
MOUILinuxSmoke: monitors count=1 primary=true primary_id=0x505 current=true current_id=0x505
MOUILinuxSmoke: cursor Icon(Text)
MOUILinuxSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true
MOUILinuxSmoke: resize requested size=400x240
MOUILinuxSmoke: resize size=400x240
MOUILinuxSmoke: redraw pre_present_notify
MOUILinuxSmoke: pointer x=24 y=32
MOUILinuxSmoke: keyboard text=a
MOUILinuxSmoke: ready input=observed
MOUILinuxSmoke: destroy requested
MOUILinuxSmoke: destroyed
MOUILinuxSmoke: finished
EOF
      if [[ "$linux_input_mode" == "pending-ok" ]]; then
        sed -e '/MOUILinuxSmoke: pointer/d' \
          -e '/MOUILinuxSmoke: keyboard text=a/d' \
          -e 's/MOUILinuxSmoke: ready input=observed/MOUILinuxSmoke: ready input=pending/' \
          "$path" >"$path.pending"
        mv "$path.pending" "$path"
      fi
      ;;
    windows)
      cat >"$path" <<'EOF'
MOUIWindowsSmoke: surface size=320x180 scale=1
MOUIWindowsSmoke: handle hwnd=0x111 hinstance=0x222 raw_display=0x222 raw_window=0x111
MOUIWindowsSmoke: monitors count=1 primary=true primary_id=0x333 current=true current_id=0x333
MOUIWindowsSmoke: cursor Icon(Text)
MOUIWindowsSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true
MOUIWindowsSmoke: resize requested size=400x240
MOUIWindowsSmoke: resize size=400x240
MOUIWindowsSmoke: redraw pre_present_notify
MOUIWindowsSmoke: pointer x=24 y=32
MOUIWindowsSmoke: keyboard key=a
MOUIWindowsSmoke: ime text=a
MOUIWindowsSmoke: ready
MOUIWindowsSmoke: destroy requested
MOUIWindowsSmoke: destroyed
MOUIWindowsSmoke: finished
EOF
      ;;
    *)
      fail "unknown sample log backend $backend"
      ;;
  esac
}

expect_log_success() {
  local backend="$1"
  local linux_input_mode="${2:-strict}"
  local log_file output status verifier_args
  log_file="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log.XXXXXX")"
  write_sample_log "$backend" "$log_file" "$linux_input_mode"
  verifier_args=("$backend" "$log_file")
  if [[ "$backend" == "linux" && "$linux_input_mode" == "pending-ok" ]]; then
    verifier_args=(--linux-input pending-ok "$backend" "$log_file")
  fi
  set +e
  output="$(bash scripts/check_moui_runtime_log.sh "${verifier_args[@]}" 2>&1)"
  status=$?
  set -e
  rm -f "$log_file"
  if [[ "$status" -ne 0 ]]; then
    fail "$backend runtime log verifier failed with status $status: $output"
  fi
  require_text "$backend runtime log verifier" "$output" \
    "MoUI $backend runtime log check passed"
}

expect_log_failure() {
  local backend="$1"
  local pattern="$2"
  local replacement="$3"
  local expected="$4"
  local linux_input_mode="${5:-strict}"
  local log_file edited_log output status verifier_args
  log_file="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log.XXXXXX")"
  edited_log="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log-edited.XXXXXX")"
  write_sample_log "$backend" "$log_file" "$linux_input_mode"
  sed "s/$pattern/$replacement/g" "$log_file" >"$edited_log"
  verifier_args=("$backend" "$edited_log")
  if [[ "$backend" == "linux" && "$linux_input_mode" == "pending-ok" ]]; then
    verifier_args=(--linux-input pending-ok "$backend" "$edited_log")
  fi
  set +e
  output="$(bash scripts/check_moui_runtime_log.sh "${verifier_args[@]}" 2>&1)"
  status=$?
  set -e
  rm -f "$log_file" "$edited_log"
  if [[ "$status" -eq 0 ]]; then
    fail "$backend runtime log verifier unexpectedly accepted edited log: $output"
  fi
  require_text "$backend runtime log verifier failure" "$output" "$expected"
}

expect_log_order_failure() {
  local backend="$1"
  local first="$2"
  local second="$3"
  local expected="$4"
  local linux_input_mode="${5:-strict}"
  local log_file edited_log output status verifier_args
  log_file="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log.XXXXXX")"
  edited_log="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log-edited.XXXXXX")"
  write_sample_log "$backend" "$log_file" "$linux_input_mode"
  awk -v first="$first" -v second="$second" '
    $0 == first { saved = $0; next }
    saved != "" && $0 == second { print second; print saved; saved = ""; next }
    saved != "" { print saved; saved = "" }
    { print }
    END { if (saved != "") print saved }
  ' "$log_file" >"$edited_log"
  verifier_args=("$backend" "$edited_log")
  if [[ "$backend" == "linux" && "$linux_input_mode" == "pending-ok" ]]; then
    verifier_args=(--linux-input pending-ok "$backend" "$edited_log")
  fi
  set +e
  output="$(bash scripts/check_moui_runtime_log.sh "${verifier_args[@]}" 2>&1)"
  status=$?
  set -e
  rm -f "$log_file" "$edited_log"
  if [[ "$status" -eq 0 ]]; then
    fail "$backend runtime log verifier unexpectedly accepted reordered log: $output"
  fi
  require_text "$backend runtime log verifier order failure" "$output" "$expected"
}

expect_log_move_after_failure() {
  local backend="$1"
  local moved_line="$2"
  local after_line="$3"
  local expected="$4"
  local linux_input_mode="${5:-strict}"
  local log_file edited_log output status verifier_args
  log_file="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log.XXXXXX")"
  edited_log="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log-edited.XXXXXX")"
  write_sample_log "$backend" "$log_file" "$linux_input_mode"
  awk -v moved="$moved_line" -v after="$after_line" '
    $0 == moved { saved = $0; next }
    { print }
    saved != "" && $0 == after { print saved; saved = "" }
    END { if (saved != "") print saved }
  ' "$log_file" >"$edited_log"
  verifier_args=("$backend" "$edited_log")
  if [[ "$backend" == "linux" && "$linux_input_mode" == "pending-ok" ]]; then
    verifier_args=(--linux-input pending-ok "$backend" "$edited_log")
  fi
  set +e
  output="$(bash scripts/check_moui_runtime_log.sh "${verifier_args[@]}" 2>&1)"
  status=$?
  set -e
  rm -f "$log_file" "$edited_log"
  if [[ "$status" -eq 0 ]]; then
    fail "$backend runtime log verifier unexpectedly accepted moved log evidence: $output"
  fi
  require_text "$backend runtime log verifier moved evidence failure" "$output" "$expected"
}

expect_log_move_between_failure() {
  local backend="$1"
  local moved_line="$2"
  local after_line="$3"
  local expected="$4"
  local linux_input_mode="${5:-strict}"
  local log_file edited_log output status verifier_args
  log_file="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log.XXXXXX")"
  edited_log="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log-edited.XXXXXX")"
  write_sample_log "$backend" "$log_file" "$linux_input_mode"
  awk -v moved="$moved_line" -v after="$after_line" '
    $0 == moved { saved = $0; next }
    {
      print
      if (saved != "" && $0 == after) {
        print saved
        saved = ""
      }
    }
    END { if (saved != "") print saved }
  ' "$log_file" >"$edited_log"
  verifier_args=("$backend" "$edited_log")
  if [[ "$backend" == "linux" && "$linux_input_mode" == "pending-ok" ]]; then
    verifier_args=(--linux-input pending-ok "$backend" "$edited_log")
  fi
  set +e
  output="$(bash scripts/check_moui_runtime_log.sh "${verifier_args[@]}" 2>&1)"
  status=$?
  set -e
  rm -f "$log_file" "$edited_log"
  if [[ "$status" -eq 0 ]]; then
    fail "$backend runtime log verifier unexpectedly accepted moved log evidence: $output"
  fi
  require_text "$backend runtime log verifier moved evidence failure" "$output" "$expected"
}

expect_log_prefix_rejection() {
  local backend="$1"
  local pattern="$2"
  local replacement="$3"
  local expected="$4"
  local linux_input_mode="${5:-strict}"
  expect_log_failure "$backend" "$pattern" "$replacement" "$expected" "$linux_input_mode"
}

expect_log_appended_failure() {
  local backend="$1"
  local appended_line="$2"
  local expected="$3"
  local linux_input_mode="${4:-strict}"
  local log_file output status verifier_args
  log_file="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log.XXXXXX")"
  write_sample_log "$backend" "$log_file" "$linux_input_mode"
  printf '%s\n' "$appended_line" >>"$log_file"
  verifier_args=("$backend" "$log_file")
  if [[ "$backend" == "linux" && "$linux_input_mode" == "pending-ok" ]]; then
    verifier_args=(--linux-input pending-ok "$backend" "$log_file")
  fi
  set +e
  output="$(bash scripts/check_moui_runtime_log.sh "${verifier_args[@]}" 2>&1)"
  status=$?
  set -e
  rm -f "$log_file"
  if [[ "$status" -eq 0 ]]; then
    fail "$backend runtime log verifier unexpectedly accepted appended failure line: $output"
  fi
  require_text "$backend runtime log verifier appended failure" "$output" "$expected"
}

expect_log_appended_line_failure() {
  local backend="$1"
  local appended_line="$2"
  local expected="$3"
  local linux_input_mode="${4:-strict}"
  local log_file output status verifier_args
  log_file="$(mktemp "${TMPDIR:-/tmp}/moui-${backend}-runtime-log.XXXXXX")"
  write_sample_log "$backend" "$log_file" "$linux_input_mode"
  printf '%s\n' "$appended_line" >>"$log_file"
  verifier_args=("$backend" "$log_file")
  if [[ "$backend" == "linux" && "$linux_input_mode" == "pending-ok" ]]; then
    verifier_args=(--linux-input pending-ok "$backend" "$log_file")
  fi
  set +e
  output="$(bash scripts/check_moui_runtime_log.sh "${verifier_args[@]}" 2>&1)"
  status=$?
  set -e
  rm -f "$log_file"
  if [[ "$status" -eq 0 ]]; then
    fail "$backend runtime log verifier unexpectedly accepted appended line: $output"
  fi
  require_text "$backend runtime log verifier appended line failure" "$output" "$expected"
}

expect_success() {
  local backend="$1"
  local output status
  set +e
  output="$(run_dry_smoke "$backend")"
  status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    fail "$backend dry run failed with status $status: $output"
  fi
  require_text "$backend dry run" "$output" "Runtime smoke checklist for $backend:"
  require_text "$backend dry run" "$output" "Dry run only; command not launched"
  if [[ "$backend" == "web" ]]; then
    require_text "$backend dry run" "$output" \
      "examples/moui_web_smoke/index.html for MoUI consumer evidence"
  elif [[ "$backend" == "linux" ]]; then
    require_text "$backend dry run" "$output" \
      "Command: env WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run"
    require_text "$backend dry run" "$output" \
      "representative input text"
  elif [[ "$backend" == "windows" ]]; then
    require_text "$backend dry run" "$output" \
      "Command: scripts/check_moui_windows_smoke.sh --run"
    require_text "$backend dry run" "$output" \
      "HWND/HINSTANCE/raw handles"
  fi
}

expect_dry_failure() {
  local backend="$1"
  local output status
  set +e
  output="$(run_dry_smoke "$backend")"
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    fail "$backend dry run unexpectedly succeeded: $output"
  fi
  require_text "$backend dry run failure" "$output" "Runtime smoke failed:"
}

expect_live_failure() {
  local backend="$1"
  local output status
  set +e
  output="$(run_live_smoke "$backend")"
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    fail "$backend live smoke unexpectedly succeeded: $output"
  fi
  require_text "$backend live smoke failure" "$output" "Runtime smoke failed:"
}

actual_host="$(detect_window_actual_host)"
case "$actual_host" in
  macos|linux|windows|none)
    ;;
  *)
    fail "detect_window_actual_host returned unexpected value $actual_host"
    ;;
esac

help_output="$(scripts/smoke_runtime.sh --help)"
require_text "help" "$help_output" "Usage: scripts/smoke_runtime.sh <backend>"

for backend in macos web linux windows; do
  expect_success "$backend"
done

expect_log_success linux
expect_log_success linux pending-ok
expect_log_success windows
expect_log_failure linux \
  "surface size=320x180 scale=1" \
  "surface size=0x180 scale=1" \
  "surface width must be positive"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: surface size=320x180 scale=1" \
  "log must contain exactly one line with MOUILinuxSmoke: surface size=, got 2"
expect_log_failure windows \
  "surface size=320x180 scale=1" \
  "surface size=320x180 scale=0" \
  "surface scale must be positive"
expect_log_appended_line_failure windows \
  "MOUIWindowsSmoke: surface size=320x180 scale=1" \
  "log must contain exactly one line with MOUIWindowsSmoke: surface size=, got 2"
expect_log_failure linux \
  "monitors count=1 primary=true" \
  "monitors count=0 primary=true" \
  "monitor count must be positive"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: monitors count=1 primary=true primary_id=0x505 current=true current_id=0x505" \
  "log must contain exactly one line with MOUILinuxSmoke: monitors count=, got 2"
expect_log_failure linux \
  "primary=true primary_id=0x505" \
  "primary=false primary_id=0x505" \
  "monitor line did not report primary=true"
expect_log_failure linux \
  "wl_display=0x101" \
  "wl_display=0x0" \
  "wl_display must be nonzero"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: handles wl_display=0x101 wl_surface=0x202 xdg_surface=0x303 xdg_toplevel=0x404" \
  "log must contain exactly one line with MOUILinuxSmoke: handles wl_display=0x, got 2"
expect_log_failure linux \
  "wl_display=0x101" \
  "wl_display=0x101junk" \
  "field wl_display must be a hex value"
expect_log_failure linux \
  "primary_id=0x505" \
  "primary_id=0x0" \
  "primary_id must be nonzero"
expect_log_failure linux \
  "current=true current_id=0x505" \
  "current=true current_id=0x0" \
  "current_id must be nonzero"
expect_log_move_between_failure linux \
  "MOUILinuxSmoke: present result=0" \
  "MOUILinuxSmoke: ready input=observed" \
  "log did not contain MOUILinuxSmoke: present result=0 before MOUILinuxSmoke: ready"
expect_log_prefix_rejection linux \
  "MOUILinuxSmoke: present result=0" \
  "note MOUILinuxSmoke: present result=0" \
  "log must contain exactly one line equal to MOUILinuxSmoke: present result=0, got 0"
expect_log_failure linux \
  "MOUILinuxSmoke: ready input=pending" \
  "MOUILinuxSmoke: ready core" \
  "log must contain exactly one line with MOUILinuxSmoke: ready input=, got 0" \
  pending-ok
expect_log_failure linux \
  "MOUILinuxSmoke: ready input=pending" \
  "MOUILinuxSmoke: ready input=unknown" \
  "Linux ready input state must be observed in strict mode or observed/pending in pending-ok mode" \
  pending-ok
expect_log_failure linux \
  "MOUILinuxSmoke: ready input=pending" \
  "MOUILinuxSmoke: ready input=observed" \
  "Linux ready input=observed requires pointer and keyboard evidence" \
  pending-ok
expect_log_failure linux \
  "MOUILinuxSmoke: pointer x=24 y=32" \
  "MOUILinuxSmoke: pointer" \
  "missing field x"
expect_log_failure linux \
  "MOUILinuxSmoke: pointer x=24 y=32" \
  "MOUILinuxSmoke: pointer x=24px y=32" \
  "field x must be an integer"
expect_log_failure linux \
  "MOUILinuxSmoke: resize size=400x240" \
  "MOUILinuxSmoke: resize size=400x240px" \
  "field size must be WIDTHxHEIGHT"
expect_log_failure linux \
  "MOUILinuxSmoke: resize requested size=400x240" \
  "MOUILinuxSmoke: resize requested size=0x240" \
  "resize request width must be positive"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: resize requested size=400x240" \
  "log must contain exactly one line with MOUILinuxSmoke: resize requested size=, got 2"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: cursor Icon(Text)" \
  "log must contain exactly one line equal to MOUILinuxSmoke: cursor Icon(Text), got 2"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true" \
  "log must contain exactly one line equal to MOUILinuxSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true, got 2"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: present result=0" \
  "log must contain exactly one line equal to MOUILinuxSmoke: present result=0, got 2"
expect_log_appended_failure linux \
  "MOUILinuxSmoke: ime probe enable failed boom" \
  "log contained MOUILinuxSmoke failure line"
expect_log_appended_line_failure linux \
  "MOUIWindowsSmoke: finished" \
  "log contained forbidden text: MOUIWindowsSmoke:"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: ready input=observed" \
  "log must contain exactly one line with MOUILinuxSmoke: ready input=, got 2"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: finished" \
  "log must contain exactly one line equal to MOUILinuxSmoke: finished, got 2"
expect_log_failure linux \
  "MOUILinuxSmoke: destroyed" \
  "MOUILinuxSmoke: destroyed later" \
  "log must contain exactly one line equal to MOUILinuxSmoke: destroyed, got 0"
expect_log_appended_line_failure linux \
  "MOUILinuxSmoke: pointer x=1 y=2" \
  "last MOUILinuxSmoke line must be MOUILinuxSmoke: finished"
expect_log_order_failure linux \
  "MOUILinuxSmoke: keyboard text=a" \
  "MOUILinuxSmoke: ready input=observed" \
  "log did not contain exact line MOUILinuxSmoke: keyboard text=a before exact line MOUILinuxSmoke: ready input=observed"
expect_log_failure linux \
  "MOUILinuxSmoke: keyboard text=a" \
  "MOUILinuxSmoke: keyboard text=ab" \
  "log must contain exactly one line equal to MOUILinuxSmoke: keyboard text=a, got 0"
expect_log_failure windows \
  "MOUIWindowsSmoke: resize size=400x240" \
  "MOUIWindowsSmoke: resize delivered=400x240" \
  "log did not contain a line with: MOUIWindowsSmoke: resize size="
expect_log_failure windows \
  "raw_display=0x222 raw_window=0x111" \
  "raw_display=0x999 raw_window=0x111" \
  "raw_display identity mismatch"
expect_log_appended_line_failure windows \
  "MOUIWindowsSmoke: handle hwnd=0x111 hinstance=0x222 raw_display=0x222 raw_window=0x111" \
  "log must contain exactly one line with MOUIWindowsSmoke: handle hwnd=0x, got 2"
expect_log_failure windows \
  "raw_display=0x222 raw_window=0x111" \
  "raw_display=0x222 raw_window=0x111junk" \
  "field raw_window must be a hex value"
expect_log_failure windows \
  "raw_display=0x222 raw_window=0x111" \
  "raw_display=0x222 raw_window=0x111 raw_window=0x111" \
  "duplicate field raw_window"
expect_log_failure windows \
  "primary=true primary_id=0x333" \
  "primary=false primary_id=0x333" \
  "monitor line did not report primary=true"
expect_log_appended_line_failure windows \
  "MOUIWindowsSmoke: monitors count=1 primary=true primary_id=0x333 current=true current_id=0x333" \
  "log must contain exactly one line with MOUIWindowsSmoke: monitors count=, got 2"
expect_log_failure windows \
  "primary_id=0x333" \
  "primary_id=0x0" \
  "primary_id must be nonzero"
expect_log_move_between_failure windows \
  "MOUIWindowsSmoke: handle hwnd=0x111 hinstance=0x222 raw_display=0x222 raw_window=0x111" \
  "MOUIWindowsSmoke: ready" \
  "log did not contain MOUIWindowsSmoke: handle hwnd=0x before MOUIWindowsSmoke: ready"
expect_log_prefix_rejection windows \
  "MOUIWindowsSmoke: handle hwnd=0x111 hinstance=0x222 raw_display=0x222 raw_window=0x111" \
  "note MOUIWindowsSmoke: handle hwnd=0x111 hinstance=0x222 raw_display=0x222 raw_window=0x111" \
  "log must contain exactly one line with MOUIWindowsSmoke: handle hwnd=0x, got 0"
expect_log_failure windows \
  "MOUIWindowsSmoke: keyboard key=a" \
  "MOUIWindowsSmoke: keyboard key=b" \
  "log must contain exactly one line equal to MOUIWindowsSmoke: keyboard key=a, got 0"
expect_log_failure windows \
  "MOUIWindowsSmoke: keyboard key=a" \
  "MOUIWindowsSmoke: keyboard key=ab" \
  "log must contain exactly one line equal to MOUIWindowsSmoke: keyboard key=a, got 0"
expect_log_failure windows \
  "MOUIWindowsSmoke: pointer x=24 y=32" \
  "MOUIWindowsSmoke: pointer" \
  "missing field x"
expect_log_failure windows \
  "MOUIWindowsSmoke: surface size=320x180 scale=1" \
  "MOUIWindowsSmoke: surface size=320x180 scale=1x" \
  "field scale must be a decimal"
expect_log_failure windows \
  "MOUIWindowsSmoke: resize requested size=400x240" \
  "MOUIWindowsSmoke: resize requested size=400x0" \
  "resize request height must be positive"
expect_log_appended_line_failure windows \
  "MOUIWindowsSmoke: resize requested size=400x240" \
  "log must contain exactly one line with MOUIWindowsSmoke: resize requested size=, got 2"
expect_log_appended_line_failure windows \
  "MOUIWindowsSmoke: cursor Icon(Text)" \
  "log must contain exactly one line equal to MOUIWindowsSmoke: cursor Icon(Text), got 2"
expect_log_appended_line_failure windows \
  "MOUIWindowsSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true" \
  "log must contain exactly one line equal to MOUIWindowsSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true, got 2"
expect_log_appended_failure windows \
  "MOUIWindowsSmoke: input request failed" \
  "log contained MOUIWindowsSmoke failure line"
expect_log_appended_line_failure windows \
  "MOUILinuxSmoke: finished" \
  "log contained forbidden text: MOUILinuxSmoke:"
expect_log_appended_line_failure windows \
  "MOUIWindowsSmoke: ready" \
  "log must contain exactly one line equal to MOUIWindowsSmoke: ready, got 2"
expect_log_failure windows \
  "MOUIWindowsSmoke: ready" \
  "MOUIWindowsSmoke: readyish" \
  "log must contain exactly one line equal to MOUIWindowsSmoke: ready, got 0"
expect_log_appended_line_failure windows \
  "MOUIWindowsSmoke: destroyed" \
  "log must contain exactly one line equal to MOUIWindowsSmoke: destroyed, got 2"
expect_log_appended_line_failure windows \
  "MOUIWindowsSmoke: pointer x=1 y=2" \
  "last MOUIWindowsSmoke line must be MOUIWindowsSmoke: finished"
expect_log_order_failure windows \
  "MOUIWindowsSmoke: ime text=a" \
  "MOUIWindowsSmoke: ready" \
  "log did not contain exact line MOUIWindowsSmoke: ime text=a before exact line MOUIWindowsSmoke: ready"
expect_log_failure windows \
  "MOUIWindowsSmoke: ime text=a" \
  "MOUIWindowsSmoke: ime text=ab" \
  "log must contain exactly one line equal to MOUIWindowsSmoke: ime text=a, got 0"
expect_log_order_failure linux \
  "MOUILinuxSmoke: destroyed" \
  "MOUILinuxSmoke: finished" \
  "log did not contain MOUILinuxSmoke: destroyed before MOUILinuxSmoke: finished" \
  pending-ok
expect_log_order_failure windows \
  "MOUIWindowsSmoke: destroyed" \
  "MOUIWindowsSmoke: finished" \
  "log did not contain MOUIWindowsSmoke: destroyed before MOUIWindowsSmoke: finished"

for backend in macos linux windows; do
  if [[ "$backend" != "$actual_host" ]]; then
    expect_live_failure "$backend"
  fi
done

expect_dry_failure bogus

printf 'Runtime smoke helper check passed: detected %s\n' "$actual_host"
