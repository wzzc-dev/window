# wzzc-dev/window

`wzzc-dev/window` is the wzzc-dev fork of `moonbit-community/window`, a MoonBit windowing library modeled after `winit`.
This fork tracks upstream window 0.5.1 and adds the MoUI-oriented Web, Windows, and Linux packages needed before those targets are available upstream.

## Platform Support

- macOS: supported on the `native` target through AppKit (`wzzc-dev/window/macos`)
- Windows: preview support on the `native` target through Win32 (`wzzc-dev/window/windows`)
- Linux: preview support on the `native` target through Wayland + xdg-shell (`wzzc-dev/window/linux`)
- Web: experimental browser support on the `wasm-gc` target (`wzzc-dev/window/web`)
- Not supported yet: X11 and other Unix backends

See `docs/platform-gaps.md` for the current MoUI readiness matrix and
backend-specific build/runtime smoke status. See
`docs/moui-integration-smoke.md` for the additional consumer-side evidence
expected before treating a backend as MoUI-ready.

### macOS Support

Use the `wzzc-dev/window/macos` package for AppKit windows and event loops on
the `native` target.

The default gate builds the macOS backend and examples. For the automated
MoUI-oriented runtime smoke that verifies surface creation, AppKit handles,
resize/redraw delivery, representative pointer/keyboard input, and clean
shutdown:

```bash
scripts/check_moui_macos_smoke.sh --run
```

The matching runtime helper is `scripts/smoke_runtime.sh macos`. It delegates
to the same smoke script so the source check and runtime sentinel checks stay
on one path.

### Windows Support (Preview)

Use the `wzzc-dev/window/windows` package for Win32 windows and event loops.
The Windows backend currently targets MoonBit `native` builds.

For the MoUI-oriented smoke artifact on a Windows host:

```bash
scripts/check_moui_windows_smoke.sh
scripts/check_moui_windows_smoke.sh --run
bash scripts/capture_moui_runtime_evidence.sh windows --log artifacts/moui-windows-runtime.log
```

When a Windows runtime transcript is captured on another machine, validate it
before recording evidence:

```bash
scripts/check_moui_runtime_log.sh windows <captured-log>
```

The Windows runtime smoke replays its captured transcript through the same log
verifier before accepting `scripts/check_moui_windows_smoke.sh --run`.
On a matching Windows host, `bash scripts/capture_moui_runtime_evidence.sh windows
--log <path>` runs the host CI branch, saves the transcript, verifies it, and
prints the standard evidence entry for review.
The current reviewed Windows matching-host transcript is
`artifacts/moui-windows-runtime.log` from 2026-06-07; it passed
`scripts/check_moui_runtime_log.sh windows` with HWND/HINSTANCE/raw handle
identity, monitor/current-monitor, cursor, IME, resize/redraw,
pointer/keyboard/text input, and clean teardown evidence.

#### MSVC

```powershell
cmd /k "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
```

```powershell
where.exe cl
moon build .\examples\window_windows\ --target native
moon run .\examples\window_windows\ --target native
```

#### Mingw

```powershell
where.exe gcc
moon build .\examples\window_windows\ --target native
moon run .\examples\window_windows\ --target native
```

### Web Support (Experimental)

Use the `wzzc-dev/window/web` package for browser-hosted `wasm-gc` apps.
The Web backend follows the winit Web model: a `Window` is backed by an
`HTMLCanvasElement`, DOM events are mapped into `@core.WindowEvent`, and the
event loop is driven by browser callbacks instead of blocking the current
thread.

Build the example:

```bash
moon build examples/window_web --target wasm-gc
```

For a noninteractive asset smoke check that verifies the host page, runtime
glue, and generated wasm exports:

```bash
scripts/check_web_assets.sh
```

For the MoUI-oriented consumer smoke artifact that verifies canvas identity,
surface/scale, redraw, resize, pointer, and keyboard evidence hooks:

```bash
scripts/check_moui_web_smoke.sh
scripts/smoke_runtime.sh web
```

The matching interactive smoke helper runs the Web asset and MoUI consumer
preflight, serves the repository, and prints both the generic Web demo URL and
the MoUI consumer page URL.

Run the local browser example from the repository root:

```bash
node examples/window_web/serve.mjs
```

Then open:

```text
http://127.0.0.1:8000/examples/window_web/index.html
```

The generated wasm is loaded from:

```text
_build/wasm-gc/debug/build/wzzc-dev/window/examples/window_web/window_web.wasm
```

Applications using the Web backend need the browser host glue from
`web/runtime.js`. The example `index.html` shows the expected import object:

- `window_web: createWindowWebImports()`
- `spectest.print_char` for MoonBit `println`
- `connectWindowWeb(instance, windowWeb)` before calling `_start()`

The application package must export `web_dispatch_event`; see
`examples/window_web/moon.pkg` for the `link.wasm-gc.exports` setting.

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
moon build examples/window_linux --target native
moon run examples/window_linux --target native
```

For the MoUI-oriented smoke artifact on a Linux Wayland host:

```bash
scripts/check_moui_linux_smoke.sh
scripts/check_moui_linux_smoke.sh --run
WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run
bash scripts/capture_moui_runtime_evidence.sh linux --log artifacts/moui-linux-runtime.log
```

When a Linux runtime transcript is captured on another machine, validate it
before recording evidence:

```bash
scripts/check_moui_runtime_log.sh linux <captured-log>
```

The automated Linux MoUI smoke covers surface creation, public Wayland handles,
`present_rgba_pixels(...)`, resize/redraw delivery, and clean shutdown.
Representative input is logged when supplied by the compositor or operator; it
is still required evidence before calling Linux MoUI-ready. Set
`WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` when running with compositor automation or
manual input capture to require pointer and keyboard evidence; that strict path
also replays the captured transcript through
`scripts/check_moui_runtime_log.sh linux <captured-log>` before passing.
The core runtime path also replays its transcript through
`scripts/check_moui_runtime_log.sh --linux-input pending-ok linux <captured-log>`
so non-input Linux runtime evidence uses the same handle, monitor, and teardown
verifier.
On a matching Linux host, `bash scripts/capture_moui_runtime_evidence.sh linux --log
<path>` runs the host CI branch, saves the strict transcript, verifies it, and
prints the standard evidence entry for review.

The build script uses `pkg-config` to locate `wayland-client` and
`wayland-scanner` to generate the `xdg-shell` and `xdg-decoration` client
protocol files during the prebuild step.


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

## Platform Difference Contracts

Cross-platform gaps should use one of four documented contracts. Use
`NotSupported` when a caller requested a native effect the backend cannot
provide. Use state-only behavior when setters/getters intentionally preserve
consumer-visible state without claiming native OS integration yet. Use no-op
only when an inert command is the documented platform behavior. Use
placeholder values only as stable fallbacks that keep portable code running;
placeholders are not native parity evidence.

The current preview contracts are tracked in `docs/platform-gaps.md`. Examples
include Web placeholder raw handles, Linux SHM placeholder mapping, Linux and
Windows public IME request state probes, and unsupported native-only Web or
preview-backend affordances.

## macOS Caveats

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

`@macos.Window::window_handle()` follows the AppKit raw-window-handle contract
and returns the window content view (`NSView*`) as an opaque `UInt64`.
For renderer integrations that need this boundary explicitly,
`@macos.Window::content_view_handle()` returns the same stable content-view
handle and raises `@core.RequestError` if the handle is unavailable.

The window package owns the AppKit window/content-view lookup. Renderer
packages such as `wgpu_mbt` should own Metal or `wgpu` surface setup on top of
that handle. In particular, downstream code should not scan
`NSApplication.windows` or use the internal `rawId` selector to find a window.

For cross-platform renderer integrations, follow the raw-window-handle shape:
use `Window::display_handle()` plus `Window::window_handle()` as the common
boundary, then use platform extensions only when the renderer needs details
beyond that pair. On Windows, the display/window pair is HINSTANCE/HWND. On
Linux Wayland, it is `wl_display`/`wl_surface`, with `xdg_surface` and
`xdg_toplevel` available through the Linux extension APIs. On Web, raw handles
are placeholder identity values; use `Window::canvas_id()` and `web/runtime.js`
for the actual browser canvas binding. `Window::content_view_handle()` is an
AppKit convenience API for macOS, not a Windows/Linux/Web compatibility target.

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
- `@wzzc-dev/window/dpi`: logical/physical size and position types

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
- The 2026-06-07 matching-host Win32 MoUI smoke passed with verified runtime
  log evidence, but APIs outside that smoke may still be state-only, no-op, or
  `NotSupported` while parity work continues.

## Linux Caveats

- Linux support currently targets Wayland + `xdg-shell`; X11 is intentionally
  left unsupported in this package.
- The first backend attaches a small SHM placeholder buffer so windows map even
  when the app has not provided a renderer yet.
- `Window::present_rgba_pixels(...)` presents renderer-owned RGBA pixel frames
  through Wayland `wl_shm` for CPU raster renderers such as MoUI Skia.
- Basic monitor queries are backed by Wayland `wl_output` geometry/scale, and
  `Window::current_monitor()` follows the surface enter/leave output when the
  compositor reports it.
- Keyboard events currently use a fixed key-code mapping for representative
  character text. Public IME enable/update/disable request state is tracked for
  consumers, while full layout-aware text input and Wayland IME/preedit
  delivery are future work.
- Decorations, taskbar integration, system menus, native drag-window, exclusive
  fullscreen, precise monitor metadata beyond `wl_output`, custom cursors, and
  rich raw-handle parity are currently unsupported, no-op, or placeholder
  behavior.

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

The repository includes runnable examples under `examples/*`.

```bash
moon run examples/window --target native
moon run examples/window_windows --target native
moon run examples/window_linux --target native
moon build examples/window_web --target wasm-gc
```

Native examples are platform-specific: run the macOS, Windows, and Linux
examples on their matching host. The Web example builds with `wasm-gc` and runs
through the browser host page described above.

## Validation

Use the repository gate before publishing or committing backend changes:

```bash
bash scripts/check_ci.sh
scripts/check_moon_baseline.sh
scripts/check_moui_readiness.sh
scripts/check_moui_evidence.sh
```

The gate is host-aware: it always checks shared packages and Web build smoke,
then builds only the native backend and native examples that match the current
host. Set `WINDOW_CI_HOST=macos`, `linux`, `windows`, or `none` to debug a
specific gate path. This selects a gate branch; it does not cross-compile
native stubs, and mismatched host overrides fail fast. Linux and Windows smoke
checks still need matching hosts.

Interactive runtime smoke is separate from the default gate. Use
`scripts/smoke_runtime.sh macos`, `web`, `linux`, or `windows` on a matching
host for native runtime evidence; set `WINDOW_RUNTIME_SMOKE_DRY_RUN=1` to print
the selected command and checklist without launching a window or browser
server. Dry-run mode can be used on any host to audit the selected backend
runtime command.

After a matching-host runtime run, use `bash scripts/record_moui_evidence.sh
<backend>` to print a standard evidence entry for `docs/platform-gaps.md`. The
helper does not edit docs or promote a pending backend automatically. For
native backends, passed evidence must be generated on the matching host or name
the remote matching host with `--host`. Any `--status passed` entry must
explicitly set `--window-opened yes`, `--resize-redraw yes`, `--input yes`, and
`--clean-exit yes`. For Linux/Windows passed evidence, validate the captured
transcript with `scripts/check_moui_runtime_log.sh <linux|windows>
<captured-log>` and include `--runtime-log yes` plus
`--runtime-log-command`. Use `--consumer-input yes` only after downstream MoUI input
delivery has also been observed; backend runtime input and MoUI consumer input
are recorded separately. Any MoUI consumer evidence field also requires
`--consumer-command` so the observed facts are traceable. Use
`--text-input yes` only after the consumer smoke observes keyboard text or IME
commit text through the public backend API. Use
`--monitor-cursor yes` only after the consumer smoke observes monitor/current
monitor queries and cursor state mutation through the public backend API.
`scripts/check_moui_evidence.sh` is the noninteractive guard for that behavior.

For the slower upstream-vs-MoonBit example transcript comparison:

```bash
RUN_EXAMPLE_TRANSCRIPTS=1 bash scripts/check_ci.sh
```

See `docs/testing.md` for why the macOS package currently uses
`moon test --build-only` instead of full framework-linked native test execution.
See `docs/platform-gaps.md` before treating a backend as MoUI-ready; build
smoke and runtime smoke are tracked separately there.
