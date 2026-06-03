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
- `scripts/check_moui_runtime_log.sh <linux|windows> <captured-log>` verifies
  captured matching-host Linux/Windows MoUI runtime transcripts before they are
  used as remote evidence.
- `bash scripts/capture_moui_runtime_evidence.sh <linux|windows> --log <path>` is
  the matching-host capture helper for Linux/Windows runtime evidence: it runs
  the host CI branch, writes the transcript, verifies it, and prints the
  standard recorder entry without editing this tracker.
- `scripts/check_moon_baseline.sh` runs the MoonBit interface, formatter, and
  bare test baseline that is safe on the current host.
- `bash scripts/record_moui_evidence.sh <backend>` prints a standard evidence entry
  for matching-host smoke runs. It does not edit this file or change readiness
  status automatically; review the generated entry before pasting it below.
  `--status passed` requires explicit `yes` evidence for window creation,
  resize/redraw, representative input, and clean exit.
- Warning 73 checks are expected to be clean for the default target and
  `moon check --target all`.
- `scripts/check_ffi_surface.sh` audits macOS, Linux, and Windows native FFI
  export allowlists so preview-backend native symbols cannot drift silently.
- macOS native tests are build-only because generic test execution can still
  route through incompatible native runner paths. The macOS MoUI runtime smoke
  uses `moon run examples/moui_macos_smoke --target native` and covers surface,
  handle, resize/redraw, representative input, and clean-shutdown evidence.
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
  surface/HWND/HINSTANCE/raw-display/input evidence. Captured runtime logs can
  be replay-checked with `scripts/check_moui_runtime_log.sh` before evidence is
  recorded from another machine; the strict Linux input smoke and Windows
  runtime smoke also replay their captured logs through that verifier before
  accepting the runtime run.

## Latest Local Verification

Last verified on macOS, 2026-06-03:

- `bash scripts/check_ci.sh` passed. This covered CI host detection,
  runtime smoke helper dry-run checks, documentation smoke checks, `moon check`,
  default-target and all-target warning-73 checks, core/dpi tests, Web
  `wasm-gc` build-only tests and build, Web host-page asset smoke, Web runtime
  module import smoke, Web MoUI consumer-style smoke, macOS native build-only
  tests and build, macOS MoUI smoke build checks, example build checks, and FFI
  surface checks.
- `moon check windows --target native --warn-list +73`,
  `moon test windows --target native --warn-list +73`, `moon info`,
  `moon fmt --check`, and `git diff --check` passed after adding Windows
  event-loop lifecycle cleanup coverage for loop-owned app-state HWNDs,
  pending redraw ids, mouse tracking, and pending UTF-16 surrogate input state.
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
- `WINDOW_RUNTIME_SMOKE_DRY_RUN=1 scripts/smoke_runtime.sh <backend>` passed
  for macOS, Web, Linux, and Windows on macOS. Dry-run mode audits the selected
  command and checklist without launching a native runtime; non-dry-run Linux
  and Windows runtime smoke still fails fast on macOS because the runtime smoke
  host does not match the requested backend.
- `scripts/check_runtime_smoke.sh` passed. This verifies the runtime smoke
  helper's help text, dry-run command selection for every backend, Web path,
  offline Linux/Windows runtime log verifier samples, mismatched-host
  non-dry-run failures, and invalid-backend failure without opening windows.
- `scripts/check_docs_smoke.sh` passed. This verifies the README, testing
  guide, platform-gap tracker, and gate script still agree on the default gate,
  warning gate, Web asset smoke, runtime smoke helper, and Linux/Windows host
  smoke commands.
- `scripts/check_moui_linux_smoke.sh` and
  `scripts/check_moui_windows_smoke.sh` are wired into the default gate and
  skip on macOS. Matching-host build/runtime evidence remains pending for both
  platforms.
- `scripts/check_moui_macos_smoke.sh --run` passed. This built
  `examples/moui_macos_smoke` and launched the AppKit smoke through `moon run`.
  Observed facts: a surface/scale probe was emitted, AppKit returned
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
- Generic `moon run examples/window --target native` is not the MoUI runtime
  evidence path. Use `scripts/check_moui_macos_smoke.sh --run` or
  `scripts/smoke_runtime.sh macos` for the current AppKit consumer smoke.

## Readiness Status

| Backend | Build smoke | Runtime smoke | Gap status |
| --- | --- | --- | --- |
| macOS | Passed on macOS through `bash scripts/check_ci.sh` and `scripts/check_moui_macos_smoke.sh` | Automated MoUI smoke passed with surface, handles, resize/redraw, representative input, and clean shutdown | AppKit lifecycle depth and callback ownership remain high risk |
| Web | Passed through the default gate, `scripts/check_web_assets.sh`, and `scripts/check_moui_web_smoke.sh` | Passed in a browser with canvas creation, redraw, resize/scale, pointer, keyboard, and MoUI consumer evidence | Native-only APIs remain placeholders or unsupported |
| Linux | Pending matching Linux host; script exists as `scripts/check_moui_linux_smoke.sh` | Pending Wayland or Weston runtime; automated core smoke covers handles/present, `wl_output` monitor/current-monitor probes, and public IME state probes, while `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 scripts/check_moui_linux_smoke.sh --run` requires pointer/keyboard evidence | Wayland dependencies, text/IME delivery, decorations, precise monitor metadata, raw-handle parity |
| Windows | Pending matching Windows host; script exists as `scripts/check_moui_windows_smoke.sh` | Pending Win32 runtime through `scripts/check_moui_windows_smoke.sh --run`; smoke requires HWND/HINSTANCE/raw-display handle fields and `current=true` monitor evidence | Windows toolchain, preview API parity, cursor/raw-handle validation |

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
4. For Linux/Windows matching-host evidence, prefer the capture helper:
   `bash scripts/capture_moui_runtime_evidence.sh linux --log <captured-log>` or
   `bash scripts/capture_moui_runtime_evidence.sh windows --log <captured-log>`.
   The capture helper writes the transcript, validates it with the offline log
   verifier, and prints the standard evidence entry for review.
5. For external Linux/Windows logs, save the captured transcript and validate
   it with `scripts/check_moui_runtime_log.sh linux <captured-log>` or
   `scripts/check_moui_runtime_log.sh windows <captured-log>` before recording
   evidence. The verifier requires the monitor/current-monitor, native id,
   input/text/IME before `ready`, raw-handle identity, positive surface
   size/scale, positive monitor count, delivered resize events after resize requests,
   unique startup probes for surface/handles/monitor/cursor/IME, positive resize
   request sizes, failure-free teardown, and `Destroyed` before `finished`
   sentinel facts expected by the MoUI smoke.
   The verifier phrases are positive surface size/scale, positive monitor count,
   unique startup probes, positive resize request sizes, and delivered resize
   events after resize requests.
6. Record the date, command output summary, and observed runtime facts:
   window opened, resize/redraw event delivered, representative input delivered,
   and clean exit.
   Use `bash scripts/record_moui_evidence.sh <backend>` to generate the standard
   entry shape, then review and paste the result into this document. For
   native backend evidence generated from external logs, pass `--host` with the
   matching host description so the entry cannot be confused with local smoke.
   Use `--status pending` or `--status failed`, not `--status passed`, when any
   required runtime fact is still missing.
   For passed Linux/Windows evidence, also pass `--runtime-log yes` and
   `--runtime-log-command "scripts/check_moui_runtime_log.sh <backend>
   <captured-log>"`; the evidence helper rejects passed Linux/Windows entries
   when runtime log verification is not explicit. The runtime log command must
   be the verifier command itself, optionally prefixed by `bash`, so a wrapper
   or note that only mentions `scripts/check_moui_runtime_log.sh` is not
   accepted as verified evidence. Verified evidence must use exactly one
   concrete captured-log path and cannot include shell chaining, redirection,
   extra verifier arguments, or a `<captured-log>` placeholder.
   Use `--consumer-input` for the MoUI consumer input field; it is deliberately
   separate from backend runtime `--input`. Any non-pending MoUI consumer field
   requires `--consumer-command` with the exact downstream command that produced
   the evidence. The generated entry includes a computed MoUI consumer status;
   keep it pending when a runtime pass has not also proven the consumer-side
   surface, redraw, input, text/IME, handle, monitor/cursor, and shutdown facts.
6. Run the matching MoUI consumer smoke described in
   `docs/moui-integration-smoke.md` when the downstream MoUI app or integration
   harness is available, then record the exact command and observed facts.
7. If the smoke fails, keep the backend `Pending` and record the exact failing
   command plus the first actionable error message.

Use this shape for new entries under `Latest Local Verification`:

```text
- <backend> <build/runtime> smoke on <host>, <date>: <passed/failed>.
  Commands: `<command 1>`; `<command 2>`.
  Observed: window opened=<yes/no>, resize/redraw=<yes/no>,
  representative input=<yes/no>, clean exit=<yes/no>.
  Runtime log: verified=<yes/no/pending>, command=<command or pending>.
  MoUI consumer: status=<passed/failed/pending>, command=<command or pending>, surface=<yes/no>,
  redraw=<yes/no>, resize/scale=<yes/no>, input=<yes/no via --consumer-input>,
  text/IME=<yes/no/pending>, renderer handle=<yes/no>,
  monitor/cursor=<yes/no/pending>, clean shutdown=<yes/no>.
  Notes: <toolchain/compositor/runtime details, or first actionable error>.
```

`docs/moui-integration-smoke.md` keeps copyable `bash scripts/record_moui_evidence.sh`
commands for the proven Web/macOS smoke facts and pending Linux/Windows
matching-host templates. Use those templates instead of hand-writing option
sets, then replace `pending` values only with facts observed on the matching
host. For passed Linux/Windows entries, replace the runtime log fields only
after `scripts/check_moui_runtime_log.sh` accepts the captured transcript.

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
- Generic framework-linked examples are not treated as MoUI runtime evidence;
  keep using `scripts/check_moui_macos_smoke.sh --run`, which builds the smoke
  package and runs its AppKit sentinel path through `moon run`.
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
- Both Linux runtime paths replay their captured log through the offline
  verifier before passing; core runs use
  `scripts/check_moui_runtime_log.sh --linux-input pending-ok linux <captured-log>`,
  while strict input runs use `scripts/check_moui_runtime_log.sh linux <captured-log>`.
- For captured external logs:
  `scripts/check_moui_runtime_log.sh linux <captured-log>`
- For matching-host capture and evidence output:
  `bash scripts/capture_moui_runtime_evidence.sh linux --log artifacts/moui-linux-runtime.log`
- Verify window creation, public Wayland handles, `present_rgba_pixels(...)`
  output, Wayland `wl_output` monitor/current-monitor probes including
  `primary=true`, `current=true` from surface enter/current-output tracking plus
  nonzero `primary_id=0x...`/`current_id=0x...` native ids, cursor state,
  public IME enable/update/disable state, resize/redraw delivery, and clean exit.
  Representative pointer and keyboard text `a` events are logged when
  supplied, and remain required before marking Linux MoUI-ready.

Known gaps:

- Wayland protocol generation requires Linux Wayland development dependencies:
  `wayland-client`, `wayland-protocols`, `wayland-scanner`, and `pkg-config`.
- X11 is intentionally unsupported in this backend.
- Full layout-aware text input and Wayland IME/preedit delivery are future
  work; the current strict smoke verifies representative keyboard text through
  the fixed key-code mapping and probes public IME request state only.
- Decorations, taskbar integration, system menus, native drag-window, exclusive
  fullscreen, precise monitor metadata beyond `wl_output` geometry/scale,
  custom cursors, and rich raw-handle parity are currently unsupported, no-op,
  or placeholder behavior.

## Windows

Build smoke:

- `WINDOW_CI_HOST=windows bash scripts/check_ci.sh`
- `scripts/check_moui_windows_smoke.sh`

Runtime smoke:

- In an MSVC or Mingw shell:
  `scripts/smoke_runtime.sh windows`
- Or run the concrete MoUI smoke:
  `scripts/check_moui_windows_smoke.sh --run`
- The runtime path replays its captured log through
  `scripts/check_moui_runtime_log.sh windows <captured-log>` before passing.
- For captured external logs:
  `scripts/check_moui_runtime_log.sh windows <captured-log>`
- For matching-host capture and evidence output:
  `bash scripts/capture_moui_runtime_evidence.sh windows --log artifacts/moui-windows-runtime.log`
- Verify window creation, HWND/HINSTANCE/raw-display handle fields with
  raw display/window identity preserved,
  monitor/current-monitor probes including `primary=true`,
  `current=true` for the window monitor plus nonzero
  `primary_id=0x...`/`current_id=0x...` native ids,
  cursor state, resize/redraw delivery, keyboard/mouse events, IME
  enable/update/disable behavior, and clean exit.

Known gaps:

- Build requires a working Windows C toolchain and Win32 headers.
- Preview APIs may still be state-only, no-op, or `NotSupported` where the
  platform behavior has not been aligned yet.
- Cursor mapping and richer raw-handle/monitor parity should be tested against
  real Win32 runtime behavior before treating the backend as stable; the
  current smoke only accepts nonzero HINSTANCE-backed display handles and raw
  window handles that preserve HWND identity.
