// Host imports for the wasm-gc web backend.
//
// The MoonBit package imports these functions from the `window_web` module.
// A browser loader should pass `createWindowWebImports()` in the import object:
//
//   const windowWeb = createWindowWebImports();
//   const imports = { window_web: windowWeb, spectest: { print_char: c => console.log(String.fromCharCode(c)) } };
//   const { instance } = await WebAssembly.instantiateStreaming(fetch("app.wasm"), imports);
//   connectWindowWeb(instance, windowWeb);
//   instance.exports._start?.();

export function createWindowWebImports() {
  const canvases = new Map();
  const listeners = new Map();
  const stringHandles = new Map();
  const eventTexts = new Map();
  let nextCanvasId = 1;
  let nextStringHandle = 1;
  let nextEventTextId = 1;
  let dispatchEvent = null;

  const emit = (kind, rawId = 0, arg0 = 0, arg1 = 0, argd = 0.0, text = "") => {
    if (dispatchEvent) {
      const textId = nextEventTextId++;
      eventTexts.set(textId, `${text ?? ""}`);
      try {
        dispatchEvent(kind, rawId, arg0, arg1, argd, textId);
      } finally {
        eventTexts.delete(textId);
      }
    }
  };

  const createStringHandle = value => {
    const handle = { value: `${value ?? ""}`, offset: 0 };
    const id = nextStringHandle++;
    stringHandles.set(id, handle);
    return id;
  };

  const stringValue = handle => {
    if (typeof handle === "number") {
      return stringHandles.get(handle)?.value ?? "";
    }
    return handle?.value ?? "";
  };

  const ensureCanvasId = canvas => {
    if (!canvas.id) {
      canvas.id = `moonbit-window-web-${nextCanvasId++}`;
    }
    canvases.set(canvas.id, canvas);
    return canvas.id;
  };

  const pointerPosition = (canvas, event) => {
    const rect = canvas.getBoundingClientRect();
    return {
      x: Math.round(event.clientX - rect.left),
      y: Math.round(event.clientY - rect.top),
    };
  };

  return {
    begin_create_string() {
      return createStringHandle("");
    },
    string_append_char(handle, ch) {
      const entry = stringHandles.get(handle);
      if (entry) {
        entry.value += String.fromCodePoint(Number(ch));
      }
    },
    finish_create_string(handle) {
      return handle;
    },
    begin_read_string(id) {
      return createStringHandle(eventTexts.get(id) ?? "");
    },
    string_read_char(handle) {
      const entry = stringHandles.get(handle);
      if (!entry || entry.offset >= entry.value.length) {
        return -1;
      }
      const codePoint = entry.value.codePointAt(entry.offset);
      entry.offset += codePoint > 0xffff ? 2 : 1;
      return codePoint;
    },
    finish_read_string(handle) {
      stringHandles.delete(handle);
    },
    create_canvas(id, width, height) {
      const canvas = document.createElement("canvas");
      canvas.id = stringValue(id) || `moonbit-window-web-${nextCanvasId++}`;
      canvas.width = Math.max(1, width | 0);
      canvas.height = Math.max(1, height | 0);
      canvas.tabIndex = 0;
      canvas.style.display = "block";
      document.body.appendChild(canvas);
      canvases.set(canvas.id, canvas);
      return canvas;
    },
    get_canvas_by_id(id) {
      const canvas = document.getElementById(stringValue(id));
      if (canvas instanceof HTMLCanvasElement) {
        canvases.set(id, canvas);
        return canvas;
      }
      return null;
    },
    canvas_is_valid(canvas) {
      return canvas instanceof HTMLCanvasElement;
    },
    canvas_id(canvas) {
      return canvas ? ensureCanvasId(canvas) : "";
    },
    canvas_width(canvas) {
      return canvas?.width ?? 0;
    },
    canvas_height(canvas) {
      return canvas?.height ?? 0;
    },
    canvas_client_width(canvas) {
      return Math.round(canvas?.clientWidth ?? canvas?.width ?? 0);
    },
    canvas_client_height(canvas) {
      return Math.round(canvas?.clientHeight ?? canvas?.height ?? 0);
    },
    canvas_offset_left(canvas) {
      return Math.round(canvas?.getBoundingClientRect().left ?? 0);
    },
    canvas_offset_top(canvas) {
      return Math.round(canvas?.getBoundingClientRect().top ?? 0);
    },
    set_canvas_size(canvas, width, height) {
      if (canvas) {
        canvas.width = Math.max(1, width | 0);
        canvas.height = Math.max(1, height | 0);
      }
    },
    set_canvas_visible(canvas, visible) {
      if (canvas) {
        canvas.style.display = visible ? "block" : "none";
      }
    },
    set_canvas_cursor(canvas, cursor) {
      if (canvas) {
        canvas.style.cursor = stringValue(cursor) || "default";
      }
    },
    set_document_title(title) {
      document.title = stringValue(title);
    },
    device_pixel_ratio() {
      return window.devicePixelRatio || 1.0;
    },
    now_ms() {
      return BigInt(Math.round(performance.now()));
    },
    schedule_animation_frame() {
      requestAnimationFrame(() => emit(1));
    },
    schedule_timeout(delayMs) {
      setTimeout(() => emit(2), Math.max(0, delayMs | 0));
    },
    schedule_microtask() {
      queueMicrotask(() => emit(3));
    },
    set_dispatch_event(fn) {
      dispatchEvent = fn;
    },
    install_canvas_events(rawId, canvas) {
      if (!canvas) return;
      const handlers = [];
      const add = (target, type, handler, options) => {
        target.addEventListener(type, handler, options);
        handlers.push([target, type, handler, options]);
      };
      add(canvas, "pointerenter", event => {
        const p = pointerPosition(canvas, event);
        emit(20, rawId, p.x, p.y);
      });
      add(canvas, "pointermove", event => {
        const p = pointerPosition(canvas, event);
        emit(21, rawId, p.x, p.y);
      });
      add(canvas, "pointerleave", event => {
        const p = pointerPosition(canvas, event);
        emit(22, rawId, p.x, p.y);
      });
      add(canvas, "pointerdown", event => {
        canvas.focus();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
      });
      add(canvas, "pointerup", event => {
        const p = pointerPosition(canvas, event);
        emit(24, rawId, p.x, p.y, event.button);
      });
      add(canvas, "wheel", event => {
        event.preventDefault();
        emit(30, rawId, Math.round(event.deltaX), Math.round(event.deltaY));
      }, { passive: false });
      add(canvas, "focus", () => emit(11, rawId));
      add(canvas, "blur", () => emit(12, rawId));
      add(canvas, "keydown", event => emit(40, rawId, 0, 0, 0, event.code || event.key || ""));
      add(canvas, "keyup", event => emit(41, rawId, 0, 0, 0, event.code || event.key || ""));
      add(canvas, "input", event => emit(42, rawId, 0, 0, 0, event.data || ""));
      add(window, "resize", () => emit(10, rawId, canvas.width, canvas.height));
      const media = window.matchMedia?.("(prefers-color-scheme: dark)");
      if (media) {
        add(media, "change", event => emit(50, rawId, event.matches ? 1 : 0));
      }
      listeners.set(rawId, handlers);
    },
    remove_canvas_events(rawId) {
      const handlers = listeners.get(rawId) || [];
      for (const [target, type, handler, options] of handlers) {
        target.removeEventListener(type, handler, options);
      }
      listeners.delete(rawId);
    },
    system_theme() {
      return window.matchMedia?.("(prefers-color-scheme: dark)").matches ? 1 : 0;
    },
  };
}

export function connectWindowWeb(instance, imports) {
  const dispatch = instance?.exports?.web_dispatch_event;
  if (typeof dispatch !== "function") {
    throw new Error("MoonBit wasm module must export web_dispatch_event");
  }
  imports.set_dispatch_event(dispatch);
  return instance;
}
