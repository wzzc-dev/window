# Mobile Hosted Backend

This document freezes the **hosted-only** mobile contract for
`wzzc-dev/window/{android,ios,harmonyos}`.

Mobile backends own the OS application entry, native surface, and input pump.
Applications (including MoUI) implement `ApplicationHandler` only. They never
supply production surface pointers through inject/bind APIs.

`moui_shell` is **not** part of the product host path. Useful native glue may be
ported by source copy into `window/*/native` or `window/*/template`, then rewritten so
window owns lifecycle. No runtime or build dependency on `moui_shell` remains
for the hosted path.

## Architecture

```text
window/{android,ios,harmonyos}/template
        │ C / JNI / ObjC / NAPI entry
        ▼
window/{android|ios|harmonyos}
  native glue  →  HostCmd queue  →  EventLoop pump / run
        │                                  │
        │                           ApplicationHandler
        ▼                                  ▼
  Window + raw handles              app / MoUI renderer
```

Internal modules (same shape per platform package):

| Module | Role |
|--------|------|
| host queue | ordered platform commands → lifecycle / window events |
| lifecycle | OS state → `resumed` / `suspended` / surfaces |
| window store | `WindowId` → native object + generation |
| input | OS input → `@core` pointer / key / IME events |
| native | FFI only; avoid business logic in C/ObjC when possible |

## ApplicationHandler contract

App-facing lifecycle is **only** the existing open trait hooks:

- `new_events` / `resumed` / `suspended`
- `can_create_surfaces` / `destroy_surfaces`
- `memory_warning`
- `window_event` / `device_event` / `about_to_wait` / `proxy_wake_up`
- platform extras such as `standard_key_binding` when present

### Canonical host → handler mapping

| Host condition | Handler / events |
|----------------|------------------|
| Process start, loop running | `new_events(Init)` then pump |
| Foreground + interactive | `resumed` |
| Native surface ready | `can_create_surfaces`, then `create_window` / GPU bind allowed |
| Surface lost / teardown | `destroy_surfaces` (bump generation) |
| Background | `suspended` |
| Low memory | `memory_warning` |
| Process exit | destroy path + loop exit as platform allows |

**Ordering invariants (non-negotiable):**

1. `resumed` before `can_create_surfaces` for a foreground+surface session.
2. `destroy_surfaces` before `suspended` when the host tears down the surface
   while leaving the process alive.
3. `create_window` before surfaces are allowed → hard `RequestError`, never
   silent fake handles.
4. After `destroy_surfaces`, window ids may remain until the app drops them, but
   **handles are invalid**; handle queries return `0` / empty / error; drawing
   without rebuild is an application bug.

### Surface generation

- Monotonic integer, starts at `0`, increments on each surface init and each
  surface teardown.
- GPU consumers **must** drop swapchains on `destroy_surfaces` and recreate
  after the next `can_create_surfaces`.
- Tests assert generation or raw handle inequality across epochs.

## HostCmd (Android reference)

Host (native OS or in-process simulator) pushes ordered commands. Production
native glue and host-sim tests share this queue.

| Command | Meaning |
|---------|---------|
| `Start` | Host activity/application started |
| `Resume` | Foreground interactive |
| `Pause` / `Stop` | Background transition signal |
| `SurfaceInit(handle, token, width, height, scale)` | Native surface ready |
| `SurfaceTerm` | Native surface lost |
| `SurfaceResize(width, height, scale)` | Size / density change |
| `PointerMoved` / `PointerButton` | Touch stream |
| `KeyboardText` | Committed text (IME MVP) |
| `MemoryWarning` | Low memory |
| `Destroy` | Host destroy / process exit path |

Desktop-style `proxy_wake_up` remains available through `EventLoopProxy`.

## Thread rules

| Platform | Rule |
|----------|------|
| Android | Host commands and UI-related window APIs on the Activity / looper thread |
| iOS | UIKit and host dispatch on the main thread only |
| HarmonyOS | Ability / UI thread as required by XComponent |

Debug builds should assert the cheap thread checks when native glue lands.

## Templates

Installable minimal hosts live under `{android,ios,harmonyos}/template/`:

- Manifest / Xcode / Ability entry
- Load the package native library
- Enter the hosted EventLoop
- Sample `ApplicationHandler` that logs lifecycle (and presents one frame when
  GPU sample exists)

Templates are **not** a second shell product. Store signing and app identity
stay outside this repository.

## Port map from `moui_shell` (read-only inventory)

Copy + rewrite ownership; **do not** submodule shell.

| Source (moui_shell) | Target idea | Port? |
|---------------------|-------------|-------|
| `android/embedder/.../MoUIActivity.kt` + SurfaceView | `android/template` + thin activity or NativeActivity | Entry/surface only |
| `android/embedder/.../moui_embedding_jni.cpp` | `android/native/*` host bridge | Surface/input only; **drop** embedding ABI v1 |
| `ios/embedder` UIView / bridge | `ios/native` + `ios/template` | Lifecycle/touch only |
| `harmonyos/embedder` XComponent NAPI | `harmonyos/native` + template | Lifecycle/touch only |
| `embedding/*` API v1, plugins, platform-views, shell.json | — | **Out of window scope** |

## Milestones

| ID | Meaning |
|----|---------|
| M1 | Hosted loop + host-sim + template install; lifecycle/touch logs |
| M2 | Real raw handles readable by GPU consumers |
| M3 | At least one real present/clear or successful swapchain create |
| M4 | MoUI cutover: destroy/recreate across background without crash |

MoUI-ready on a mobile OS requires **M3+**. HarmonyOS may lag device M3 while
keeping the same semantic machine and host-sim coverage.

## Explicit non-goals (MVP)

- Soft keyboard / full IME beyond committed text MVP
- Safe area / display cutout as first-class events
- Orientation lock APIs
- Multi-window
- Clipboard / DnD as window-owned APIs
- Dual stack inject compatibility layer

## Public API rule

Mobile packages **must not** expose:

- `bind_surface`
- `inject_*`

Host bridge symbols used by native glue and host-sim (for example `host_push`)
are the supported way to feed the queue.


## Native bridge (M2 path)

Each mobile package ships a small C host queue in the package directory
(`native_*_host.c`):

1. OS / JNI / UIKit / NAPI calls `mbw_*_host_on_*` which **enqueue** events.
2. Each `EventLoop` pump calls `host_drain_native_queue()` which polls C via
   `mbw_*_host_poll_raw` and converts to `HostCmd` → `host_push`.
3. Pure host-sim tests may call `host_push` directly without C.

This avoids reverse MoonBit→C exports from library packages (which do not link
as free C symbols for stubs) while keeping production and tests on one queue.

Android also includes `__ANDROID__` JNI methods for `android/template`
`HostedActivity` (surface / pointer / lifecycle).


## Soft present (M3 host path)

Mobile packages expose `Window::present_rgba_pixels` and `Window::clear_color`:

- **Android**: real `ANativeWindow_lock` / `unlockAndPost` when built with
  `__ANDROID__`; host-sim returns success for non-zero handles.
- **iOS / HarmonyOS**: host-sim success when handle non-zero; device GPU
  present remains app/renderer-owned (Metal/EGL) once UIView/XComponent
  ownership is complete.

GPU consumers (MoUI/Skia) should still rebuild swapchains on surface generation
changes and may bypass the soft blit when they have a native GPU path.
