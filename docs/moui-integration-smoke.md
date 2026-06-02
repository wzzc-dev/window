# MoUI Integration Smoke

This checklist defines the evidence needed before a backend is called
MoUI-ready. It complements `docs/platform-gaps.md`: that document records the
current evidence matrix, while this document defines the acceptance shape for
future MoUI integration runs.

## Repository Gate

Run these from the repository root before collecting runtime evidence:

```bash
bash scripts/check_ci.sh
scripts/check_moon_baseline.sh
scripts/check_moui_readiness.sh
scripts/check_moui_evidence.sh
moon info
moon info web --target wasm-gc
```

`bash scripts/check_ci.sh` is host-aware and only builds the matching native
backend. Run Linux and Windows checks on matching hosts, not through a host
override on macOS.
`scripts/check_moui_evidence.sh` keeps the evidence recorder honest: it checks
that passed native evidence cannot be generated on the wrong local host without
an explicit matching `--host`, and that the helper remains stdout-only.

For the Web backend, `scripts/check_moui_web_smoke.sh` builds the concrete
consumer-style smoke entry point at `examples/moui_web_smoke`. It verifies the
host page and wasm artifact include the canvas identity, surface/scale,
redraw, resize, pointer, and keyboard evidence hooks that the browser runtime
will exercise. For browser runtime evidence, run `scripts/smoke_runtime.sh web`
and open `http://127.0.0.1:8000/examples/moui_web_smoke/index.html`; the page
must reach `PASS` after observing `canvas_id=moui-web-smoke-canvas`, a
`640x360` surface, pointer `24,32`, and keyboard text `a`.

For the macOS backend, `scripts/check_moui_macos_smoke.sh` builds the concrete
consumer-style smoke entry point at `examples/moui_macos_smoke`. Run
`scripts/check_moui_macos_smoke.sh --run` on a macOS host to verify surface
creation, scale reporting, `Window::window_handle()`,
`Window::content_view_handle()`, monitor/current-monitor probes, cursor state,
resize delivery, redraw plus `pre_present_notify`, representative
pointer/keyboard input, and clean shutdown.

For the Linux backend, `scripts/check_moui_linux_smoke.sh` builds the concrete
consumer-style smoke entry point at `examples/moui_linux_smoke`. Run
`scripts/check_moui_linux_smoke.sh --run` inside a Wayland session or Weston to
verify surface creation, scale reporting, public Wayland handles,
`present_rgba_pixels(...)`, monitor/current-monitor probes, cursor state,
resize delivery, redraw plus `pre_present_notify`, and clean shutdown.
Representative pointer/keyboard input is logged when the compositor or operator
supplies it; keep Linux runtime input evidence pending until that path is
observed on a matching host. For full Linux input evidence, run
`WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run` or
`scripts/check_moui_linux_smoke.sh --run --require-input`.

For the Windows backend, `scripts/check_moui_windows_smoke.sh` builds the
concrete consumer-style smoke entry point at `examples/moui_windows_smoke`. Run
`scripts/check_moui_windows_smoke.sh --run` on a Windows host to verify surface
creation, scale reporting, `Window::window_handle()`,
monitor/current-monitor probes, cursor state, resize delivery, redraw plus
`pre_present_notify`, representative pointer/keyboard/text input, and clean
shutdown.

## Backend Runtime Evidence

Use the backend helper first:

```bash
scripts/smoke_runtime.sh <backend>
```

Record the command, host, date, and observed facts in `docs/platform-gaps.md`.
Do not mark a backend runtime smoke as passed unless the window or page opens,
resize/redraw delivery is observed, representative input is delivered, and the
runtime exits cleanly.
Use `scripts/record_moui_evidence.sh <backend>` to generate a standard evidence
entry after the run; the helper prints to stdout only so status changes still
require review. For native backends, passed evidence must come from a matching
host or explicitly name the remote matching host with `--host`. Passed evidence
must also explicitly include `--window-opened yes`, `--resize-redraw yes`,
`--input yes`, and `--clean-exit yes`. Use `--consumer-input yes` only for the
separate MoUI consumer input field after the downstream smoke observes input
through the public backend API. Any non-pending MoUI consumer evidence field
requires `--consumer-command` with the exact downstream command.

Copyable recorder commands for the current evidence shape:

```bash
scripts/record_moui_evidence.sh web \
  --status passed \
  --commands "bash scripts/check_ci.sh; scripts/smoke_runtime.sh web; browser http://127.0.0.1:8000/examples/moui_web_smoke/index.html" \
  --window-opened yes \
  --resize-redraw yes \
  --input yes \
  --clean-exit yes \
  --consumer-command "scripts/smoke_runtime.sh web; browser http://127.0.0.1:8000/examples/moui_web_smoke/index.html" \
  --surface yes \
  --redraw yes \
  --resize-scale yes \
  --consumer-input yes \
  --text-input yes \
  --renderer-handle yes \
  --monitor-cursor pending \
  --clean-shutdown yes \
  --notes "page reached PASS with canvas_id=moui-web-smoke-canvas, pointer 24,32, keyboard text a, and no browser console warnings/errors"

scripts/record_moui_evidence.sh macos \
  --status passed \
  --commands "WINDOW_CI_HOST=macos bash scripts/check_ci.sh; scripts/check_moui_macos_smoke.sh --run" \
  --window-opened yes \
  --resize-redraw yes \
  --input yes \
  --clean-exit yes \
  --consumer-command "scripts/check_moui_macos_smoke.sh --run" \
  --surface yes \
  --redraw yes \
  --resize-scale yes \
  --consumer-input yes \
  --text-input yes \
  --renderer-handle yes \
  --monitor-cursor yes \
  --clean-shutdown yes \
  --notes "surface/scale and monitor count are environment-sensitive in CLI-launched AppKit smoke; latest local run printed surface size=1x0 scale=1 and monitors count=0 primary=false current=false, with nonzero handles, cursor Icon(Text), resize/redraw, pointer 24,32, keyboard text a, and Destroyed before finished"

scripts/record_moui_evidence.sh linux \
  --status pending \
  --host "Linux Wayland/Weston CI" \
  --commands "WINDOW_CI_HOST=linux bash scripts/check_ci.sh; scripts/smoke_runtime.sh linux; WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run" \
  --window-opened pending \
  --resize-redraw pending \
  --input pending \
  --clean-exit pending \
  --consumer-command "WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run" \
  --surface pending \
  --redraw pending \
  --resize-scale pending \
  --consumer-input pending \
  --text-input pending \
  --renderer-handle pending \
  --monitor-cursor pending \
  --clean-shutdown pending \
  --notes "replace pending values only with observed matching-host Wayland facts, including monitor/current-monitor and cursor probes"

scripts/record_moui_evidence.sh windows \
  --status pending \
  --host "Windows Win32 CI" \
  --commands "WINDOW_CI_HOST=windows bash scripts/check_ci.sh; scripts/smoke_runtime.sh windows; scripts/check_moui_windows_smoke.sh --run" \
  --window-opened pending \
  --resize-redraw pending \
  --input pending \
  --clean-exit pending \
  --consumer-command "scripts/check_moui_windows_smoke.sh --run" \
  --surface pending \
  --redraw pending \
  --resize-scale pending \
  --consumer-input pending \
  --text-input pending \
  --renderer-handle pending \
  --monitor-cursor pending \
  --clean-shutdown pending \
  --notes "replace pending values only with observed matching-host Win32 facts, including monitor/current-monitor and cursor probes"
```

## MoUI Consumer Evidence

After the repository-level backend smoke passes, run a MoUI consumer smoke that
uses the selected backend through the same public package API MoUI will depend
on. Record the exact downstream command and these observed facts:

- top-level surface creation succeeds with a nonzero initial surface size
- redraw flow works: `request_redraw`, `RedrawRequested`, and
  `pre_present_notify` occur in order
- resize flow reports the new physical surface size and scale factor
- representative pointer and keyboard input reach the MoUI event layer
- representative keyboard text or IME commit text reaches the MoUI event layer
- the renderer receives the expected platform handle or canvas identity
- monitor/current-monitor queries and cursor state mutation use the public
  backend API without private backend lookup
- clean shutdown delivers close/destroy handling without leaked loop state
- native runtime smokes must print a `Destroyed` sentinel before `finished` so
  the evidence proves lifecycle teardown, not just process return

Backend-specific handle expectations:

- macOS: renderer setup uses `Window::content_view_handle()` or
  `Window::window_handle()` content-view semantics, not private AppKit lookup
- Web: renderer setup uses `Window::canvas_id()` plus `web/runtime.js`
  imports and exported `web_dispatch_event`
- Linux: renderer setup uses Wayland handles (`wl_display`, `wl_surface`,
  `xdg_surface`, `xdg_toplevel`) or `present_rgba_pixels(...)` for CPU frames
- Windows: renderer setup uses the public raw-window-handle surface and covers
  Win32 keyboard, mouse, and IME delivery

If the MoUI consumer smoke fails, keep the backend status pending in
`docs/platform-gaps.md` and record the first actionable failure.
