# Platform Gaps

Single-source-of-truth for every `wzzc-dev/window` API deviation relative to the
macOS reference implementation. Each gap is classified with an explicit contract.

## Contract taxonomy

| Contract | Meaning |
|----------|---------|
| **Native** | OS-native implementation; behavior matches macOS reference. |
| **NotSupported** | Raises `RequestError::not_supported(...)`; callers must handle. |
| **StateOnly** | Method stores the value and returns it; no OS effect. |
| **NoOp** | Method accepts the call and returns silently; no OS effect, no error. |
| **Placeholder** | Returns a synthetic default value (e.g. default monitor). |

**Platforms**: macOS (reference), Windows, Linux, Web, Android, iOS, HarmonyOS, WeChat.

---

## Cursor

| Method | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS | WeChat |
|--------|-------|---------|-------|-----|---------|-----|-----------|--------|
| `set_cursor_icon` | Native | Native | StateOnly | Native (DOM cursor) | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `set_cursor` | Native | Native | StateOnly | Native+StateOnly | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `cursor` | Native | Native | StateOnly | Native+StateOnly | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `set_cursor_visible` | Native | Native | StateOnly | Native (DOM `none`) | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `is_cursor_visible` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `set_cursor_hittest` | Native | Native | StateOnly | StateOnly | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `is_cursor_hittest` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `set_cursor_grab` | Native (Confined unsupported) | Native | **NotSupported** (only None) | **NotSupported** (only None) | NoOp | NoOp | NoOp | **NotSupported** (only None) |
| `set_cursor_position` | Native | Native | **NotSupported** | **NotSupported** | NoOp | NoOp | NoOp | **NotSupported** |
| `create_custom_cursor` | Native | Native | NotSupported | NotSupported | NotSupported | NotSupported | NotSupported | **NotSupported** |

---

## IME (Input Method Editor)

| Method | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS | WeChat |
|--------|-------|---------|-------|-----|---------|-----|-----------|--------|
| `set_ime_allowed` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `set_ime_cursor_area` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `set_ime_hints` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `set_ime_purpose` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `set_ime_surrounding_text` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `request_ime_update` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `ime_allowed` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |

---

## Fullscreen

| Method | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS | WeChat |
|--------|-------|---------|-------|-----|---------|-----|-----------|--------|
| `set_fullscreen(Borderless/Exclusive)` | Native | Native | Native | Native (Fullscreen API) | NoOp | NoOp | NoOp | **NoOp** |
| `fullscreen` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `is_fullscreen` | Native | Native | Native | Native | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `set_simple_fullscreen` | **macOS-only** | NoOp (returns false) | NoOp (returns false) | NoOp (returns false) | N/A | N/A | N/A | **N/A** |
| `simple_fullscreen` | **macOS-only** | NoOp (returns false) | NoOp (returns false) | NoOp (returns false) | N/A | N/A | N/A | **N/A** |
| `set_borderless_game` | **macOS-only** | N/A | N/A | N/A | N/A | N/A | N/A | **N/A** |

**Notes**:
- `set_simple_fullscreen` on macOS enters a borderless fullscreen using the
  native AppKit fullscreen toggle mechanism; it is NOT equivalent to
  `set_fullscreen(Borderless)`. Non-macOS platforms return `false`.
- `set_borderless_game` on macOS enables a high-performance Metal-friendly
  fullscreen mode. No other platform has an equivalent.
- `set_fullscreen(None)` on desktop exits fullscreen; on mobile/WeChat it is
  a no-op (windows are always "fullscreen" in the app frame).

---

## Monitor / Display

| Method | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS | WeChat |
|--------|-------|---------|-------|-----|---------|-----|-----------|--------|
| `available_monitors` | Native (multi) | Native (multi) | Native (wl_output) | Placeholder (single, 800×600) | Placeholder (single) | Placeholder (single) | Placeholder (single) | **Placeholder** (single, 375×812) |
| `primary_monitor` | Native | Native | Native | Placeholder | Placeholder | Placeholder | Placeholder | **Placeholder** |
| `MonitorHandle` | Native AppKit | Native Win32 | Native Wayland | Synthetic (size+scale) | Synthetic (size+scale) | Synthetic (size+scale) | Synthetic (size+scale) | **Synthetic** (size+scale) |
| `VideoMode` | Native | Native | NotSupported | NotSupported | NotSupported | NotSupported | NotSupported | **NotSupported** |

**Notes**:
- Desktop platforms return the actual connected display list.
- Mobile, Web, and WeChat return a single synthetic monitor derived from the
  window/surface dimensions.
- `VideoMode` (resolution switching) is desktop-only; not applicable to
  embedded/web/WeChat environments.

---

## Window State

| Method | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS | WeChat |
|--------|-------|---------|-------|-----|---------|-----|-----------|--------|
| `set_minimized` | Native | Native | Native | NoOp | NoOp | NoOp | NoOp | **NoOp** |
| `is_minimized` | Native | Native | Native | Placeholder (None) | NoOp (false) | NoOp (false) | NoOp (false) | **NoOp** (false) |
| `set_maximized` | Native | Native | Native | NoOp | NoOp | NoOp | NoOp | **NoOp** |
| `is_maximized` | Native | Native | Native | NoOp (false) | NoOp (false) | NoOp (false) | NoOp (false) | **NoOp** (false) |
| `drag_window` | **macOS-only** | N/A | N/A | N/A | N/A | N/A | N/A | **N/A** |
| `drag_resize_window` | **macOS-only** | N/A | N/A | N/A | N/A | N/A | N/A | **N/A** |

---

## Decorations

| Method | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS | WeChat |
|--------|-------|---------|-------|-----|---------|-----|-----------|--------|
| `set_decorations` | Native | Native | Native (Wayland xdg-decoration) | StateOnly | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `is_decorated` | Native | Native | Native | StateOnly | StateOnly | StateOnly | StateOnly | **StateOnly** |
| `uses_client_decorations` | N/A | N/A | **Linux-only** | N/A | N/A | N/A | N/A | **N/A** |

---

## Raw Handles

| Method | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS | WeChat |
|--------|-------|---------|-------|-----|---------|-----|-----------|--------|
| `window_handle` | Native (NSView) | Native (HWND) | Native (Wayland via ExtLinux) | NotSupported | Native (ANativeWindow) | Native (UIView) | Native (XComponent) | **NotSupported** |
| `display_handle` | Native | Native | Native | NoOp (0) | NotSupported | NotSupported | NotSupported | **NotSupported** |
| `HasWindowHandle` | Yes | Yes | Yes | No | Yes | Yes | Yes | **No** |
| `HasDisplayHandle` | Yes | Yes | Yes | No | No | No | No | **No** |

---

## Surface Operations

| Method | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS | WeChat |
|--------|-------|---------|-------|-----|---------|-----|-----------|--------|
| `present_rgba_pixels` | N/A | N/A | Native (SHM) | N/A | Native | Native | Native | **N/A** |
| `clear_color` | N/A | N/A | N/A | N/A | Native | Native | Native | **N/A** |

**Notes**:
- `present_rgba_pixels`/`clear_color` are mobile+raster-surface APIs.
  Desktop/macOS/Windows/Web/WeChat use GPU-only present paths.

---

## System Theme

| Method | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS | WeChat |
|--------|-------|---------|-------|-----|---------|-----|-----------|--------|
| `system_theme` | Native | Native (Win10+) | Placeholder (None) | Native (prefers-color-scheme) | Placeholder (None) | Placeholder (None) | Placeholder (None) | **Placeholder** (None) |

---

## Multi-Window

| macOS | Windows | Linux | Web | Mobile | WeChat |
|-------|---------|-------|-----|--------|--------|
| Native (NSApplication multi-window) | Native (multiple HWND) | Native (multiple Wayland surfaces) | Native (multiple canvas) | NoOp (single surface) | **NoOp** (single canvas) |

---

## WeChat-specific notes

WeChat Mini Programs have fundamental platform constraints that prevent parity
with desktop APIs:

1. **Single canvas only**: one `WindowId(0)` with a single canvas element.
   Multi-window APIs are no-ops.

2. **No native cursor API**: Mini Programs run inside WeChat's sandboxed WebView
   environment. Cursor icon/visibility/grab/position changes are not supported
   by the platform runtime. State is stored but has no visual effect.

3. **No native IME API**: Text input is handled by the Mini Program's own
   `<input>` / `<textarea>` components, not by OS-level IME composition events.
   IME state is stored for API compatibility but does not drive composition
   windows.

4. **Touch-only input**: `WechatTouch` events (TouchStart/Move/End/Cancel) are
   the primary input. The `WechatEvent` enum carries these as platform events;
   they are converted to `WindowEvent::Pointer*` variants by the MoUI backend.

5. **No fullscreen API**: Mini Programs render inside a fixed viewport. The
   fullscreen methods are state-only no-ops.

6. **Synthetic lifecycle**: `run_app()` dispatches a fixed sequence of synthetic
   events (Init, Poll, RedrawRequested). The Mini Program runtime calls
   `handle_event`, `handle_resumed`, `handle_suspended`, etc. explicitly.

7. **Direct-canvas-callback route**: WeChat does NOT integrate with
   `moui/backend/common` for cross-platform event normalization.
   Instead, the `wechat_canvas_provider.mbt` directly creates host renderers
   from WeChat's `WechatEvent` → `WindowEvent` conversion. This is documented
   as the fixed direct-canvas exception in the budget-free Platform Bridge
   boundary validator (ADR 0020).
