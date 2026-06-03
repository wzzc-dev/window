#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'Web asset smoke check failed: %s\n' "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file $path"
}

require_nonempty_file() {
  local path="$1"
  require_file "$path"
  [[ -s "$path" ]] || fail "empty file $path"
}

require_text() {
  local path="$1"
  local text="$2"
  rg -q --fixed-strings "$text" "$path" ||
    fail "$path does not contain expected text: $text"
}

require_binary_text() {
  local path="$1"
  local text="$2"
  rg -a -q --fixed-strings "$text" "$path" ||
    fail "$path does not contain expected binary text: $text"
}

ensure_wasm_at_documented_path() {
  local generated_path="$1"
  local documented_path="$2"
  if [[ -f "$documented_path" ]]; then
    return
  fi
  require_nonempty_file "$generated_path"
  mkdir -p "$(dirname "$documented_path")"
  cp "$generated_path" "$documented_path"
}

check_runtime_module_load() {
  if ! command -v node >/dev/null 2>&1; then
    printf 'Skipping Web runtime module import smoke: node not found\n'
    return
  fi

  node --input-type=module <<'EOF'
const mod = await import("./web/runtime.js");
const requiredExports = ["connectWindowWeb", "createWindowWebImports"];
for (const name of requiredExports) {
  if (typeof mod[name] !== "function") {
    throw new Error(`web/runtime.js export ${name} is not a function`);
  }
}

const imports = mod.createWindowWebImports();
const requiredImports = [
  "begin_create_string",
  "finish_create_string",
  "create_canvas",
  "install_canvas_events",
  "remove_canvas_events",
  "set_dispatch_event",
  "set_ime_allowed",
];
for (const name of requiredImports) {
  if (typeof imports[name] !== "function") {
    throw new Error(`window_web import ${name} is not a function`);
  }
}

let dispatched = false;
mod.connectWindowWeb(
  {
    exports: {
      web_dispatch_event() {
        dispatched = true;
      },
    },
  },
  imports,
);
imports.schedule_microtask();
await new Promise(resolve => queueMicrotask(resolve));
if (!dispatched) {
  throw new Error("connectWindowWeb did not install web_dispatch_event");
}
EOF
  printf 'Web runtime module import smoke passed\n'
}

moon --target-dir "$ROOT/_build" build examples/window_web --target wasm-gc >/dev/null

html="examples/window_web/index.html"
runtime="web/runtime.js"
wasm="_build/wasm-gc/debug/build/wzzc-dev/window/examples/window_web/window_web.wasm"
generated_wasm="_build/wasm-gc/debug/build/examples/window_web/window_web.wasm"

require_file "$html"
require_file "$runtime"
ensure_wasm_at_documented_path "$generated_wasm" "$wasm"
require_nonempty_file "$wasm"

require_text "$html" "../../web/runtime.js?window-web-dev=1"
require_text "$html" "../../_build/wasm-gc/debug/build/wzzc-dev/window/examples/window_web/window_web.wasm?window-web-dev=1"
require_text "$html" "createWindowWebImports()"
require_text "$html" "connectWindowWeb(instance, windowWeb)"
require_text "$html" 'status.textContent = "Running"'
require_text "$runtime" "export function createWindowWebImports()"
require_text "$runtime" "export function connectWindowWeb(instance, imports)"
require_text "$runtime" "web_dispatch_event"
require_binary_text "$wasm" "web_dispatch_event"
require_binary_text "$wasm" "_start"

check_runtime_module_load

printf 'Web asset smoke check passed: %s\n' "$wasm"
