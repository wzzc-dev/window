#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

fail() {
  printf 'CI host detection check failed: %s\n' "$1" >&2
  exit 1
}

expect_host() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail "$label returned $actual, expected $expected"
  fi
}

expect_failure() {
  local value="$1"
  local output status
  set +e
  output="$( (export WINDOW_CI_HOST="$value"; detect_window_ci_host) 2>&1 )"
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    fail "WINDOW_CI_HOST=$value unexpectedly succeeded with output: $output"
  fi
  if [[ -z "$output" ]]; then
    fail "WINDOW_CI_HOST=$value failed without an explanatory message"
  fi
}

selected_host="$(detect_window_ci_host)"
case "$selected_host" in
  macos|linux|windows|none)
    ;;
  *)
    fail "detect_window_ci_host returned unexpected value $selected_host"
    ;;
esac

actual_host="$(detect_window_actual_host)"
case "$actual_host" in
  macos|linux|windows|none)
    ;;
  *)
    fail "detect_window_actual_host returned unexpected value $actual_host"
    ;;
esac

auto_host="$(unset WINDOW_CI_HOST; detect_window_ci_host)"
expect_host "auto-detected host" "$actual_host" "$auto_host"

none_host="$(export WINDOW_CI_HOST=none; detect_window_ci_host)"
expect_host "WINDOW_CI_HOST=none" "none" "$none_host"

if [[ "$actual_host" != "none" ]]; then
  matching_host="$(export WINDOW_CI_HOST="$actual_host"; detect_window_ci_host)"
  expect_host "WINDOW_CI_HOST=$actual_host" "$actual_host" "$matching_host"
fi

for candidate in macos linux windows; do
  if [[ "$candidate" != "$actual_host" ]]; then
    expect_failure "$candidate"
  fi
done

expect_failure "bogus"

printf 'CI host detection check passed: detected %s\n' "$actual_host"
