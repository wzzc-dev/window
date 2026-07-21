#!/usr/bin/env bash
set -euo pipefail

PKG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$PKG_ROOT/template"

for path in \
  "$TEMPLATE/build-profile.json5" \
  "$TEMPLATE/oh-package.json5" \
  "$TEMPLATE/AppScope/resources/base/media/app_icon.svg" \
  "$TEMPLATE/entry/build-profile.json5" \
  "$TEMPLATE/entry/oh-package.json5" \
  "$TEMPLATE/entry/src/main/module.json5" \
  "$TEMPLATE/entry/src/main/ets/entryability/EntryAbility.ets" \
  "$TEMPLATE/entry/src/main/ets/pages/Index.ets" \
  "$TEMPLATE/entry/src/main/cpp/CMakeLists.txt" \
  "$TEMPLATE/entry/src/main/cpp/window_hosted_napi.cpp" \
  "$TEMPLATE/entry/src/main/resources/base/element/color.json" \
  "$TEMPLATE/entry/src/main/resources/base/media/app_icon.svg" \
  "$TEMPLATE/entry/src/main/cpp/types/libwindow_harmonyos_hosted/Index.d.ts"
do
  [[ -f "$path" ]] || {
    echo "missing HarmonyOS hosted template file: $path" >&2
    exit 1
  }
done

SOURCE_ROOTS=(
  "$TEMPLATE/entry/src/main/ets"
  "$TEMPLATE/entry/src/main/cpp"
)
if rg -n 'moui_embedding|moui_shell|install_embedding|attach_surface|inject_' "${SOURCE_ROOTS[@]}"; then
  echo "HarmonyOS hosted template must not use shell or embedding APIs" >&2
  exit 1
fi

rg -q 'OH_NativeXComponent_RegisterCallback' "$TEMPLATE/entry/src/main/cpp/window_hosted_napi.cpp"
rg -q 'mbw_harmonyos_host_on_surface_init' "$TEMPLATE/entry/src/main/cpp/window_hosted_napi.cpp"
rg -q 'mbw_harmonyos_host_on_pointer_' "$TEMPLATE/entry/src/main/cpp/window_hosted_napi.cpp"
rg -q "libraryname: 'window_harmonyos_hosted'" "$TEMPLATE/entry/src/main/ets/pages/Index.ets"
rg -q 'startEventLoop' "$TEMPLATE/entry/src/main/ets/entryability/EntryAbility.ets"

echo "harmonyos hosted template: ok"
