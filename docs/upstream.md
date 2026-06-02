# Upstream Pin

- Repository: `rust-windowing/winit`
- Commit: `b5252f136632aac27937ad00fbd6764f812d4922`
- Workspace version: `0.31.0-beta.2`

# Reference Scope

The pinned upstream checkout is the reference for shared `winit`-style API
shape, event semantics, AppKit behavior, and example parity audits. This fork
tracks the `moonbit-community/window` 0.5.1 API surface while adapting the
current reference behavior where it is useful for MoUI.

# Current Migration Scope

This repository has moved beyond the original macOS-only bootstrap slice. The
current scope is a cross-platform MoUI-oriented window layer:

- `dpi` value types and scale helpers
- core window/event/control-flow data structures
- a macOS backend on the `native` target through AppKit
- a Web backend on the `wasm-gc` target through browser canvas and DOM events
- a Windows preview backend on the `native` target through Win32
- a Linux preview backend on the `native` target through Wayland + xdg-shell
- event loop APIs: `run_app`, `run_app_on_demand`, `pump_app_events`, `EventLoopProxy::wake_up`, and `EventLoop::builder` with macOS startup attributes
- `ApplicationHandler::new_events` with `StartCause::{Init, Poll, WaitCancelled, ResumeTimeReached}`
- `WindowEvent::{CloseRequested, Destroyed, Focused, KeyboardInput, ModifiersChanged, Moved, PointerMoved, PointerEntered, PointerLeft, PointerButton, MouseWheel, SurfaceResized, ScaleFactorChanged, ThemeChanged, Occluded, RedrawRequested}`
- platform examples and host-aware build/runtime smoke scripts

Known deltas against upstream `winit`:

- macOS is the most complete backend and remains the primary AppKit parity
  target.
- Web, Linux, and Windows intentionally expose preview or experimental support
  where MoUI needs early cross-platform coverage before those targets are fully
  upstream-aligned.
- X11 and other Unix backends are not implemented in this fork.
- Build smoke and runtime smoke are tracked separately in
  `docs/platform-gaps.md`; pending runtime evidence is not a soft pass.
