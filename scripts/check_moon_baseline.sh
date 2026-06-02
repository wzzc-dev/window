#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

fail() {
  printf 'Moon baseline check failed: %s\n' "$1" >&2
  exit 1
}

snapshot_tracked_interfaces() {
  git ls-files '*pkg.generated.mbti' | while IFS= read -r path; do
    if [[ -f "$path" ]]; then
      cksum "$path"
    else
      printf 'missing %s\n' "$path"
    fi
  done
}

before_interfaces="$(snapshot_tracked_interfaces)"
moon info >/dev/null
after_interfaces="$(snapshot_tracked_interfaces)"
if [[ "$after_interfaces" != "$before_interfaces" ]]; then
  fail "moon info changed tracked pkg.generated.mbti files; rerun moon info and review the interface diff"
fi

moon info web --target wasm-gc >/dev/null
moon fmt --check

actual_host="$(detect_window_actual_host)"
case "$actual_host" in
  macos)
    moon test
    ;;
  linux|windows|none)
    printf 'Skipping bare moon test on %s host; use the matching host CI branch plus backend smoke instead\n' "$actual_host"
    ;;
  *)
    fail "detect_window_actual_host returned unexpected value $actual_host"
    ;;
esac

printf 'Moon baseline check passed: detected %s\n' "$actual_host"
