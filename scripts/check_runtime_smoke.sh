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
}

expect_failure() {
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

expect_success web

for backend in macos linux windows; do
  if [[ "$backend" == "$actual_host" ]]; then
    expect_success "$backend"
  else
    expect_failure "$backend"
  fi
done

expect_failure bogus

printf 'Runtime smoke helper check passed: detected %s\n' "$actual_host"
