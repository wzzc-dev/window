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
  const textInputs = new Map();
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

  const draggedFileNames = event =>
    Array.from(event.dataTransfer?.files ?? [])
      .map(file => file.webkitRelativePath || file.name)
      .filter(Boolean)
      .join("\n");

  const createHiddenTextInput = canvas => {
    const input = document.createElement("textarea");
    input.setAttribute("aria-hidden", "true");
    input.autocomplete = "off";
    input.autocapitalize = "off";
    input.spellcheck = false;
    input.wrap = "off";
    input.value = "";
    input.style.position = "fixed";
    input.style.left = "-10000px";
    input.style.top = "0";
    input.style.width = "1px";
    input.style.height = "1px";
    input.style.opacity = "0";
    input.style.pointerEvents = "none";
    input.style.zIndex = "-1";
    (canvas.parentElement ?? document.body).appendChild(input);
    return input;
  };

  const focusWithoutScroll = element => {
    try {
      element?.focus?.({ preventScroll: true });
    } catch {
      element?.focus?.();
    }
  };

  const shouldForwardTextInputKey = event =>
    event.key === "Enter" ||
    event.key === "Tab" ||
    event.key === "ArrowLeft" ||
    event.key === "ArrowRight" ||
    event.key === "ArrowUp" ||
    event.key === "ArrowDown" ||
    event.key === "Home" ||
    event.key === "End" ||
    event.key === "PageUp" ||
    event.key === "PageDown" ||
    event.key === "Escape";

  const inputEventData = event => {
    if (event.data) return event.data;
    const value = event.target?.value ?? "";
    return value;
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
    set_canvas_fullscreen(rawId, fullscreen) {
      const state = textInputs.get(rawId);
      const canvas = state?.canvas ?? null;
      if (!canvas) return;
      if (fullscreen) {
        if (document.fullscreenElement !== canvas && canvas.requestFullscreen) {
          const promise = canvas.requestFullscreen();
          if (promise && typeof promise.catch === "function") promise.catch(() => {});
        }
      } else if (document.fullscreenElement && document.exitFullscreen) {
        const promise = document.exitFullscreen();
        if (promise && typeof promise.catch === "function") promise.catch(() => {});
      }
    },
    focus_canvas(rawId) {
      const state = textInputs.get(rawId);
      const canvas = state?.canvas ?? null;
      if (canvas && typeof canvas.focus === "function") {
        try {
          canvas.focus({ preventScroll: true });
        } catch (_) {
          canvas.focus();
        }
      }
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
      setTimeout(() => emit(2, 0, 0, 0, performance.now()), Math.max(0, delayMs | 0));
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
      const textInput = createHiddenTextInput(canvas);
      const textState = {
        input: textInput,
        canvas,
        imeAllowed: false,
        surroundingText: "",
        surroundingCursor: 0,
        surroundingAnchor: 0,
      };
      textInputs.set(rawId, textState);
      let composing = false;
      let compositionText = "";
      let suppressNextInputText = "";
      let suppressNextInputUntil = 0;
      const add = (target, type, handler, options) => {
        target.addEventListener(type, handler, options);
        handlers.push([target, type, handler, options]);
      };
      const acceptFileDrag = event => {
        if (event.cancelable) {
          event.preventDefault();
        }
        if (event.dataTransfer) {
          event.dataTransfer.dropEffect = "copy";
        }
      };
      const emitFileDrag = (kind, event, includeFiles = false) => {
        acceptFileDrag(event);
        const p = pointerPosition(canvas, event);
        emit(kind, rawId, p.x, p.y, 0, includeFiles ? draggedFileNames(event) : "");
      };
      const hostHasFocus = () =>
        document.activeElement === canvas || document.activeElement === textInput;
      const blurTargetIsHost = event =>
        event.relatedTarget === canvas || event.relatedTarget === textInput;
      const emitBlurIfOutsideHost = event => {
        if (blurTargetIsHost(event)) return;
        queueMicrotask(() => {
          if (!hostHasFocus()) {
            emit(12, rawId);
          }
        });
      };
      const focusInputTarget = () => {
        if (textState.imeAllowed) {
          focusWithoutScroll(textInput);
        } else {
          focusWithoutScroll(canvas);
        }
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
        focusInputTarget();
        const p = pointerPosition(canvas, event);
        emit(23, rawId, p.x, p.y, event.button);
      });
      add(canvas, "pointerup", event => {
        const p = pointerPosition(canvas, event);
        emit(24, rawId, p.x, p.y, event.button);
      });
      // Normalize a DOM wheel event into the window library delta convention.
      // This mirrors moui/backend/web/browser_runtime.js normalizeCanvasWheelDelta
      // (same invert-deltaY, expand-deltaMode semantics); keep the two in sync.
      // DOM reports positive deltaY for downward scroll (and line/page delta
      // modes), while the library convention (shared with the Windows, macOS,
      // and Linux backends) is positive for upward scroll. Invert the vertical
      // component and expand deltaMode into pixels.
      const wheelDelta = event => {
        const deltaMode = Number(event?.deltaMode) || 0;
        const rawX = Number(event?.deltaX) || 0;
        const rawY = Number(event?.deltaY) || 0;
        const lineHeight = Math.max(
          1,
          Number.parseFloat(
            (typeof getComputedStyle === "function"
              ? getComputedStyle(canvas.parentElement ?? canvas)?.lineHeight
              : "") ?? "",
          ) || 16,
        );
        const pageHeight = Math.max(
          1,
          canvas.parentElement?.getBoundingClientRect?.().height ||
            canvas.parentElement?.clientHeight ||
            canvas.clientHeight ||
            1,
        );
        const multiplier =
          deltaMode === 1 ? lineHeight : deltaMode === 2 ? pageHeight : 1;
        return {
          x: rawX * multiplier,
          y: -rawY * multiplier,
        };
      };
      add(canvas, "wheel", event => {
        event.preventDefault();
        const delta = wheelDelta(event);
        emit(30, rawId, Math.round(delta.x), Math.round(delta.y));
      }, { passive: false });
      add(canvas, "dragenter", event => emitFileDrag(60, event, true));
      add(canvas, "dragover", event => emitFileDrag(61, event));
      add(canvas, "drop", event => emitFileDrag(62, event, true));
      add(canvas, "dragleave", event => emitFileDrag(63, event));
      add(canvas, "focus", () => emit(11, rawId));
      add(canvas, "blur", emitBlurIfOutsideHost);
      add(canvas, "keydown", event => {
        if (textState.imeAllowed) {
          if (event.isComposing || !shouldForwardTextInputKey(event)) {
            return;
          }
          event.preventDefault();
        }
        emit(40, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(canvas, "keyup", event => {
        if (
          textState.imeAllowed &&
          (event.isComposing || !shouldForwardTextInputKey(event))
        ) {
          return;
        }
        emit(41, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(textInput, "keydown", event => {
        if (event.isComposing || !shouldForwardTextInputKey(event)) {
          return;
        }
        event.preventDefault();
        emit(40, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(textInput, "keyup", event => {
        if (event.isComposing || !shouldForwardTextInputKey(event)) {
          return;
        }
        emit(41, rawId, 0, 0, 0, event.key || event.code || "");
      });
      add(textInput, "focus", () => emit(11, rawId));
      add(textInput, "blur", emitBlurIfOutsideHost);
      add(textInput, "compositionstart", () => {
        composing = true;
        compositionText = "";
        suppressNextInputText = "";
        suppressNextInputUntil = 0;
        emit(43, rawId);
      });
      add(textInput, "compositionupdate", event => {
        const text = event.data || "";
        compositionText = text;
        emit(44, rawId, 0, text.length, 0, text);
      });
      add(textInput, "compositionend", event => {
        composing = false;
        const text = event.data || "";
        compositionText = text;
        suppressNextInputText = text;
        suppressNextInputUntil = text ? Date.now() + 250 : 0;
        emit(42, rawId, 0, 0, 0, text);
        textInput.value = "";
      });
      add(textInput, "beforeinput", event => {
        if (event.isComposing || composing) {
          return;
        }
        if (event.inputType === "deleteContentBackward") {
          event.preventDefault();
          emit(45, rawId, 1, 0);
        } else if (event.inputType === "deleteContentForward") {
          event.preventDefault();
          emit(45, rawId, 0, 1);
        }
      });
      add(textInput, "input", event => {
        const now = Date.now();
        if (!composing && now > suppressNextInputUntil) {
          compositionText = "";
          suppressNextInputText = "";
          suppressNextInputUntil = 0;
        }
        const data = inputEventData(event);
        const inputType = event.inputType || "";
        const composingInput =
          event.isComposing ||
          composing ||
          inputType === "insertCompositionText" ||
          inputType === "deleteCompositionText";
        if (composingInput) {
          return;
        }
        const suppressingCompositionInput =
          inputType === "insertFromComposition" && suppressNextInputText;
        const suppressingCompositionFragment =
          compositionText &&
          (composing || now <= suppressNextInputUntil) &&
          (data === compositionText || compositionText.endsWith(data));
        const suppressingDuplicateCommit =
          suppressNextInputText &&
          now <= suppressNextInputUntil &&
          (data === suppressNextInputText || suppressNextInputText.endsWith(data));
        if (
          data &&
          !suppressingCompositionInput &&
          !suppressingCompositionFragment &&
          !suppressingDuplicateCommit
        ) {
          emit(42, rawId, 0, 0, 0, data);
        }
        if (suppressingDuplicateCommit || now > suppressNextInputUntil) {
          suppressNextInputText = "";
          suppressNextInputUntil = 0;
        }
        if (!composing && now > suppressNextInputUntil) {
          compositionText = "";
        }
        textInput.value = "";
      });
      add(window, "resize", () =>
        emit(10, rawId, canvas.width, canvas.height, window.devicePixelRatio || 1.0),
      );
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
      textInputs.get(rawId)?.input?.remove?.();
      textInputs.delete(rawId);
    },
    set_ime_allowed(rawId, allowed) {
      const state = textInputs.get(rawId);
      if (!state) return;
      state.imeAllowed = !!allowed;
      if (state.imeAllowed) {
        focusWithoutScroll(state.input);
      } else {
        state.input.value = "";
        state.input.style.left = "-10000px";
        state.input.style.top = "0";
        if (document.activeElement === state.input) {
          focusWithoutScroll(state.canvas);
        }
      }
    },
    set_ime_cursor_area(rawId, x, y, width, height) {
      const state = textInputs.get(rawId);
      if (!state) return;
      state.input.style.left = `${Number.isFinite(x) ? x : 0}px`;
      state.input.style.top = `${Number.isFinite(y) ? y : 0}px`;
      state.input.style.width = `${Math.max(1, Math.round(width || 1))}px`;
      state.input.style.height = `${Math.max(1, Math.round(height || 1))}px`;
    },
    set_ime_surrounding_text(rawId, text, cursor, anchor) {
      const state = textInputs.get(rawId);
      if (!state) return;
      state.surroundingText = stringValue(text);
      state.surroundingCursor = cursor | 0;
      state.surroundingAnchor = anchor | 0;
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
