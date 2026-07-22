#!/usr/bin/env bash
# Build window-hosted APK using android/template (package-local).
set -euo pipefail
PKG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_ROOT="$(cd "$PKG_ROOT/.." && pwd)"
WINDOW_REPO_ROOT="$(cd "$MODULE_ROOT/../.." && pwd)"
WORKSPACE="${MBW_WORKSPACE_ROOT:-}"
if [[ -z "$WORKSPACE" ]]; then
  if [[ -d "$WINDOW_REPO_ROOT/../examples/counter/android_window_hosted" ]]; then
    WORKSPACE="$(cd "$WINDOW_REPO_ROOT/.." && pwd)"
  else
    WORKSPACE="$MODULE_ROOT"
  fi
fi

ABI="${MBW_ABI:-arm64-v8a}"
BUILD_DIR="${MBW_BUILD_DIR:-$WORKSPACE/artifacts/window-hosted-android}"
MOONBIT_DIR="$BUILD_DIR/moonbit-c"
MOONBIT_C="$MOONBIT_DIR/native/debug/build/examples/counter/android_window_hosted/android_window_hosted.c"
TEMPLATE="$PKG_ROOT/template"
APK_OUT="$BUILD_DIR/app-debug.apk"
MOON_HOME="${MOON_HOME:-$HOME/.moon}"

export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/.valdi/android_home}}"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
export MOUI_SKIA_DISABLE_PREBUILD_SKIA="${MOUI_SKIA_DISABLE_PREBUILD_SKIA:-1}"
export MOONBIT_NEW_NATIVE=0

mkdir -p "$BUILD_DIR" "$MOONBIT_DIR"
cd "$WORKSPACE"

echo "== generate MoonBit C (MOONBIT_NEW_NATIVE=0) =="
if [[ ! -d "$WORKSPACE/examples/counter/android_window_hosted" ]]; then
  echo "MoUI counter package missing; set MBW_WORKSPACE_ROOT to MoUI root." >&2
  exit 1
fi
moon build examples/counter/android_window_hosted --target native --target-dir "$MOONBIT_DIR"
if [[ ! -f "$MOONBIT_C" ]]; then
  found="$(find "$MOONBIT_DIR" -name 'android_window_hosted.c' | head -1 || true)"
  if [[ -z "$found" ]]; then
    echo "missing generated C: $MOONBIT_C" >&2
    exit 1
  fi
  MOONBIT_C="$found"
fi
echo "moonbitC=$MOONBIT_C"

echo "== gradle assembleDebug =="
GRADLEW=""
if [[ -x "$WORKSPACE/artifacts/android/counter/android-project/gradlew" ]]; then
  GRADLEW="$WORKSPACE/artifacts/android/counter/android-project/gradlew"
elif command -v gradle >/dev/null 2>&1; then
  GRADLEW="gradle"
elif [[ -x "$WORKSPACE/.gradle/moui-gradle-9.6.1/gradle-9.6.1/bin/gradle" ]]; then
  GRADLEW="$WORKSPACE/.gradle/moui-gradle-9.6.1/gradle-9.6.1/bin/gradle"
fi
if [[ -z "$GRADLEW" ]]; then
  echo "gradle/gradlew not found" >&2
  exit 1
fi

(
  cd "$TEMPLATE"
  "$GRADLEW" :app:assembleDebug \
    -PmbwWorkspaceRoot="$WORKSPACE" \
    -PmbwWindowRoot="$MODULE_ROOT" \
    -PmbwMoonHome="$MOON_HOME" \
    -PmbwMoonbitC="$MOONBIT_C" \
    -PmbwAbi="$ABI" \
    --no-daemon
)

APK_PATH="$TEMPLATE/app/build/outputs/apk/debug/app-debug.apk"
if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not produced at $APK_PATH" >&2
  exit 1
fi
cp -f "$APK_PATH" "$APK_OUT"
echo "wrote $APK_OUT"
ls -la "$APK_OUT"
