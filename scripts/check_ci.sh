#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

host="$(detect_window_ci_host)"

scripts/check_ci_host.sh
scripts/check_runtime_smoke.sh
scripts/check_docs_smoke.sh
moon check
moon check --warn-list +73
moon check --target all --warn-list +73
moon test core
moon test dpi
moon test web --build-only --target wasm-gc
moon build web --target wasm-gc

case "$host" in
  macos)
    moon test macos --build-only
    moon build macos --target native
    ;;
  linux)
    moon test linux --build-only
    moon build linux --target native
    ;;
  windows)
    moon test windows --build-only
    moon build windows --target native
    ;;
  none)
    echo "Skipping host-native backend build: unsupported CI host"
    ;;
esac

scripts/check_examples_build.sh
scripts/check_web_assets.sh
scripts/check_ffi_surface.sh

if [[ "${RUN_EXAMPLE_TRANSCRIPTS:-0}" == "1" ]]; then
  scripts/check_example_transcripts.sh
fi
