# Platform Gaps

This document tracks the remaining gaps before `moui-support` can be treated as
a MoUI-ready cross-platform window fork. It intentionally separates build
smoke, runtime smoke, and API parity so a green local gate is not mistaken for
complete backend validation.
See `docs/moui-integration-smoke.md` for the consumer-side evidence expected
before a backend is treated as ready for MoUI integration.

## Current Baseline

- `bash scripts/check_ci.sh` is the default host-aware build gate.
- `scripts/check_moui_readiness.sh` audits the MoUI smoke matrix so pending
  Linux/Windows evidence is not accidentally documented as passed.
- `scripts/check_moui_evidence.sh` verifies the evidence helper's host-safety
  behavior and confirms it does not edit this tracker automatically.
- `scripts/check_moon_baseline.sh` runs the MoonBit interface, formatter, and
  bare test baseline that is safe on the current host.
- `scripts/record_moui_evidence.sh <backend>` prints a standard evidence entry
  for matching-host smoke runs. It does not edit this file or change readiness
  status automatically; review the generated entry before pasting it below.
  `--status passed` requires explicit `yes` evidence for window creation,
  resize/redraw, representative input, and clean exit.
- Warning 73 checks are expected to be clean for the default target and
  `moon check --target all`.
- macOS native tests are build-only until framework-linked native test
  execution works through the MoonBit runner. The macOS MoUI runtime smoke uses
  the built AppKit executable directly and covers surface, handle,
  resize/redraw, representative input, and clean-shutdown evidence.
- Web is validated with `wasm-gc` build artifacts on every host; when Node is
  available, the asset smoke also imports `web/runtime.js` and verifies dispatch
  binding. The Web MoUI consumer-style smoke builds
  `examples/moui_web_smoke`, runs the DOM-shim consumer path when Node supports
  the required wasm-gc interop, and verifies the canvas/surface/redraw/input
  evidence hooks.
- Linux and Windows native backends must be validated on their matching host.
  Their MoUI smoke scripts now exist as matching-host gates:
  `scripts/check_moui_linux_smoke.sh` for Wayland core surface/handle/present
  evidence and `scripts/check_moui_windows_smoke.sh` for Win32
  surface/handle/input evidence.

## Latest Local Verification

Last verified on macOS, 2026-06-02:

- `bash scripts/check_ci.sh` passed. This covered CI host detection,
  runtime smoke helper dry-run checks, documentation smoke checks, `moon check`,
  default-target and all-target warning-73 checks, core/dpi tests, Web
  `wasm-gc` build-only tests and build, Web host-page asset smoke, Web runtime
  module import smoke, Web MoUI consumer-style smoke, macOS native build-only
  tests and build, macOS MoUI smoke build checks, example build checks, and FFI
  surface checks.
- `moon info`, `moon info web --target wasm-gc`, `moon fmt`, and bare
  `moon test` passed through `scripts/check_moon_baseline.sh`. Bare `moon test`
  now reaches the macOS whitebox coverage and the non-host Linux/Windows native
  C stubs on macOS; targeted
  framework-linked `moon test macos` still uses the `tcc -run` path documented
  below and should remain build-only in the default gate.
- Web runtime smoke passed with `node examples/window_web/serve.mjs` and
  `http://127.0.0.1:8000/examples/window_web/index.html`: the page reached
  `Running`, created one `640x360` canvas, delivered redraw, pointer, and
  keyboard events, and reported no browser console warnings or errors.
- `WINDOW_CI_HOST=none bash scripts/check_ci.sh` passed. This verifies the
  platform-independent and Web portions of the gate while deliberately skipping
  host-native backend builds and platform-specific native examples.
- `WINDOW_CI_HOST=macos bash scripts/check_ci.sh` passed. This verifies the
  documented macOS build-smoke override path in addition to auto-detected
  macOS host detection.
- On macOS, `WINDOW_CI_HOST=linux` and `WINDOW_CI_HOST=windows` fail fast
  before build steps because those overrides do not match the detected host.
- `WINDOW_RUNTIME_SMOKE_DRY_RUN=1 scripts/smoke_runtime.sh macos` and
  `WINDOW_RUNTIME_SMOKE_DRY_RUN=1 scripts/smoke_runtime.sh web` passed. The
  same dry-run command for `linux` and `windows` failed fast on macOS because
  the runtime smoke host did not match the requested backend.
- `scripts/check_runtime_smoke.sh` passed. This verifies the runtime smoke
  helper's help text, dry-run command selection, matching-host path, Web path,
  mismatched-host failures, and invalid-backend failure without opening windows.
- `scripts/check_docs_smoke.sh` passed. This verifies the README, testing
  guide, platform-gap tracker, and gate script still agree on the default gate,
  warning gate, Web asset smoke, runtime smoke helper, and Linux/Windows host
  smoke commands.
- `scripts/check_moui_linux_smoke.sh` and
  `scripts/check_moui_windows_smoke.sh` are wired into the default gate and
  skip on macOS. Matching-host build/runtime evidence remains pending for both
  platforms.
- `scripts/check_moui_macos_smoke.sh --run` passed. This built
  `examples/moui_macos_smoke` and launched the generated AppKit executable
  directly. Observed facts: a surface/scale probe was emitted, AppKit returned
  nonzero `window_handle` and `content_view_handle` values, the
  monitor/current-monitor probe completed, cursor probe `Icon(Text)` was
  reported, resize was requested, resize events were delivered,
  `RedrawRequested` ran with `pre_present_notify`, representative pointer input
  and keyboard text `a` were delivered, `Destroyed` was printed, and the process
  returned cleanly with `MOUIMacSmoke: finished`. The exact initial surface size,
  scale factor, and monitor count are environment-sensitive in CLI-launched
  AppKit smoke runs; the latest local rerun printed `surface size=1x0 scale=1`
  and `monitors count=0 primary=false current=false`. The runtime checker
  requires the `Destroyed` sentinel before `finished` before accepting clean
  shutdown evidence.
- `scripts/check_moui_web_smoke.sh` passed. This built
  `examples/moui_web_smoke`, verified the host page and wasm artifact, and
  checked the canvas identity, surface/scale, redraw, resize, pointer, and
  keyboard evidence hooks. The Node DOM-shim consumer runtime path also passed,
  covering the public `Window::canvas_id()` string bridge and event dispatch.
- Web MoUI browser consumer smoke passed through `scripts/smoke_runtime.sh web`
  and `http://127.0.0.1:8000/examples/moui_web_smoke/index.html`: the helper
  ran Web asset and MoUI preflight checks, served the repository, and the page
  reached `PASS` with `canvas_id=moui-web-smoke-canvas`, `640x360` surface
  size, redraw plus `pre_present_notify`, resize/scale reporting, pointer
  `24,32`, keyboard text `a`, and no browser warning or error logs.
- `moon run examples/window --target native` did not complete a macOS runtime
  smoke through the MoonBit runner. The current runner path printed
  `tcc: error: file 'AppKit' not found`; use
  `scripts/check_moui_macos_smoke.sh --run` or `scripts/smoke_runtime.sh macos`
  for the current AppKit executable smoke.

## Readiness Status

| Backend | Build smoke | Runtime smoke | Gap status |
| --- | --- | --- | --- |
| macOS | Passed on macOS through `bash scripts/check_ci.sh` and `scripts/check_moui_macos_smoke.sh` | Automated MoUI smoke passed with surface, handles, resize/redraw, representative input, and clean shutdown | AppKit lifecycle depth and callback ownership remain high risk |
| Web | Passed through the default gate, `scripts/check_web_assets.sh`, and `scripts/check_moui_web_smoke.sh` | Passed in a browser with canvas creation, redraw, resize/scale, pointer, keyboard, and MoUI consumer evidence | Native-only APIs remain placeholders or unsupported |
| Linux | Pending matching Linux host; script exists as `scripts/check_moui_linux_smoke.sh` | Pending Wayland or Weston runtime; automated core smoke covers handles/present, while `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run` requires pointer/keyboard evidence | Wayland dependencies, text/IME, decorations, monitor/raw-handle parity |
| Windows | Pending matching Windows host; script exists as `scripts/check_moui_windows_smoke.sh` | Pending Win32 runtime through `scripts/check_moui_windows_smoke.sh --run` | Windows toolchain, preview API parity, cursor/raw-handle/monitor validation |

Treat `Pending` as missing evidence, not as a soft pass. A backend becomes
MoUI-ready only after its build smoke and runtime smoke have both been observed
on the matching platform, with remaining gaps either closed or accepted by MoUI.

## External Host Validation

When validating a pending backend on another machine, record evidence here
instead of only reporting "it works":

1. Confirm the branch and host:
   `git status --short --branch` and the OS/toolchain or compositor being used.
2. Run the matching build smoke:
   `WINDOW_CI_HOST=linux bash scripts/check_ci.sh` or
   `WINDOW_CI_HOST=windows bash scripts/check_ci.sh`.
   `WINDOW_CI_HOST` selects the gate branch; it is not a cross-compilation
   switch, and mismatched host overrides fail fast. Run these commands on
   matching hosts.
3. Run the matching runtime smoke command listed below through
   `scripts/smoke_runtime.sh <backend>`.
4. Record the date, command output summary, and observed runtime facts:
   window opened, resize/redraw event delivered, representative input delivered,
   and clean exit.
   Use `scripts/record_moui_evidence.sh <backend>` to generate the standard
   entry shape, then review and paste the result into this document. For
   native backend evidence generated from external logs, pass `--host` with the
   matching host description so the entry cannot be confused with local smoke.
   Use `--status pending` or `--status failed`, not `--status passed`, when any
   required runtime fact is still missing.
   Use `--consumer-input` for the MoUI consumer input field; it is deliberately
   separate from backend runtime `--input`. Any non-pending MoUI consumer field
   requires `--consumer-command` with the exact downstream command that produced
   the evidence.
5. Run the matching MoUI consumer smoke described in
   `docs/moui-integration-smoke.md` when the downstream MoUI app or integration
   harness is available, then record the exact command and observed facts.
6. If the smoke fails, keep the backend `Pending` and record the exact failing
   command plus the first actionable error message.

Use this shape for new entries under `Latest Local Verification`:

```text
- <backend> <build/runtime> smoke on <host>, <date>: <passed/failed>.
  Commands: `<command 1>`; `<command 2>`.
  Observed: window opened=<yes/no>, resize/redraw=<yes/no>,
  representative input=<yes/no>, clean exit=<yes/no>.
  MoUI consumer: command=<command or pending>, surface=<yes/no>,
  redraw=<yes/no>, resize/scale=<yes/no>, input=<yes/no via --consumer-input>,
  text/IME=<yes/no/pending>, renderer handle=<yes/no>,
  monitor/cursor=<yes/no/pending>, clean shutdown=<yes/no>.
  Notes: <toolchain/compositor/runtime details, or first actionable error>.
```

`docs/moui-integration-smoke.md` keeps copyable `record_moui_evidence.sh`
commands for the proven Web/macOS smoke facts and pending Linux/Windows
matching-host templates. Use those templates instead of hand-writing option
sets, then replace `pending` values only with facts observed on the matching
host.

## macOS

Build smoke:

- `WINDOW_CI_HOST=macos bash scripts/check_ci.sh`
- `scripts/check_moui_macos_smoke.sh`

Runtime smoke:

- `scripts/check_moui_macos_smoke.sh --run`
- `scripts/smoke_runtime.sh macos`
- Verify window creation, nonzero `window_handle`/`content_view_handle`,
  monitor/current-monitor probes, cursor state, resize/redraw delivery,
  representative pointer/keyboard input, and clean exit.

Known gaps:

- Full runtime transcript parity remains optional and environment-dependent.
- Framework-linked `moon run --target native` still fails on this host with
  `tcc: error: file 'AppKit' not found`; the runtime smoke uses the built
  executable directly until that runner path is fixed.
- AppKit lifecycle and callback ownership remain high-risk areas; keep using
  `docs/architecture-risks.md` as the ownership checklist when changing them.

## Web

Build smoke:

- `scripts/check_web_assets.sh` verifies the host page, runtime glue, wasm
  exports, and the `web/runtime.js` module import path when Node is available.
- `scripts/check_moui_web_smoke.sh` verifies the concrete Web consumer smoke
  artifact and page hooks used to collect MoUI-style surface/redraw/input
  evidence.

Runtime smoke:

- `scripts/smoke_runtime.sh web`
- Open `http://127.0.0.1:8000/examples/window_web/index.html`
- Verify canvas creation, resize/redraw delivery, pointer input, text/IME
  forwarding, and clean exit.
- Open `http://127.0.0.1:8000/examples/moui_web_smoke/index.html` for the
  MoUI consumer page. `scripts/smoke_runtime.sh web` runs the same
  `scripts/check_moui_web_smoke.sh` preflight before serving.
- The MoUI consumer page must reach `PASS` with surface, redraw, resize/scale,
  pointer, keyboard, and canvas identity evidence.

Known gaps:

- Browser DOM APIs are required; Node/headless-without-DOM is not a supported
  runtime.
- Native-only behavior such as system menus, taskbar integration, native
  decorations, native drag-window, exclusive fullscreen, and precise monitor
  metadata is unsupported or represented by stable placeholders.

## Linux

Build smoke:

- `WINDOW_CI_HOST=linux bash scripts/check_ci.sh`
- `scripts/check_moui_linux_smoke.sh`

Runtime smoke:

- Run inside a Wayland session or Weston:
  `scripts/smoke_runtime.sh linux`
- Or run the concrete MoUI smoke:
  `scripts/check_moui_linux_smoke.sh --run`
- For full input evidence:
  `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run`
  or `scripts/check_moui_linux_smoke.sh --run --require-input`
- Verify window creation, public Wayland handles, `present_rgba_pixels(...)`
  output, monitor/current-monitor probes, cursor state, resize/redraw delivery,
  and clean exit. Representative pointer and keyboard events are logged when
  supplied, and remain required before marking Linux MoUI-ready.

Known gaps:

- Wayland protocol generation requires Linux Wayland development dependencies:
  `wayland-client`, `wayland-protocols`, `wayland-scanner`, and `pkg-config`.
- X11 is intentionally unsupported in this backend.
- Text input and IME are future work.
- Decorations, taskbar integration, system menus, native drag-window, exclusive
  fullscreen, precise monitor metadata, custom cursors, and rich raw-handle
  parity are currently unsupported, no-op, or placeholder behavior.

## Windows

Build smoke:

- `WINDOW_CI_HOST=windows bash scripts/check_ci.sh`
- `scripts/check_moui_windows_smoke.sh`

Runtime smoke:

- In an MSVC or Mingw shell:
  `scripts/smoke_runtime.sh windows`
- Or run the concrete MoUI smoke:
  `scripts/check_moui_windows_smoke.sh --run`
- Verify window creation, monitor/current-monitor probes, cursor state,
  resize/redraw delivery, keyboard/mouse events, IME enable/update/disable
  behavior, and clean exit.

Known gaps:

- Build requires a working Windows C toolchain and Win32 headers.
- Preview APIs may still be state-only, no-op, or `NotSupported` where the
  platform behavior has not been aligned yet.
- Cursor mapping and richer raw-handle/monitor parity should be tested against
  real Win32 runtime behavior before treating the backend as stable.
