#!/usr/bin/env bash
# Compatibility entrypoint; the package-local HAP builder owns the implementation.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec bash "$SCRIPT_DIR/build-hosted-hap.sh" "$@"
