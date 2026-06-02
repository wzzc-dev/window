#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

host="$(detect_window_ci_host)"

bash scripts/check_ci_host.sh
bash scripts/check_runtime_smoke.sh
bash scripts/check_docs_smoke.sh
bash scripts/check_moui_readiness.sh
bash scripts/check_moui_evidence.sh
bash scripts/check_moon_baseline.sh
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

bash scripts/check_examples_build.sh
bash scripts/check_moui_macos_smoke.sh
bash scripts/check_moui_linux_smoke.sh
bash scripts/check_moui_windows_smoke.sh
bash scripts/check_web_assets.sh
bash scripts/check_moui_web_smoke.sh
bash scripts/check_ffi_surface.sh

if [[ "${RUN_EXAMPLE_TRANSCRIPTS:-0}" == "1" ]]; then
  bash scripts/check_example_transcripts.sh
fi
