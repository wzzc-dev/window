# Platform Gaps

This document tracks the remaining gaps before `moui-support` can be treated as
a MoUI-ready cross-platform window fork. It intentionally separates build
smoke, runtime smoke, and API parity so a green local gate is not mistaken for
complete backend validation.

## Current Baseline

- `bash scripts/check_ci.sh` is the default host-aware build gate.
- Warning 73 checks are expected to be clean for the default target and
  `moon check --target all`.
- macOS native tests are build-only until framework-linked native test
  execution works through the MoonBit runner.
- Web is validated with `wasm-gc` build artifacts on every host; when Node is
  available, the asset smoke also imports `web/runtime.js` and verifies dispatch
  binding.
- Linux and Windows native backends must be validated on their matching host.

## Latest Local Verification

Last verified on macOS, 2026-06-01:

- `bash scripts/check_ci.sh` passed. This covered CI host detection,
  runtime smoke helper dry-run checks, documentation smoke checks, `moon check`,
  default-target and all-target warning-73 checks, core/dpi tests, Web
  `wasm-gc` build-only tests and build, Web host-page asset smoke, Web runtime
  module import smoke, macOS native build-only tests and build, example build
  checks, and FFI surface checks.
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
- `moon run examples/window --target native` did not complete a macOS runtime
  smoke. The current runner path printed `tcc: error: file 'AppKit' not found`,
  so no AppKit window-open/resize/redraw/exit observation was possible.

## Readiness Status

| Backend | Build smoke | Runtime smoke | Gap status |
| --- | --- | --- | --- |
| macOS | Passed on macOS through `bash scripts/check_ci.sh` | Pending; blocked by framework-linked `moon run --target native` runner behavior | AppKit lifecycle and callback ownership remain high risk |
| Web | Passed through the default gate and `scripts/check_web_assets.sh` | Passed in a browser with canvas creation, redraw, pointer, and keyboard events | Native-only APIs remain placeholders or unsupported |
| Linux | Pending matching Linux host | Pending Wayland or Weston runtime | Wayland dependencies, text/IME, decorations, monitor/raw-handle parity |
| Windows | Pending matching Windows host | Pending Win32 runtime | Windows toolchain, preview API parity, cursor/raw-handle/monitor validation |

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
5. If the smoke fails, keep the backend `Pending` and record the exact failing
   command plus the first actionable error message.

Use this shape for new entries under `Latest Local Verification`:

```text
- <backend> <build/runtime> smoke on <host>, <date>: <passed/failed>.
  Commands: `<command 1>`; `<command 2>`.
  Observed: window opened=<yes/no>, resize/redraw=<yes/no>,
  representative input=<yes/no>, clean exit=<yes/no>.
  Notes: <toolchain/compositor/runtime details, or first actionable error>.
```

## macOS

Build smoke:

- `WINDOW_CI_HOST=macos bash scripts/check_ci.sh`

Runtime smoke:

- Pending. Framework-linked `moon run --target native` is still limited by the
  current native runner behavior documented in `docs/testing.md`.
- Last attempted command: `moon run examples/window --target native`; it printed
  `tcc: error: file 'AppKit' not found` before an AppKit window could open.
- Once that runner path is fixed, run `scripts/smoke_runtime.sh macos`
  and verify window creation, resize/redraw delivery, and clean exit.

Known gaps:

- Full runtime transcript parity remains optional and environment-dependent.
- AppKit lifecycle and callback ownership remain high-risk areas; keep using
  `docs/architecture-risks.md` as the ownership checklist when changing them.

## Web

Build smoke:

- `scripts/check_web_assets.sh` verifies the host page, runtime glue, wasm
  exports, and the `web/runtime.js` module import path when Node is available.

Runtime smoke:

- `scripts/smoke_runtime.sh web`
- Open `http://127.0.0.1:8000/examples/window_web/index.html`
- Verify canvas creation, resize/redraw delivery, pointer input, text/IME
  forwarding, and clean exit.

Known gaps:

- Browser DOM APIs are required; Node/headless-without-DOM is not a supported
  runtime.
- Native-only behavior such as system menus, taskbar integration, native
  decorations, native drag-window, exclusive fullscreen, and precise monitor
  metadata is unsupported or represented by stable placeholders.

## Linux

Build smoke:

- `WINDOW_CI_HOST=linux bash scripts/check_ci.sh`

Runtime smoke:

- Run inside a Wayland session or Weston:
  `scripts/smoke_runtime.sh linux`
- Verify window creation, resize/redraw delivery, pointer button/motion events,
  `present_rgba_pixels(...)` output, and clean exit.

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

Runtime smoke:

- In an MSVC or Mingw shell:
  `scripts/smoke_runtime.sh windows`
- Verify window creation, resize/redraw delivery, keyboard/mouse events, IME
  enable/update/disable behavior, and clean exit.

Known gaps:

- Build requires a working Windows C toolchain and Win32 headers.
- Preview APIs may still be state-only, no-op, or `NotSupported` where the
  platform behavior has not been aligned yet.
- Cursor mapping and richer raw-handle/monitor parity should be tested against
  real Win32 runtime behavior before treating the backend as stable.
