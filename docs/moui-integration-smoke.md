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
scripts/check_moui_runtime_log.sh <linux|windows> <captured-log>
moon info
moon info web --target wasm-gc
```

`bash scripts/check_ci.sh` is host-aware and only builds the matching native
backend. Run Linux and Windows checks on matching hosts, not through a host
override on macOS.
`scripts/check_moui_evidence.sh` keeps the evidence recorder honest: it checks
that passed native evidence cannot be generated on the wrong local host without
an explicit matching `--host`, and that the helper remains stdout-only.
`scripts/check_moui_runtime_log.sh <linux|windows> <captured-log>` validates
captured matching-host Linux/Windows runtime transcripts before they are used
as evidence.

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
`present_rgba_pixels(...)`, Wayland `wl_output` monitor/current-monitor probes
including `current=true` from surface enter/current-output tracking, cursor
state, `primary_id=0x...`/`current_id=0x...` native monitor ids, public IME
enable/update/disable state, resize delivery, redraw plus `pre_present_notify`,
and clean shutdown.
Representative pointer/keyboard input is logged when the compositor or operator
supplies it; keep Linux runtime input evidence pending until that path is
observed on a matching host. For full Linux input evidence, run
`WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run` or
`scripts/check_moui_linux_smoke.sh --run --require-input`; this strict path
requires pointer evidence and representative keyboard text `a` from the current
fixed key mapping, then replays its captured transcript through
`scripts/check_moui_runtime_log.sh linux <captured-log>` before accepting the
runtime smoke. For Wayland data-device evidence, run
`WINDOW_MOUI_LINUX_REQUIRE_DATA_DEVICE=1 scripts/check_moui_linux_smoke.sh --run`
or `scripts/check_moui_linux_smoke.sh --run --require-data-device` to require
clipboard selection and drag/drop capability markers. The core Linux runtime path also replays its transcript with
`scripts/check_moui_runtime_log.sh --linux-input pending-ok linux <captured-log>`
so core handle/present/monitor/teardown checks share the same verifier while
input evidence remains pending. If the transcript is collected on another
machine, validate the captured log with the same verifier before recording the
evidence; the verifier requires nonzero Wayland/XDG handles, `current=true`, a
`primary=true`, nonzero `primary_id` and `current_id`, positive surface size and scale,
positive monitor count, delivered resize events after resize requests,
representative pointer input and keyboard text `a` before `ready` for strict
logs, and `Destroyed` before `finished`.

For the Windows backend, `scripts/check_moui_windows_smoke.sh` builds the
concrete consumer-style smoke entry point at `examples/moui_windows_smoke`. Run
`scripts/check_moui_windows_smoke.sh --run` on a Windows host to verify surface
creation, scale reporting, `Window::window_handle()`,
`Window::display_handle()`, `Window::rwh_06_display_handle()`,
`Window::rwh_06_window_handle()`,
monitor/current-monitor probes including `current=true` and
`primary_id=0x...`/`current_id=0x...` native monitor ids, cursor state, resize
delivery, redraw plus `pre_present_notify`, representative
pointer/keyboard/text input, public IME enable/update/disable state, and clean
shutdown. The runtime path replays its captured transcript through
`scripts/check_moui_runtime_log.sh windows <captured-log>` before accepting the
smoke. If the transcript is collected on another machine, validate the captured
log with the same verifier before recording the evidence; the verifier requires
nonzero HWND/HINSTANCE fields, raw display/window identity, `primary=true` and
`current=true` with nonzero `primary_id` and `current_id`, positive surface size
and scale, positive monitor count, delivered resize events after resize
requests, pointer/keyboard/IME text `a` before `ready`, and `Destroyed` before
`finished`.

## Backend Runtime Evidence

Use the backend helper first:

```bash
scripts/smoke_runtime.sh <backend>
```

Record the command, host, date, and observed facts in `docs/platform-gaps.md`.
Do not mark a backend runtime smoke as passed unless the window or page opens,
resize/redraw delivery is observed, representative input is delivered, and the
runtime exits cleanly.
For external Linux/Windows logs, first run
`scripts/check_moui_runtime_log.sh <linux|windows> <captured-log>` so the
transcript is checked against the same required sentinel lines before the
evidence entry is generated.
On a matching Linux/Windows host, prefer
`bash scripts/capture_moui_runtime_evidence.sh <linux|windows> --log <path>` for a
single audited capture path: it runs the matching `WINDOW_CI_HOST` branch,
writes the runtime transcript, validates it with
`scripts/check_moui_runtime_log.sh`, and prints the standard evidence entry.
Use `bash scripts/record_moui_evidence.sh <backend>` to generate a standard evidence
entry after the run; the helper prints to stdout only so status changes still
require review. For native backends, passed evidence must come from a matching
host or explicitly name the remote matching host with `--host`. Passed evidence
must also explicitly include `--window-opened yes`, `--resize-redraw yes`,
`--input yes`, and `--clean-exit yes`. Passed Linux/Windows evidence must
include `--runtime-log yes` and `--runtime-log-command` after
`scripts/check_moui_runtime_log.sh` accepts the captured transcript. The
runtime log command must be the verifier invocation itself, optionally prefixed
with `bash`, with exactly one concrete captured-log path and no shell chaining,
redirection, wrapper text, or `<captured-log>` placeholder. Use
`--consumer-input yes` only for the separate MoUI consumer input field after
the downstream smoke observes input
through the public backend API. Any non-pending MoUI consumer evidence field
requires `--consumer-command` with the exact downstream command. The generated
entry computes a separate MoUI consumer status so runtime-only evidence remains
visibly pending until the consumer smoke has also proven its surface, redraw,
input, text/IME, renderer handle, monitor/cursor, and shutdown facts. Web may
leave monitor/cursor pending when recording browser-only consumer evidence;
native Linux/Windows consumer readiness still needs monitor/current-monitor and
cursor evidence.

Copyable recorder commands for the current evidence shape:

```bash
bash scripts/record_moui_evidence.sh web \
  --status passed \
  --commands "bash scripts/check_ci.sh; scripts/smoke_runtime.sh web; browser http://127.0.0.1:8000/examples/moui_web_smoke/index.html" \
  --window-opened yes \
  --resize-redraw yes \
  --input yes \
  --clean-exit yes \
  --runtime-log pending \
  --runtime-log-command pending \
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

bash scripts/record_moui_evidence.sh macos \
  --status passed \
  --commands "WINDOW_CI_HOST=macos bash scripts/check_ci.sh; scripts/check_moui_macos_smoke.sh --run" \
  --window-opened yes \
  --resize-redraw yes \
  --input yes \
  --clean-exit yes \
  --runtime-log pending \
  --runtime-log-command pending \
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

bash scripts/record_moui_evidence.sh linux \
  --status pending \
  --host "Linux Wayland/Weston CI" \
  --commands "WINDOW_CI_HOST=linux bash scripts/check_ci.sh; scripts/smoke_runtime.sh linux; WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run; scripts/check_moui_runtime_log.sh linux <captured-log>" \
  --window-opened pending \
  --resize-redraw pending \
  --input pending \
  --clean-exit pending \
  --runtime-log pending \
  --runtime-log-command "scripts/check_moui_runtime_log.sh linux <captured-log>" \
  --consumer-command "WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run" \
  --surface pending \
  --redraw pending \
  --resize-scale pending \
  --consumer-input pending \
  --text-input pending \
  --renderer-handle pending \
  --monitor-cursor pending \
  --clean-shutdown pending \
  --notes "replace pending values only with observed matching-host Wayland facts, including wl_output monitor/current-monitor current=true with primary_id/current_id native ids, cursor probes, public IME probe enable/update/disable, representative keyboard text a before ready with pointer evidence, destroy requested, and Destroyed before finished"

bash scripts/capture_moui_runtime_evidence.sh linux --log artifacts/moui-linux-runtime.log

bash scripts/record_moui_evidence.sh windows \
  --status passed \
  --host "Windows Win32 CI" \
  --commands "WINDOW_CI_HOST=windows bash scripts/check_ci.sh; scripts/check_moui_windows_smoke.sh --run; scripts/check_moui_runtime_log.sh windows artifacts/moui-windows-runtime.log" \
  --window-opened yes \
  --resize-redraw yes \
  --input yes \
  --clean-exit yes \
  --runtime-log yes \
  --runtime-log-command "scripts/check_moui_runtime_log.sh windows artifacts/moui-windows-runtime.log" \
  --consumer-command "scripts/check_moui_windows_smoke.sh --run" \
  --surface yes \
  --redraw yes \
  --resize-scale yes \
  --consumer-input yes \
  --text-input yes \
  --renderer-handle yes \
  --monitor-cursor yes \
  --clean-shutdown yes \
  --notes "matching-host Win32 runtime accepted by scripts/check_moui_runtime_log.sh windows artifacts/moui-windows-runtime.log; observed HWND/HINSTANCE/raw_display/raw_window handle fields, monitor/current-monitor current=true with primary_id/current_id native ids, cursor Icon(Text), IME probe enabled/update/disable with hint/purpose enable/update probes, pointer/keyboard/ime text a before ready, resize/redraw, destroy requested, and Destroyed before finished"

bash scripts/capture_moui_runtime_evidence.sh windows --log artifacts/moui-windows-runtime.log
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

- Shared native renderer setup uses `Window::display_handle()` and
  `Window::window_handle()` in the raw-window-handle style.
- macOS: `Window::window_handle()` has AppKit content-view semantics;
  `Window::content_view_handle()` is the macOS-only explicit convenience API.
- Web: renderer setup uses `Window::canvas_id()` plus `web/runtime.js`
  imports and exported `web_dispatch_event`; raw handles are placeholders.
- Linux: renderer setup uses `wl_display`/`wl_surface` from the shared handle
  pair, with `xdg_surface`/`xdg_toplevel` extension APIs or
  `present_rgba_pixels(...)` for CPU frames.
- Windows: renderer setup uses public HINSTANCE/HWND identity from
  `Window::display_handle()`, `Window::window_handle()`,
  `Window::rwh_06_display_handle()`, and `Window::rwh_06_window_handle()`,
  and covers Win32 keyboard, mouse, and IME delivery.

If the MoUI consumer smoke fails, keep the backend status pending in
`docs/platform-gaps.md` and record the first actionable failure.
