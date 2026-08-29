#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
. "$ROOT/scripts/ci_host.sh"

host="$(detect_window_ci_host)"

moon fmt --check
moon check
moon check --warn-list +73

case "$host" in
  linux|windows)
    # Non-Darwin hosts cannot compile the macOS/iOS native stubs, so they run
    # the host-relevant backend subset instead of the full-package gate.
    moon test modules/window/core --build-only
    moon test modules/window/dpi --build-only
    moon test modules/window/web --build-only --target wasm-gc
    moon test modules/window/$host --build-only
    moon build modules/window/$host --target native
    ;;
  *)
    # Darwin (and unknown) hosts can compile every backend's native stubs,
    # so they keep the full-package gate.
    moon test --release
    moon build
    ;;
esac

scripts/check_examples_build.sh
scripts/check_ffi_surface.sh
scripts/check_event_loop_thread_boundary.sh
scripts/check_monitor_thread_boundary.sh
scripts/check_window_thread_boundary.sh
scripts/check_workspace_architecture.sh

if [[ "${RUN_ASAN:-0}" == "1" ]]; then
  scripts/check_asan.py
fi

if [[ "${RUN_EXAMPLE_TRANSCRIPTS:-0}" == "1" ]]; then
  scripts/check_example_transcripts.sh
fi
