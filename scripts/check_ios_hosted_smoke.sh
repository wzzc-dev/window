#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "== ios hosted host-sim =="
moon test ./ios --target native
echo "== ios package check =="
moon check ./ios --target native
echo "== ios template check =="
bash "$ROOT/ios/scripts/check-template.sh"
echo "ios hosted smoke: ok"
