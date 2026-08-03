#!/usr/bin/env bash
# Build window-hosted Counter .app for iOS Simulator (package-local sources).
set -euo pipefail
PKG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_ROOT="$(cd "$PKG_ROOT/.." && pwd)"
WINDOW_REPO_ROOT="$(cd "$MODULE_ROOT/../.." && pwd)"
WORKSPACE="${MBW_WORKSPACE_ROOT:-}"
if [[ -z "$WORKSPACE" ]]; then
  if [[ -d "$WINDOW_REPO_ROOT/../examples/counter/ios_window_hosted" ]]; then
    WORKSPACE="$(cd "$WINDOW_REPO_ROOT/.." && pwd)"
  else
    WORKSPACE="$MODULE_ROOT"
  fi
fi

BUILD_DIR="${MBW_IOS_BUILD_DIR:-$WORKSPACE/artifacts/window-hosted-ios}"
MOONBIT_DIR="$BUILD_DIR/moonbit-c"
PKG="examples/counter/ios_window_hosted"
MOONBIT_C="$MOONBIT_DIR/native/debug/build/${PKG}/ios_window_hosted.c"
APP_DIR="$BUILD_DIR/WindowHostedCounter.app"
BUNDLE_ID="${MBW_IOS_BUNDLE_ID:-dev.wzzc.window.hosted.counter}"
MOON_HOME="${MOON_HOME:-$HOME/.moon}"
TEMPLATE="$PKG_ROOT/template"
APP_DELEGATE="$TEMPLATE/Sources/MBWHostedAppDelegate.m"
APP_MAIN="$TEMPLATE/Sources/main.m"

export MOUI_SKIA_DISABLE_PREBUILD_SKIA="${MOUI_SKIA_DISABLE_PREBUILD_SKIA:-1}"
export MOONBIT_NEW_NATIVE=0

mkdir -p "$BUILD_DIR" "$MOONBIT_DIR" "$APP_DIR"
cd "$WORKSPACE"

if [[ ! -f "$APP_DELEGATE" || ! -f "$APP_MAIN" ]]; then
  echo "iOS hosted template is missing UIKit sources under $TEMPLATE/Sources" >&2
  exit 1
fi

echo "== generate MoonBit C (MOONBIT_NEW_NATIVE=0) =="
if [[ ! -d "$WORKSPACE/examples/counter/ios_window_hosted" ]]; then
  echo "MoUI counter package missing; set MBW_WORKSPACE_ROOT to MoUI root." >&2
  exit 1
fi
moon build "$PKG" --target native --target-dir "$MOONBIT_DIR"
if [[ ! -f "$MOONBIT_C" ]]; then
  found="$(find "$MOONBIT_DIR" -name 'ios_window_hosted.c' | head -1 || true)"
  if [[ -z "$found" ]]; then
    echo "missing generated C under $MOONBIT_DIR" >&2
    exit 1
  fi
  MOONBIT_C="$found"
fi
echo "moonbitC=$MOONBIT_C"

SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"
CLANG="$(xcrun --sdk iphonesimulator --find clang)"
CLANGXX="$(xcrun --sdk iphonesimulator --find clang++)"
MIN_IOS="${MBW_IOS_MIN_VERSION:-15.0}"
OBJDIR="$BUILD_DIR/obj"
mkdir -p "$OBJDIR"

COMMON_FLAGS=(
  -isysroot "$SDK_PATH"
  -target "arm64-apple-ios${MIN_IOS}-simulator"
  -fobjc-arc
  -O0 -g
  -I"$MOON_HOME/include"
  -I"$PKG_ROOT"
  -I"$PKG_ROOT/native/include"
  -I"$WORKSPACE/moui_skia/native"
  -D__APPLE__
  -DTARGET_OS_IPHONE=1
  -DTARGET_OS_SIMULATOR=1
  -DMBW_IOS_MOONBIT_MAIN=mbw_ios_moonbit_main
)

echo "== compile moonbit c =="
"$CLANG" "${COMMON_FLAGS[@]}" -c "$MOONBIT_C" -o "$OBJDIR/ios_window_hosted.o" \
  -Dmain=mbw_ios_moonbit_main

echo "== compile runtime =="
"$CLANG" "${COMMON_FLAGS[@]}" -Dgetentropy=mbw_ios_getentropy -c "$MOON_HOME/lib/runtime.c" -o "$OBJDIR/runtime.o"

echo "== compile host =="
"$CLANG" "${COMMON_FLAGS[@]}" -x objective-c -c "$PKG_ROOT/native_ios_host.c" -o "$OBJDIR/native_ios_host.o"
"$CLANG" "${COMMON_FLAGS[@]}" -c "$APP_DELEGATE" -o "$OBJDIR/mbw_hosted_app_delegate.o"
"$CLANG" "${COMMON_FLAGS[@]}" -c "$PKG_ROOT/native/mbw_ios_app_entry.c" -o "$OBJDIR/mbw_ios_app_entry.o"
"$CLANG" "${COMMON_FLAGS[@]}" -c "$APP_MAIN" -o "$OBJDIR/mbw_ios_main.o"
"$CLANG" "${COMMON_FLAGS[@]}" -c "$PKG_ROOT/native/mbw_ios_compat.c" -o "$OBJDIR/mbw_ios_compat.o"

FS_NATIVE="$WORKSPACE/.mooncakes/moonbitlang/x/fs/fs_native.c"
if [[ -f "$FS_NATIVE" ]]; then
  "$CLANG" "${COMMON_FLAGS[@]}" -c "$FS_NATIVE" -o "$OBJDIR/fs_native.o"
fi

echo "== compile skia stubs =="
SKIA_ROOT="$WORKSPACE/moui_skia/native"
SKIA_OBJS=()
for f in skia_stub.cpp skia_stub_common.cpp skia_stub_surface_image_data.cpp skia_stub_canvas.cpp \
         skia_stub_path.cpp skia_stub_text_font.cpp skia_stub_paragraph.cpp skia_stub_shader_filter.cpp \
         skia_stub_picture.cpp skia_stub_gpu_worker.cpp; do
  if [[ -f "$SKIA_ROOT/$f" ]]; then
    out="$OBJDIR/${f%.cpp}.o"
    "$CLANGXX" "${COMMON_FLAGS[@]}" -std=c++17 -c "$SKIA_ROOT/$f" -o "$out"
    SKIA_OBJS+=("$out")
  fi
done

for glue in "$WORKSPACE/moui/backend/ios/ios_present.mm"
do
  if [[ -f "$glue" ]]; then
    base="$(basename "$glue" .mm)"
    "$CLANGXX" "${COMMON_FLAGS[@]}" -std=c++17 -ObjC++ -c "$glue" -o "$OBJDIR/${base}.o"
    SKIA_OBJS+=("$OBJDIR/${base}.o")
  fi
done

OBJS=(
  "$OBJDIR/ios_window_hosted.o"
  "$OBJDIR/runtime.o"
  "$OBJDIR/native_ios_host.o"
  "$OBJDIR/mbw_hosted_app_delegate.o"
  "$OBJDIR/mbw_ios_app_entry.o"
  "$OBJDIR/mbw_ios_main.o"
  "$OBJDIR/mbw_ios_compat.o"
)
[[ -f "$OBJDIR/fs_native.o" ]] && OBJS+=("$OBJDIR/fs_native.o")
OBJS+=("${SKIA_OBJS[@]}")

echo "== link =="
"$CLANGXX" "${COMMON_FLAGS[@]}" -o "$APP_DIR/WindowHostedCounter" "${OBJS[@]}" \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics \
  -framework Metal -framework MetalKit -lc++

# Bundle metadata from package template when present
PLIST_SRC="$PKG_ROOT/template/Info.plist"
if [[ -f "$PLIST_SRC" ]]; then
  cp -f "$PLIST_SRC" "$APP_DIR/Info.plist"
else
  cat > "$APP_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>WindowHostedCounter</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleName</key>
  <string>WindowHostedCounter</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSRequiresIPhoneOS</key>
  <true/>
  <key>UILaunchScreen</key>
  <dict/>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
  </array>
  <key>MinimumOSVersion</key>
  <string>${MIN_IOS}</string>
</dict>
</plist>
PLIST
fi
# Ensure executable name matches
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable WindowHostedCounter" "$APP_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "$APP_DIR/Info.plist" 2>/dev/null || true

chmod +x "$APP_DIR/WindowHostedCounter"
echo "wrote $APP_DIR"
ls -la "$APP_DIR"
