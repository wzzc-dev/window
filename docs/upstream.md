# Upstream Pin

- Repository: `moonbit-community/window` (`Milky2018/window`)
- Release: `0.5.4`
- Commit: `46400890f6a45d66f8123d1111ea50b0b45939ba`
- Secondary reference: `rust-windowing/winit` (API shape / AppKit behavior audits)

# Reference Scope

This fork tracks `moonbit-community/window` 0.5.4 for the shared `core` /
`dpi` / macOS AppKit surface, and vendors a local `windowing` package equivalent
to upstream `Milky2018/windowing` for raw handle contracts.

# Current Migration Scope

The current scope is a cross-platform MoUI-oriented window layer:

- `dpi` value types and scale helpers
- `windowing` raw window/display handle contracts
- core window/event/control-flow data structures
- a macOS backend on the `native` target through AppKit (synced toward upstream 0.5.4 seams)
- a Web backend on the `wasm-gc` target through browser canvas and DOM events
- a Windows preview backend on the `native` target through Win32
- a Linux preview backend on the `native` target through Wayland + xdg-shell
- Android / iOS / HarmonyOS embedding-oriented backends for moui_shell surface injection
- event loop APIs: `run_app`, `run_app_on_demand`, `pump_app_events`, `EventLoopProxy::wake_up`, and `EventLoop::builder`

Known deltas against upstream `moonbit-community/window`:

- Upstream is still macOS-focused; this fork keeps multi-platform MoUI packages.
- MoUI system menu helpers (`set_system_menus`, menu action callbacks) remain
  fork-only on macOS.
- Web, Linux, Windows, Android, iOS, and HarmonyOS are MoUI-oriented packages
  that are not present upstream.
- X11 and other Unix backends are not implemented in this fork.
- Build smoke and runtime smoke are tracked separately in
  `docs/platform-gaps.md`; pending runtime evidence is not a soft pass.
