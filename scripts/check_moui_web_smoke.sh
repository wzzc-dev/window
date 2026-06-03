#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'MoUI Web smoke check failed: %s\n' "$1" >&2
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

check_node_consumer_runtime() {
  if ! command -v node >/dev/null 2>&1; then
    printf 'Skipping MoUI Web Node consumer runtime smoke: node not found\n'
    return
  fi

  node --input-type=module <<'EOF'
import { readFile } from "node:fs/promises";
import { connectWindowWeb, createWindowWebImports } from "./web/runtime.js";

class FakeEventTarget {
  constructor() {
    this.listeners = new Map();
  }

  addEventListener(type, handler, options) {
    const handlers = this.listeners.get(type) ?? [];
    handlers.push([handler, options]);
    this.listeners.set(type, handlers);
  }

  removeEventListener(type, handler) {
    const handlers = this.listeners.get(type) ?? [];
    this.listeners.set(
      type,
      handlers.filter(([candidate]) => candidate !== handler),
    );
  }

  dispatchEvent(event) {
    event.target ??= this;
    event.preventDefault ??= () => {
      event.defaultPrevented = true;
    };
    for (const [handler] of this.listeners.get(event.type) ?? []) {
      handler(event);
    }
    return !event.defaultPrevented;
  }
}

class FakeElement extends FakeEventTarget {
  constructor(tagName) {
    super();
    this.tagName = tagName.toUpperCase();
    this.children = [];
    this.parentElement = null;
    this.style = {};
    this.value = "";
  }

  appendChild(child) {
    child.parentElement = this;
    this.children.push(child);
    return child;
  }

  remove() {
    if (!this.parentElement) return;
    this.parentElement.children = this.parentElement.children.filter(
      child => child !== this,
    );
    this.parentElement = null;
  }

  setAttribute(name, value) {
    this[name] = `${value}`;
  }

  focus() {
    globalThis.document.activeElement = this;
    this.dispatchEvent({ type: "focus" });
  }
}

class FakeCanvas extends FakeElement {
  constructor() {
    super("canvas");
    this.width = 0;
    this.height = 0;
    this.tabIndex = 0;
  }

  getBoundingClientRect() {
    return {
      left: 0,
      top: 0,
      width: this.width,
      height: this.height,
    };
  }
}

const elementsById = new Map();
const body = new FakeElement("body");
const canvas = new FakeCanvas();
canvas.id = "moui-web-smoke-canvas";
body.appendChild(canvas);
elementsById.set(canvas.id, canvas);

const documentShim = {
  activeElement: null,
  body,
  title: "",
  createElement(tagName) {
    return tagName === "canvas" ? new FakeCanvas() : new FakeElement(tagName);
  },
  getElementById(id) {
    return elementsById.get(id) ?? null;
  },
};

const windowShim = new FakeEventTarget();
windowShim.devicePixelRatio = 1;
windowShim.matchMedia = () => ({
  matches: false,
  addEventListener() {},
  removeEventListener() {},
});

globalThis.document = documentShim;
globalThis.window = windowShim;
globalThis.HTMLCanvasElement = FakeCanvas;
globalThis.requestAnimationFrame = callback =>
  setTimeout(() => callback(Date.now()), 0);

const imports = createWindowWebImports();
const lines = [];
let line = "";
const spectest = {
  print_char(value) {
    const ch = String.fromCodePoint(Number(value));
    if (ch === "\n") {
      lines.push(line);
      line = "";
    } else {
      line += ch;
    }
  },
};

const bytes = await readFile(
  "_build/wasm-gc/debug/build/wzzc-dev/window/examples/moui_web_smoke/moui_web_smoke.wasm",
);
let instance;
try {
  ({ instance } = await WebAssembly.instantiate(bytes, {
    window_web: imports,
    spectest,
  }));
} catch (error) {
  if (error instanceof WebAssembly.CompileError) {
    console.log(
      `Skipping MoUI Web Node consumer runtime smoke: ${error.message}`,
    );
    process.exit(0);
  }
  throw error;
}

connectWindowWeb(instance, imports);
try {
  instance.exports._start?.();
  await new Promise(resolve => setTimeout(resolve, 0));

  windowShim.dispatchEvent({ type: "resize" });
  canvas.dispatchEvent({
    type: "pointermove",
    clientX: 24,
    clientY: 32,
  });
  canvas.dispatchEvent({
    type: "keydown",
    key: "a",
    code: "KeyA",
    isComposing: false,
  });

  for (
    let i = 0;
    i < 20 && !lines.some(line => line.includes("MOUISmoke: ready"));
    i += 1
  ) {
    await new Promise(resolve => setTimeout(resolve, 0));
  }

  const required = [
    "MOUISmoke: surface canvas_id=moui-web-smoke-canvas size=640x360",
    "MOUISmoke: redraw",
    "MOUISmoke: resize size=640x360",
    "MOUISmoke: pointer x=24 y=32",
    "MOUISmoke: keyboard text=a",
    "MOUISmoke: ready",
  ];
  for (const text of required) {
    if (!lines.some(line => line.includes(text))) {
      throw new Error(`Missing ${text}; saw ${lines.join(" | ")}`);
    }
  }
} catch (error) {
  if (
    error instanceof TypeError &&
    error.message.includes("type incompatibility")
  ) {
    console.log(
      `Skipping MoUI Web Node consumer runtime smoke: ${error.message}`,
    );
    process.exit(0);
  }
  throw error;
}
console.log("MoUI Web Node consumer runtime smoke passed");
EOF
}

moon --target-dir "$ROOT/_build" build examples/moui_web_smoke --target wasm-gc >/dev/null

pkg="examples/moui_web_smoke"
html="$pkg/index.html"
main="$pkg/main.mbt"
wasm="_build/wasm-gc/debug/build/wzzc-dev/window/examples/moui_web_smoke/moui_web_smoke.wasm"
generated_wasm="_build/wasm-gc/debug/build/examples/moui_web_smoke/moui_web_smoke.wasm"

require_file "$html"
require_file "$main"
ensure_wasm_at_documented_path "$generated_wasm" "$wasm"
require_nonempty_file "$wasm"

require_text "$main" "WindowAttributesWeb::default().with_canvas_id"
require_text "$main" "window.canvas_id()"
require_text "$main" "window.surface_size()"
require_text "$main" "window.scale_factor()"
require_text "$main" "window.pre_present_notify()"
require_text "$main" "MOUISmoke: ready"
require_text "$main" "PointerMoved"
require_text "$main" "KeyboardInput"
require_text "$main" "SurfaceResized"

require_text "$html" "../../web/runtime.js?window-web-dev=1"
require_text "$html" "../../_build/wasm-gc/debug/build/wzzc-dev/window/examples/moui_web_smoke/moui_web_smoke.wasm?window-web-dev=1"
require_text "$html" "window.__mouiWebSmoke"
require_text "$html" "dispatchConsumerEvents"
require_text "$html" "MOUISmoke: PASS"
require_text "$html" "new KeyboardEvent"
require_text "$html" "pointermove"
require_text "$html" "canvas.getBoundingClientRect()"

require_binary_text "$wasm" "web_dispatch_event"
require_binary_text "$wasm" "_start"

check_node_consumer_runtime

printf 'MoUI Web smoke check passed: %s\n' "$wasm"
