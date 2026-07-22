# wzzc-dev/window

This repository is a MoonBit workspace containing:

- `modules/window`: the `wzzc-dev/window` compatibility library modeled after `winit`
- `modules/windowing`: the backend-neutral `Milky2018/windowing` handle module

The window module provides native desktop backends, an experimental Web backend
for `wasm-gc`, and host-driven mobile event-loop adapters.

## Platform Support

- macOS: supported on the `native` target through AppKit (`wzzc-dev/window/macos`)
- Windows: preview support on the `native` target through Win32 (`wzzc-dev/window/windows`)
- Linux: preview support on the `native` target through Wayland + xdg-shell (`wzzc-dev/window/linux`)
- Web: experimental browser support on the `wasm-gc` target (`wzzc-dev/window/web`)
- Android, iOS, HarmonyOS: experimental host-driven adapters on the `native`
  target (`wzzc-dev/window/<platform>`); the host supplies lifecycle, surface,
  and input events while the package normalizes them as window events
- Placeholder handle types: Xlib and Xcb
- Not supported yet: X11 and other Unix backends

### Windows Support (Preview)

Use the `wzzc-dev/window/windows` package for Win32 windows and event loops.
The Windows backend currently targets MoonBit `native` builds.

#### MSVC

```powershell
cmd /k "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
```

```powershell
where.exe cl
moon build modules\window\examples\window_windows --target native
moon run modules\window\examples\window_windows --target native
```

#### Mingw

```powershell
where.exe gcc
moon build modules\window\examples\window_windows --target native
moon run modules\window\examples\window_windows --target native
```

### Web Support (Experimental)

Use the `wzzc-dev/window/web` package for browser-hosted `wasm-gc` apps.
The Web backend follows the winit Web model: a `Window` is backed by an
`HTMLCanvasElement`, DOM events are mapped into `@core.WindowEvent`, and the
event loop is driven by browser callbacks instead of blocking the current
thread.

Build the example:

```bash
moon build modules/window/examples/window_web --target wasm-gc
```

Run the local browser example from the repository root:

```bash
node modules/window/examples/window_web/serve.mjs
```

Then open:

```text
http://127.0.0.1:8000/modules/window/examples/window_web/index.html
```

The generated wasm is loaded from:

```text
_build/wasm-gc/debug/build/examples/window_web/window_web.wasm
```

Applications using the Web backend need the browser host glue from
`modules/window/web/runtime.js`. The example `index.html` shows the expected import object:

- `window_web: createWindowWebImports()`
- `spectest.print_char` for MoonBit `println`
- `connectWindowWeb(instance, windowWeb)` before calling `_start()`

The application package must export `web_dispatch_event`; see
`modules/window/examples/window_web/moon.pkg` for the `link.wasm-gc.exports` setting.

### Linux Support (Preview)

Use the `wzzc-dev/window/linux` package for Wayland windows and event loops.
The first Linux backend supports Wayland + `xdg-shell` only; X11 is not part of
this backend.

Install the native development dependencies on Linux:

```bash
sudo apt install libwayland-dev wayland-protocols wayland-scanner pkg-config
```

Build and run the example inside a Wayland session or Weston environment:

```bash
moon build modules/window/examples/window_linux --target native
moon run modules/window/examples/window_linux --target native
```

The build script uses `pkg-config` to locate `wayland-client` and
`wayland-scanner` to generate the `xdg-shell` client protocol files during the
prebuild step.


## Install

```bash
moon add wzzc-dev/window
```

You do **not** need to manually add AppKit/CoreGraphics link flags in your app;
the subpackages provide native link configuration.

Import the subpackages you need directly. This module does **not** expose a
root `@wzzc-dev/window` package.

## Quick Start

Use explicit subpackage imports in your package's `moon.pkg`:

```moonbit
import {
  "wzzc-dev/window/core",
  "wzzc-dev/window/macos",
}

supported_targets = "native"

options("is-main": true)
```

Then write the app in `main.mbt`:

```moonbit
///|
struct App {
  mut window : @macos.Window?
}

///|
pub impl @macos.ApplicationHandler for App with can_create_surfaces(
  self,
  event_loop,
) {
  let attrs = @core.WindowAttributes::default().with_title("window demo")
  let window : @macos.Window? = Some(event_loop.try_create_window(attrs)) catch {
    err => {
      println("error creating window: \{err}")
      event_loop.exit()
      None
    }
  }
  self.window = window
}

///|
pub impl @macos.ApplicationHandler for App with window_event(
  self,
  event_loop,
  _id,
  event,
) {
  match event {
    CloseRequested => event_loop.exit()
    SurfaceResized(_) =>
      match self.window {
        Some(window) => window.request_redraw()
        None => ()
      }
    RedrawRequested => println("redraw requested")
    _ => ()
  }
}

///|
fn main {
  let event_loop = @macos.EventLoop::EventLoop()
  event_loop.run_app({ window: None })
}
```

## Error Model

This library follows MoonBit `raise`-based error handling (typed errors), not
`Result`. For example:

- `EventLoop::try_new()` may raise `@core.EventLoopError`
- `Window::set_cursor_position(...)` may raise `@core.RequestError`
- `Window::request_ime_update(...)` may raise `@core.ImeRequestError`

## macOS Caveats

- `EventLoop` must be created and run on the process main thread.
  `EventLoopBuilder::with_any_thread(true)` does not relax this AppKit
  requirement.
- Methods on an existing `Window` may be called from worker threads.
  AppKit-backed operations synchronously execute on the process main thread,
  matching winit's macOS behavior. Do not block the main thread while waiting
  for a worker that is calling a `Window` method.
- `monitor_ns_screen(...)` returns a retained `NSScreenHandle` snapshot. Keep
  that handle alive while using `objc_handle()`, and resolve it again after a
  display reconfiguration.
- `EventLoop::pump_app_events(...)` is for host-loop integration, not frame-by-frame rendering.
  For frame-driven apps, prefer `run_app()` with `ControlFlow::Poll` or `ControlFlow::WaitUntil`.
- `Window::set_cursor_grab(@core.CursorGrabMode::Confined)` raises `@core.RequestError::NotSupported`.
- `Window::drag_resize_window(...)` raises `@core.RequestError::NotSupported` on macOS.
- `Window::show_window_menu(...)` currently has no native AppKit implementation.
- `@core.CustomCursorSource::Url(...)` and animation cursors are not supported on macOS.
- `Window::set_prefers_home_indicator_hidden(...)`,
  `Window::set_prefers_status_bar_hidden(...)`,
  and `Window::set_preferred_screen_edges_deferring_system_gestures(...)`
  are parity state setters on macOS (no native AppKit effect).

## macOS Renderer Integration

`@macos.Window` implements the `Milky2018/windowing` `HasWindowHandle` and
`HasDisplayHandle` contracts. `Window::window_handle()` returns a structured
`WindowHandle` whose provider keeps the window owner reachable. Resolve the
platform handle only at the renderer boundary. Renderer packages should import
`"Milky2018/windowing"` in their `moon.pkg`:

```moonbit
let raw = try! window.window_handle().as_raw()
match raw {
  @windowing.RawWindowHandle::AppKit(handle) => {
    let ns_view = handle.ns_view()
    // Create the renderer surface from ns_view.
  }
  _ => abort("renderer does not support this window backend")
}
```

The AppKit variant contains the window content view (`NSView*`). It is borrowed:
do not release it or retain it beyond the lifetime of the `WindowHandle`.
Explicitly dropping the underlying window invalidates subsequent `as_raw()`
calls with `HandleError::Unavailable`.

For platform-specific integrations that cannot consume `windowing`,
`Window::content_view_handle()` remains an AppKit escape hatch and raises
`@core.RequestError` if the handle is unavailable.

The window package owns the AppKit window/content-view lookup. Renderer
packages such as `wgpu_mbt` should own Metal or `wgpu` surface setup on top of
that handle. In particular, downstream code should not scan
`NSApplication.windows` or use the internal `rawId` selector to find a window.

For `CAMetalLayer` integration, create/attach/sync the layer in the renderer
layer using the content-view handle. Keep the layer synchronized with:

- `Window::scale_factor()` for `contentsScale`
- `Window::surface_size()` for physical drawable size
- `WindowEvent::SurfaceResized` and `WindowEvent::ScaleFactorChanged` for
  resize/scale resync
- the content view bounds for the layer frame
- autoresizing or an explicit renderer-side sync step for future view resizes

## API Overview

Import only the subpackages you need:

- `@wzzc-dev/window/core`: core event/types (`WindowEvent`, `ControlFlow`,
  `WindowAttributes`, keyboard/mouse/IME data types)
- `@wzzc-dev/window/macos`: macOS runtime API (`EventLoop`, `ActiveEventLoop`,
  `Window`, `EventLoopProxy`, `ApplicationHandler`)
- `@wzzc-dev/window/windows`: Windows runtime API (`EventLoop`,
  `ActiveEventLoop`, `Window`, `EventLoopProxy`, `ApplicationHandler`)
- `@wzzc-dev/window/linux`: Linux Wayland runtime API (`EventLoop`,
  `ActiveEventLoop`, `Window`, `EventLoopProxy`, `ApplicationHandler`) plus
  Wayland extension APIs exposing display/surface/xdg handles
- `@wzzc-dev/window/web`: browser `wasm-gc` runtime API (`EventLoop`,
  `ActiveEventLoop`, `Window`, `EventLoopProxy`, `ApplicationHandler`) plus
  Web extension APIs for canvas binding and poll strategy selection
- `@wzzc-dev/window/android`, `@wzzc-dev/window/ios`, and
  `@wzzc-dev/window/harmonyos`: host-driven native event-loop adapters for
  platform lifecycle, surface, and input event normalization
- `@wzzc-dev/window/dpi`: logical/physical size and position types
- `@Milky2018/windowing`: structured raw handles and provider traits

`WindowEvent::into_winit_events()` is available when you want a
`winit`-style compatibility projection.

## Web Caveats

- Web support currently targets browser environments with `wasm-gc`; Node or
  headless environments without DOM APIs are not the supported runtime.
- `run_app`/`try_run_app`/`spawn_app` register browser callbacks and return
  instead of blocking the thread.
- `ControlFlow::Poll` uses `requestAnimationFrame` by default. `Wait` responds
  to DOM/proxy wakeups, and `WaitUntil` uses browser timers.
- Native-only features such as taskbar integration, native decorations, window
  levels, system menus, native drag-window, exclusive fullscreen, and precise
  monitor information are intentionally unsupported or no-op on Web.
- Raw window/display handles return stable placeholder values; use Web
  extension APIs such as `Window::canvas_id()` for canvas identity.

## Windows Caveats

- Windows support is preview quality and targets desktop Win32 through the
  MoonBit `native` backend.
- Use a working C toolchain before building examples. MSVC users should run
  `vcvarsall.bat`; Mingw users should ensure `gcc` is on `PATH`.
- Some APIs that are meaningful on macOS or Web may be state-only, no-op, or
  `NotSupported` on Windows while parity work continues.

## Linux Caveats

- Linux support currently targets Wayland + `xdg-shell`; X11 is intentionally
  left unsupported in this package.
- The first backend attaches a small SHM placeholder buffer so windows map even
  when the app has not provided a renderer yet.
- `Window::present_rgba_pixels(...)` presents renderer-owned RGBA pixel frames
  through Wayland `wl_shm` for CPU raster renderers such as MoUI Skia.
- Keyboard events currently expose native XKB key codes without text decoding;
  text input and IME are future work.
- Decorations, taskbar integration, system menus, native drag-window, exclusive
  fullscreen, precise monitor metadata, custom cursors, and rich raw-handle
  parity are currently unsupported, no-op, or placeholder behavior.

## Rich Event Matching

You can also match native event variants directly:

```moonbit
///|
pub impl @macos.ApplicationHandler for App with window_event(
  self,
  event_loop,
  _id,
  event,
) {
  match event {
    PointerMoved(_, position, _, _) =>
      println("pointer moved: \{position}")
    DragEntered(paths, position) =>
      println("drag entered at \{position}: \{paths}")
    CloseRequested => event_loop.exit()
    _ => ()
  }
}
```

## Repository Examples

The window module includes runnable examples under `modules/window/examples/*`.
From the repository root, run:

```bash
moon run modules/window/examples/window --target native
moon run modules/window/examples/window_windows --target native
moon build modules/window/examples/window_web --target wasm-gc
moon run modules/window/examples/window_linux --target native
```

## Validation

Use the repository gate before publishing or committing backend changes:

```bash
scripts/check_ci.sh
```

For the slower upstream-vs-MoonBit example transcript comparison:

```bash
RUN_EXAMPLE_TRANSCRIPTS=1 scripts/check_ci.sh
```

See the repository's `docs/testing.md` for why the local gate uses
`moon test --release` for framework-linked macOS tests.
