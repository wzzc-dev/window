#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== android hosted host-sim (moon test ./android) =="
moon test ./android --target native

echo "== android package check =="
moon check ./android --target native

echo "== mobile_hosted_smoke (ApplicationHandler cutover sketch) =="
if [[ -d "$ROOT/examples/mobile_hosted_smoke" ]]; then
  moon test ./examples/mobile_hosted_smoke --target native
else
  echo "examples/mobile_hosted_smoke missing; skip"
fi

if [[ "${WINDOW_ANDROID_TEMPLATE_BUILD:-}" == "1" ]]; then
  echo "== android template gradle assemble (optional) =="
  if [[ -x "$ROOT/android/template/gradlew" ]]; then
    (cd "$ROOT/android/template" && ./gradlew :app:assembleDebug)
  else
    echo "WINDOW_ANDROID_TEMPLATE_BUILD=1 but android/template/gradlew is missing; skip."
  fi
else
  echo "Skipping template Gradle build (set WINDOW_ANDROID_TEMPLATE_BUILD=1 to enable)."
fi

echo "android hosted smoke: ok"
