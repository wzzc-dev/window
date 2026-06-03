# Testing

This repository uses `scripts/check_ci.sh` as the default local validation gate.

```bash
bash scripts/check_ci.sh
```

The gate runs:

- `scripts/check_ci_host.sh`
- `scripts/check_runtime_smoke.sh`
- `scripts/check_moui_runtime_log.sh` sample-log coverage through
  `scripts/check_runtime_smoke.sh`
- `scripts/check_docs_smoke.sh`
- `scripts/check_moui_readiness.sh`
- `scripts/check_moui_evidence.sh`
- `scripts/check_moon_baseline.sh`
- `moon check`
- `moon check --warn-list +73`
- `moon check --target all --warn-list +73`
- `moon test core`
- `moon test dpi`
- `moon test web --build-only --target wasm-gc`
- `moon build web --target wasm-gc`
- the current host backend with build-only native tests and `moon build`
  (`macos` on macOS, `linux` on Linux, `windows` on Windows)
- `scripts/check_examples_build.sh`
- `scripts/check_moui_macos_smoke.sh`
- `scripts/check_moui_linux_smoke.sh`
- `scripts/check_moui_windows_smoke.sh`
- `scripts/check_web_assets.sh`
- `scripts/check_moui_web_smoke.sh`
- `scripts/check_ffi_surface.sh`

The gate is host-aware because native stubs are platform-specific. macOS
should not try to compile Win32 headers or Wayland generated C files; Linux
should not try to compile AppKit or Win32 stubs; Windows should not try to
compile AppKit or Wayland stubs. Set `WINDOW_CI_HOST=macos`, `linux`,
`windows`, or `none` to override host detection when debugging the scripts.
Invalid override values fail fast instead of falling back to auto-detection.
The override selects a gate branch; it does not cross-compile native stubs.
Mismatched host overrides fail fast; use Linux and Windows overrides on
matching hosts with their native toolchains.

`scripts/check_examples_build.sh` follows the same host matrix. It always
builds Web examples with `wasm-gc`, builds generic native examples on every
host, and builds macOS/Linux/Windows native examples only on their matching
host.

`scripts/check_moui_macos_smoke.sh` builds `examples/moui_macos_smoke` on a
macOS host and verifies the smoke source covers surface/scale, AppKit window
and content-view handles, monitor/current-monitor probes, cursor state, resize,
redraw, representative pointer/keyboard input, and clean-shutdown sentinel
hooks. Run
`scripts/check_moui_macos_smoke.sh --run` to execute the smoke through
`moon run` and require those sentinel lines at runtime, with `destroyed` before
`finished`.

`scripts/check_moui_linux_smoke.sh` builds `examples/moui_linux_smoke` on a
Linux host and verifies the smoke source covers surface/scale, public Wayland
handles, Wayland `wl_output` monitor/current-monitor probes including
`current=true` from surface enter/current-output tracking and
`primary_id=0x...`/`current_id=0x...` native monitor ids, cursor state,
`present_rgba_pixels(...)`, public IME enable/update/disable state probes,
resize, redraw, input hooks, and clean-shutdown sentinel hooks. Run
`scripts/check_moui_linux_smoke.sh --run`
inside Wayland or Weston to collect automated core runtime evidence. Pointer
and keyboard lines are logged when supplied, but Linux input automation remains
separate evidence. Set `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` or pass
`--require-input` with `--run` to require pointer and keyboard evidence on a
matching host, including representative keyboard text `a` from the current
fixed key mapping. Both Linux runtime paths replay the captured transcript
through `scripts/check_moui_runtime_log.sh`; the core path uses
`--linux-input pending-ok`, while strict evidence uses the default input
requirements before it is accepted. The Linux IME probe covers public request state only;
layout-aware text and Wayland IME/preedit delivery still require separate
matching-host evidence. The runtime check requires `destroyed` before `finished`.
Linux and Windows IME request whitebox coverage checks
`request_ime_update(Enable/Update/Disable)` state transitions for hints,
purpose, surrounding text, and cursor area without requiring a live native IME.
The smoke app requests window destruction after the ready sentinel and only
exits after the `Destroyed` event, so the runtime log should show
`ready -> destroy requested -> destroyed -> finished`.
Linux event bridge whitebox tests cover Wayland configure normalization,
pointer enter/leave/buttons/wheel dispatch, keyboard text and modifier family
release semantics, focus/close/destroy/theme dispatch, redraw deduplication,
invalid raw-id filtering, destroyed-window pending-redraw cleanup, and proxy
wake delivery without requiring a live Wayland compositor.
Linux input-dispatch whitebox coverage requires an app-state live window handle
before accepting native pointer or keyboard callbacks, so late input after
window unregister cannot mutate modifiers or emit stale input events.
Linux window-dispatch whitebox coverage likewise requires an app-state live
window handle before accepting native configure, focus, close, destroyed, or
theme callbacks, so unregistering a window makes later native lifecycle noise
inert.
Linux window-runtime cleanup whitebox coverage checks that the shared drop and
native-destroy cleanup path clears app-state window handles and pending redraws
before any deferred redraw drain can emit a stale `RedrawRequested`.
Linux redraw queue whitebox coverage also requires a live app-state window
handle before enqueueing redraw ids, preventing late native redraw callbacks
from recreating stale `RedrawRequested` events after unregister.
Linux lifecycle whitebox coverage also checks that dropping the event loop
clears the stored Wayland context handle, context-owned window entries, and
pending redraw ids from app state without relying on a fake native context
pointer.
Native readiness checks require Wayland context teardown to release any
remaining context-owned windows before destroying Wayland globals.
Wayland context setup initializes the proxy wake fd to invalid and fails the
context explicitly if `eventfd` cannot be created, avoiding stale fd 0 teardown
or dispatch behavior.
The same setup path requires registry, compositor, shared-memory, and
`xdg_wm_base` globals before reporting a usable context, and only installs
Wayland seat/pointer/keyboard listeners after the corresponding bind succeeds.
Wayland registry roundtrip failures also fail context creation through the same
native cleanup path.
Wayland flush failures are audited separately from write-buffer backpressure:
`EAGAIN` enables write-ready polling, while real flush errors make dispatch,
window creation, or `present_rgba_pixels(...)` fail instead of recording
successful runtime evidence.
Wayland seat capability removal also clears the stored pointer/keyboard window
targets when the corresponding native input object is destroyed.

`scripts/check_moui_windows_smoke.sh` builds `examples/moui_windows_smoke` on a
Windows host and verifies the smoke source covers surface/scale, public HWND
handle, HINSTANCE/raw display handle probes with raw display/window identity
preserved, monitor/current-monitor probes including `current=true` and
`primary_id=0x...`/`current_id=0x...` native monitor ids, cursor state, resize,
redraw, representative
pointer/keyboard/text input, public IME enable/update/disable state probes,
and clean-shutdown sentinel hooks.
Windows event bridge whitebox tests cover Win32 resize, DPI scale changes using
the `WM_DPICHANGED` suggested rect size, pointer/key/text/IME dispatch, redraw
deduplication, invalid raw-id filtering, invalid `WM_CHAR` code-unit suppression,
destroyed-window pending-redraw cleanup, and sync-query handle gating without requiring a live Win32 GUI.
Windows input-dispatch whitebox coverage requires an app-state live HWND before
accepting native pointer, keyboard, or IME callbacks, so late input after window
unregister cannot mutate tracking/surrogate state or emit stale input events.
Windows window-dispatch whitebox coverage likewise requires an app-state live
HWND before accepting native resize, move, focus, DPI-scale, redraw, or destroyed
callbacks; `Window::new` registers the HWND immediately after successful native
creation before title/visibility native calls can produce more messages.
Windows window-runtime cleanup whitebox coverage checks that the shared drop and
native-destroy cleanup path clears per-window input state, app-state HWNDs, and
pending redraws before any deferred redraw drain can emit a stale
`RedrawRequested`.
Windows redraw queue whitebox coverage also requires a live app-state HWND
before enqueueing redraw ids, preventing late native redraw callbacks from
recreating stale `RedrawRequested` events after unregister.
Windows monitor whitebox tests cover null-handle preservation and non-positive
monitor size/scale normalization, invalid HWND current-monitor rejection, and
zero-DPI window scale fallback without requiring live Win32 monitor access.
Linux and Windows monitor whitebox tests also cover app-state window-handle
liveness gating for `Window::current_monitor()`, so stale window values do not
query native current-monitor state after the backend has unregistered them.
Native Win32 monitor enumeration clears the cached monitor list on any
enumeration failure instead of exposing partial monitor evidence.
Native Win32 monitor DPI queries only use `GetDpiForMonitor` results when the
call succeeds and reports a positive DPI; otherwise monitor scale falls back to
`1.0`.
Native Win32 monitor name conversion returns an empty name when UTF-8 conversion
fails instead of exposing unwritten bytes as monitor metadata.
Native Win32 current-monitor lookup rejects invalid HWND values before using
`MonitorFromWindow`, so stale or destroyed window handles do not fabricate
nearest-monitor evidence.
Windows event-loop creation fails with an OS error if the message-only window
cannot be created, instead of publishing a half-initialized event loop. Native
message-window creation only publishes the global window/thread state after a
successful `CreateWindowExW`; normal Win32 window creation also verifies that
`WM_NCCREATE` published the expected raw-id state before returning an HWND.
Failed creation, missing raw-id state, and message-window destroy clear that
global or per-window state.
Win32 IME dynamic loading also publishes `imm32.dll` function pointers only
after all required symbols resolve; partial loads are released and cleared.
The Windows event-loop drop path destroys its message-only window; invalid
raw-id filtering keeps that native teardown from surfacing as an application
`Destroyed` event, and native destroy clears the message-window global handle.
Windows lifecycle whitebox coverage also checks that dropping the event loop
clears loop-owned app-state HWNDs, pending redraw ids, mouse tracking, and
pending UTF-16 surrogate input state for any windows still registered at
teardown.
Run `scripts/check_moui_windows_smoke.sh --run`
to launch the built executable and require those sentinel lines at runtime,
with `destroyed` before `finished`. The Windows runtime path replays the
captured transcript through `scripts/check_moui_runtime_log.sh windows
<captured-log>` before it is accepted.
The smoke app requests window destruction after the ready sentinel and only
exits after the `Destroyed` event, so the runtime log should show
`ready -> destroy requested -> destroyed -> finished`.

`scripts/check_moui_runtime_log.sh <linux|windows> <captured-log>` validates a
captured native MoUI runtime transcript without rerunning the executable. Use
it when Linux/Windows logs are collected on a matching external host and then
brought back for review. The verifier requires the same runtime sentinel facts
as the strict Linux and Windows smoke scripts, including `current=true`,
nonzero `current_id`, nonzero Linux Wayland/XDG handles, Linux pointer and
keyboard text `a` before `ready`, Windows raw display/window identity, Windows
pointer, keyboard key `a`, and IME text `a` before `ready`, positive surface
size/scale, positive monitor count, exactly one startup probe for surface,
handles, monitor/current-monitor, cursor, and IME state, positive resize
request sizes, delivered resize events after resize requests, and `Destroyed`
before `finished`. It also rejects transcripts that contain the other native
backend's smoke prefix, so pasted Linux/Windows evidence cannot be spliced into
a single accepted runtime log. Use `--linux-input
pending-ok` only for the Linux core smoke transcript where pointer/keyboard
automation remains separate evidence. The default
gate exercises this verifier with pass/fail sample logs through
`scripts/check_runtime_smoke.sh`, including input-before-ready failures and
core-evidence-before-ready failures, non-prefixed smoke evidence rejection,
prefixed smoke failure-line rejection, pointer coordinate-field failures,
duplicate startup-probe failures, invalid resize-request failures,
duplicate-ready sentinel failures, plus duplicate-teardown sentinel failures,
post-finished smoke-line failures, and teardown-order failures where `finished`
appears before `Destroyed`; real Linux/Windows runtime evidence still must be
collected on matching hosts. Evidence lines must begin with the exact
`MOUILinuxSmoke:` or `MOUIWindowsSmoke:` prefix, so ordinary logs that merely
mention a smoke sentinel cannot satisfy runtime evidence. Ready and teardown
sentinels must match their expected line exactly, so near-miss lines like
`readyish` or `destroyed later` cannot satisfy lifecycle evidence.
Representative input evidence for Linux keyboard text, Windows keyboard key,
and Windows IME text must also match the exact `a` line; near-miss values such
as `ab` do not count as MoUI input evidence.
The verifier phrases are positive surface size/scale, positive monitor count,
unique startup probes, positive resize request sizes, and delivered resize
events after resize requests.

`scripts/check_web_assets.sh` builds `examples/window_web`, verifies the host
page references the expected runtime and wasm artifacts, checks the runtime
glue and wasm export names, and imports `web/runtime.js` with Node when Node is
available to verify the glue API and dispatch binding.

`scripts/check_moui_web_smoke.sh` builds `examples/moui_web_smoke`, verifies the
host page and wasm artifact cover canvas identity, surface/scale, redraw,
resize, pointer, and keyboard evidence hooks, and runs a Node DOM-shim consumer
runtime smoke when the host supports the required wasm-gc interop. The Web
consumer smoke requires the exact `moui-web-smoke-canvas` identity, `640x360`
surface, pointer `24,32`, keyboard text `a`, redraw, resize, and ready
sentinels before reporting PASS.

Runtime smoke is intentionally separate from the default gate because it opens
windows or serves a browser page. Use `scripts/smoke_runtime.sh <backend>` to
run the matching interactive smoke entry point. Non-dry-run native runtime
smoke still requires a matching host. Set `WINDOW_RUNTIME_SMOKE_DRY_RUN=1` to
print the selected command and checklist without launching the runtime. Dry-run
mode can be used on any host to audit all backend runtime command selections,
including the strict Linux input smoke command.
For Web, the helper runs the Web asset and MoUI consumer-smoke preflight before
serving both `examples/window_web/index.html` and
`examples/moui_web_smoke/index.html`; the latter is the browser page used for
MoUI consumer evidence.
The default gate still runs `scripts/check_runtime_smoke.sh` to verify these
dry-run and host-mismatch paths without opening windows.
It also runs `scripts/check_docs_smoke.sh` so the documented gate and smoke
entry points stay in sync with the scripts on disk.
`scripts/check_moui_readiness.sh` adds a noninteractive readiness audit over
the MoUI smoke matrix: macOS/Web may only be documented as passed with recorded
evidence, while Linux/Windows must remain pending until matching-host runtime
evidence is recorded.
`scripts/check_moui_evidence.sh` verifies the evidence helper itself: passed
native evidence must be produced on the matching host or explicitly name the
remote matching host, the copyable recorder templates must satisfy the helper's
current option rules, and the helper must not edit `docs/platform-gaps.md`.
For Linux/Windows matching-host runs, use
`bash scripts/capture_moui_runtime_evidence.sh <linux|windows> --log <path>` as the
matching-host capture helper when you want one command to run the host CI
branch, save the native runtime transcript, verify it with
`scripts/check_moui_runtime_log.sh`, and print the standard evidence entry.
`scripts/check_ffi_surface.sh` audits the native export allowlists for macOS,
Linux, and Windows so backend FFI surface changes require explicit review. It
also verifies Linux/Windows MoonBit `extern "C"` bindings only target reviewed
native export symbols, and checks each preview backend's real platform branch
exports the same symbols with matching ABI signatures as its non-host stub
branch, so stale, unexported, or signature-drifted backend bindings cannot
drift silently.
`scripts/check_moon_baseline.sh` runs `moon info`, verifies tracked
`pkg.generated.mbti` files did not drift, runs `moon info web --target wasm-gc`,
runs `moon fmt --check`, and runs bare moon test on macOS where the current
cross-package native test graph is executable. On Linux/Windows, keep using the
matching host CI branch and backend smoke for native runtime evidence.
Use `bash scripts/record_moui_evidence.sh <backend>` after a matching-host runtime
run to print the standard `docs/platform-gaps.md` evidence entry. The helper is
write-free by design: it does not upgrade backend status or edit documentation
without review. For native backends, a `--status passed` entry must be
generated on the matching host, or use `--host` to name the remote matching
host where the run was actually observed. A `--status passed` entry also
requires explicit `yes` values for `--window-opened`, `--resize-redraw`,
`--input`, and `--clean-exit`; partial runtime evidence should stay pending or
failed until the missing fact is observed. The runtime `--input` fact is
separate from downstream MoUI input delivery; use `--consumer-input yes` only
after the MoUI consumer smoke has observed input through the public backend API.
Any observed MoUI consumer field also requires `--consumer-command` with the
exact downstream command that produced the evidence. Evidence entries also
print a computed MoUI consumer status, which stays pending for runtime-only
records or for native Linux/Windows records that still lack
monitor/current-monitor and cursor evidence.
When generating evidence from a different machine after receiving external
Linux/Windows logs, first validate the transcript with
`scripts/check_moui_runtime_log.sh <linux|windows> <captured-log>`, then include
the matching `--host`, `--runtime-log yes`, and `--runtime-log-command` in the
evidence entry. `scripts/check_moui_evidence.sh` rejects passed Linux/Windows
evidence that lacks explicit runtime log verification. The
`--runtime-log-command` value must be the verifier command itself,
`scripts/check_moui_runtime_log.sh ...` or
`bash scripts/check_moui_runtime_log.sh ...`, so wrapper text that only mentions
the verifier is not accepted as evidence. The accepted command has exactly one
concrete captured-log path and rejects shell chaining, redirection, extra
arguments, and `<captured-log>` placeholders for verified evidence. Any passed Linux/Windows evidence,
including matching-host records, must include
`--runtime-log yes` with the accepted verifier command. Linux passed evidence
must use strict runtime log verification, not
`--linux-input pending-ok`.

Use `moon info` after public API work to refresh tracked package interfaces.
The Web package is `wasm-gc`-only, so the current tool reports its requested
interface under `_build/wasm-gc/...` instead of writing a tracked
`web/pkg.generated.mbti` for the canonical `native` backend. Use
`moon info web --target wasm-gc` when reviewing the Web public surface.

## Smoke Matrix

Use these as the minimum backend smoke paths while the fork is being prepared
for MoUI integration:

| Backend | Build smoke | Runtime smoke |
| --- | --- | --- |
| macOS | `WINDOW_CI_HOST=macos bash scripts/check_ci.sh`; `scripts/check_moui_macos_smoke.sh` | `scripts/smoke_runtime.sh macos` or `scripts/check_moui_macos_smoke.sh --run` |
| Web | `scripts/check_web_assets.sh`; `scripts/check_moui_web_smoke.sh` | `scripts/smoke_runtime.sh web`, then open `http://127.0.0.1:8000/examples/window_web/index.html` and `http://127.0.0.1:8000/examples/moui_web_smoke/index.html` |
| Linux | `WINDOW_CI_HOST=linux bash scripts/check_ci.sh`; `scripts/check_moui_linux_smoke.sh` | In a Wayland session or Weston, run `scripts/smoke_runtime.sh linux` or `scripts/check_moui_linux_smoke.sh --run`; add `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` for full input evidence, or use `bash scripts/capture_moui_runtime_evidence.sh linux --log <path>` to capture and verify the transcript before printing the evidence entry |
| Windows | `WINDOW_CI_HOST=windows bash scripts/check_ci.sh`; `scripts/check_moui_windows_smoke.sh` | In an MSVC or Mingw shell, run `scripts/smoke_runtime.sh windows` or `scripts/check_moui_windows_smoke.sh --run`, or use `bash scripts/capture_moui_runtime_evidence.sh windows --log <path>` to capture and verify the transcript before printing the evidence entry |

Only claim a full backend runtime smoke as passed after observing that the
window opens, receives a resize/redraw event, receives representative input,
and exits cleanly.

For example, after a strict Linux Wayland runtime run with input evidence,
generate a runtime-only entry skeleton with:

```bash
bash scripts/record_moui_evidence.sh linux --status passed --window-opened yes --resize-redraw yes --input yes --clean-exit yes --runtime-log yes --runtime-log-command "scripts/check_moui_runtime_log.sh linux <captured-log>"
```

When generating that entry from a different machine after receiving external
logs, include the matching host explicitly, for example
`--host "Linux Weston CI"`, and validate the captured transcript first with
`scripts/check_moui_runtime_log.sh linux <captured-log>` or
`scripts/check_moui_runtime_log.sh windows <captured-log>`. Passed
Linux/Windows entries should also include `--runtime-log yes` and
`--runtime-log-command "scripts/check_moui_runtime_log.sh <backend> <captured-log>"`.
Linux passed evidence must not use `--linux-input pending-ok`; that verifier
mode is only for core transcripts where input automation is still pending.
On the matching Linux/Windows host itself, the capture helper writes the
transcript and supplies those runtime-log fields automatically:

```bash
bash scripts/capture_moui_runtime_evidence.sh linux --log artifacts/moui-linux-runtime.log
bash scripts/capture_moui_runtime_evidence.sh windows --log artifacts/moui-windows-runtime.log
```

Full MoUI consumer evidence records also include
`--consumer-command`, `--surface yes`, `--redraw yes`,
`--resize-scale yes`, `--consumer-input yes`, `--renderer-handle yes`,
`--text-input yes`, `--monitor-cursor yes`, and `--clean-shutdown yes`. The
copyable Web/macOS passed templates and Linux/Windows pending templates live in
`docs/moui-integration-smoke.md`.

See `docs/platform-gaps.md` for backend-specific gaps that remain after these
smoke checks. See `docs/moui-integration-smoke.md` for the additional
consumer-side checks needed before calling a backend MoUI-ready.

`moon test --build-only` is intentional for the macOS package. The current
MoonBit native test runner executes generated native tests through `tcc -run`,
and that path does not currently pass macOS framework arguments such as
`-framework AppKit` in a way `tcc -run` accepts. The failure mode is:

```text
tcc: error: file 'AppKit' not found
```

That is a toolchain/native-runner execution limitation, not evidence that the
macOS package fails to compile. The same limitation can affect AppKit-linked
examples when they are executed through `moon run --target native`. Until the
runner supports framework-linked native execution on macOS, the repository gate
verifies macOS tests and examples with build-only commands and keeps executable
unit tests on packages that do not need AppKit framework execution.

For upstream-vs-MoonBit example transcript parity, run the slower optional gate
only in an environment where `moon run --target native` can execute
AppKit-linked examples:

```bash
RUN_EXAMPLE_TRANSCRIPTS=1 bash scripts/check_ci.sh
```

This runs `scripts/check_example_transcripts.sh`, normalizes unstable prefixes,
ANSI sequences, timestamps, IDs, and addresses, then performs a strict diff on
the remaining message bodies.
