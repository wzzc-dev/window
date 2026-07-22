#!/usr/bin/env bash
# Build the package-local window-hosted HarmonyOS HAP when DevEco is available.
set -euo pipefail

PKG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_ROOT="$(cd "$PKG_ROOT/.." && pwd)"
WINDOW_REPO_ROOT="$(cd "$MODULE_ROOT/../.." && pwd)"
WORKSPACE="${MBW_WORKSPACE_ROOT:-}"
if [[ -z "$WORKSPACE" ]]; then
  if [[ -d "$WINDOW_REPO_ROOT/../examples/counter/harmonyos_window_hosted" ]]; then
    WORKSPACE="$(cd "$WINDOW_REPO_ROOT/.." && pwd)"
  else
    WORKSPACE="$MODULE_ROOT"
  fi
fi

BUILD_DIR="${MBW_HOS_BUILD_DIR:-$WORKSPACE/artifacts/window-hosted-harmonyos}"
MOONBIT_DIR="$BUILD_DIR/moonbit-c"
MOONBIT_C="$MOONBIT_DIR/native/debug/build/examples/counter/harmonyos_window_hosted/harmonyos_window_hosted.c"
TEMPLATE="$PKG_ROOT/template"
MOON_HOME="${MOON_HOME:-$HOME/.moon}"
DEFAULT_DEVECO_HOME="/Applications/DevEco-Studio.app/Contents"
SDK_HOME="${HARMONYOS_SDK_HOME:-${OHOS_SDK_HOME:-$DEFAULT_DEVECO_HOME/sdk/default/openharmony}}"
DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-${HARMONYOS_DEVECO_SDK_HOME:-$DEFAULT_DEVECO_HOME/sdk}}"
HVIGORW="${MBW_HVIGORW:-${HARMONYOS_HVIGORW:-$DEFAULT_DEVECO_HOME/tools/hvigor/bin/hvigorw}}"
OHPM="${MBW_OHPM:-${HARMONYOS_OHPM:-$DEFAULT_DEVECO_HOME/tools/ohpm/bin/ohpm}}"
HAP_OUT="$BUILD_DIR/WindowHostedCounter.hap"

export MOUI_SKIA_DISABLE_PREBUILD_SKIA="${MOUI_SKIA_DISABLE_PREBUILD_SKIA:-1}"
export MOONBIT_NEW_NATIVE=0

mkdir -p "$BUILD_DIR" "$MOONBIT_DIR"

echo "== HarmonyOS template check =="
bash "$PKG_ROOT/scripts/check-template.sh"

echo "== window HarmonyOS hosted host-sim =="
(
  cd "$MODULE_ROOT"
  moon test harmonyos --target native
)

if [[ ! -d "$WORKSPACE/examples/counter/harmonyos_window_hosted" ]]; then
  echo "MoUI counter package missing; set MBW_WORKSPACE_ROOT to the MoUI root." >&2
  exit 1
fi

echo "== generate MoonBit C =="
(
  cd "$WORKSPACE"
  moon build examples/counter/harmonyos_window_hosted --target native --target-dir "$MOONBIT_DIR"
)
if [[ ! -f "$MOONBIT_C" ]]; then
  MOONBIT_C="$(find "$MOONBIT_DIR" -name 'harmonyos_window_hosted.c' | head -1 || true)"
fi
if [[ -z "$MOONBIT_C" || ! -f "$MOONBIT_C" ]]; then
  echo "missing generated HarmonyOS MoonBit C under $MOONBIT_DIR" >&2
  exit 1
fi

hap_result="not-built"
hap_path=""
if [[ -x "$HVIGORW" && -x "$OHPM" && -d "$DEVECO_SDK_HOME" && -f "$SDK_HOME/native/build/cmake/ohos.toolchain.cmake" ]]; then
  export DEVECO_SDK_HOME
  export HARMONYOS_SDK_HOME="$SDK_HOME"
  export OHOS_SDK_HOME="$SDK_HOME"
  export OHOS_BASE_SDK_HOME="$SDK_HOME"
  echo "== install HarmonyOS template dependencies =="
  (
    cd "$TEMPLATE"
    "$OHPM" install --all --no-save
  )

  echo "== build window-hosted HAP =="
  export MBW_WORKSPACE_ROOT="$WORKSPACE"
  export MBW_WINDOW_ROOT="$MODULE_ROOT"
  export MBW_MOON_HOME="$MOON_HOME"
  export MBW_MOONBIT_C="$MOONBIT_C"
  mkdir -p "$TEMPLATE/hnp" "$TEMPLATE/entry/libs/arm64-v8a"
  "$HVIGORW" --stop-daemon >/dev/null 2>&1 || true
  (
    cd "$TEMPLATE"
    "$HVIGORW" --no-daemon assembleHap
  )
  hap_path="$(find "$TEMPLATE/entry/build" -type f -name '*.hap' | head -1 || true)"
  if [[ -z "$hap_path" ]]; then
    echo "Hvigor completed without producing a HAP" >&2
    exit 1
  fi
  cp -f "$hap_path" "$HAP_OUT"
  hap_result="built"
  hap_path="$HAP_OUT"
  echo "wrote $HAP_OUT"
else
  echo "HarmonyOS SDK/hvigor/ohpm unavailable; recording host-sim-only status."
fi

{
  printf '%s\n' '# window-hosted HarmonyOS packaging status'
  printf '\n'
  printf '%s\n' "- Date: $(date -Iseconds 2>/dev/null || date)"
  printf '%s\n' '- Host-sim: passed (check_harmonyos_hosted_smoke.sh)'
  printf '%s\n' '- Template: Stage Ability + SURFACE XComponent + HostCmd NAPI bridge'
  printf '%s\n' "- HAP: $hap_result${hap_path:+ ($hap_path)}"
  printf '%s\n' '- Device: hdc targets:'
  if command -v hdc >/dev/null 2>&1; then
    hdc list targets 2>&1 || true
  else
    printf '%s\n' '  hdc not found'
  fi
  printf '%s\n' '- Device result: not claimed without hdc install+launch evidence.'
} | tee "$BUILD_DIR/status.md"
