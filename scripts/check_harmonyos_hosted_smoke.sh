#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "== harmonyos hosted host-sim =="
moon test ./harmonyos --target native
echo "== harmonyos package check =="
moon check ./harmonyos --target native
echo "== harmonyos template check =="
bash "$ROOT/harmonyos/scripts/check-template.sh"
echo "harmonyos hosted smoke: ok"
