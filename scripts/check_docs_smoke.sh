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
  rg -q --fixed-strings "$text" "$path" ||
    fail "$path does not mention expected text: $text"
}

for path in \
  README.mbt.md \
  docs/testing.md \
  docs/platform-gaps.md \
  scripts/check_ci.sh \
  scripts/check_ci_host.sh \
  scripts/check_runtime_smoke.sh \
  scripts/check_web_assets.sh \
  scripts/smoke_runtime.sh
do
  require_file "$path"
done

for path in \
  scripts/check_ci.sh \
  scripts/check_ci_host.sh \
  scripts/check_runtime_smoke.sh \
  scripts/check_web_assets.sh \
  scripts/smoke_runtime.sh
do
  require_executable "$path"
done

require_text README.mbt.md "docs/platform-gaps.md"
require_text README.mbt.md "bash scripts/check_ci.sh"
require_text README.mbt.md "scripts/smoke_runtime.sh macos"
require_text README.mbt.md "WINDOW_RUNTIME_SMOKE_DRY_RUN=1"

require_text docs/testing.md "scripts/check_ci_host.sh"
require_text docs/testing.md "scripts/check_runtime_smoke.sh"
require_text docs/testing.md "moon check --target all --warn-list +73"
require_text docs/testing.md "scripts/check_web_assets.sh"
require_text docs/testing.md "scripts/smoke_runtime.sh <backend>"
require_text docs/testing.md "WINDOW_CI_HOST=linux bash scripts/check_ci.sh"
require_text docs/testing.md "WINDOW_CI_HOST=windows bash scripts/check_ci.sh"

require_text docs/platform-gaps.md 'Treat `Pending` as missing evidence'
require_text docs/platform-gaps.md "scripts/check_runtime_smoke.sh"
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh macos"
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh web"
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh linux"
require_text docs/platform-gaps.md "scripts/smoke_runtime.sh windows"
require_text docs/platform-gaps.md "WINDOW_CI_HOST=linux bash scripts/check_ci.sh"
require_text docs/platform-gaps.md "WINDOW_CI_HOST=windows bash scripts/check_ci.sh"

require_text scripts/check_ci.sh "scripts/check_ci_host.sh"
require_text scripts/check_ci.sh "scripts/check_runtime_smoke.sh"
require_text scripts/check_ci.sh "moon check --target all --warn-list +73"
require_text scripts/check_ci.sh "scripts/check_web_assets.sh"

printf 'Documentation smoke check passed\n'
