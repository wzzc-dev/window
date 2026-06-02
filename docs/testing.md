# Testing

This repository uses `scripts/check_ci.sh` as the default local validation gate.

```bash
bash scripts/check_ci.sh
```

The gate runs:

- `scripts/check_ci_host.sh`
- `scripts/check_runtime_smoke.sh`
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
`scripts/check_moui_macos_smoke.sh --run` to launch the built executable and
require those sentinel lines at runtime, with `destroyed` before `finished`.

`scripts/check_moui_linux_smoke.sh` builds `examples/moui_linux_smoke` on a
Linux host and verifies the smoke source covers surface/scale, public Wayland
handles, monitor/current-monitor probes, cursor state,
`present_rgba_pixels(...)`, resize, redraw, input hooks, and clean-shutdown
sentinel hooks. Run `scripts/check_moui_linux_smoke.sh --run`
inside Wayland or Weston to collect automated core runtime evidence. Pointer
and keyboard lines are logged when supplied, but Linux input automation remains
separate evidence. Set `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` or pass
`--require-input` with `--run` to require pointer and keyboard evidence on a
matching host. The runtime check requires `destroyed` before `finished`.

`scripts/check_moui_windows_smoke.sh` builds `examples/moui_windows_smoke` on a
Windows host and verifies the smoke source covers surface/scale, public HWND
handle, monitor/current-monitor probes, cursor state, resize, redraw,
representative pointer/keyboard/text input, and clean-shutdown sentinel hooks.
Run `scripts/check_moui_windows_smoke.sh --run`
to launch the built executable and require those sentinel lines at runtime,
with `destroyed` before `finished`.

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
run the matching interactive smoke entry point. Set
`WINDOW_RUNTIME_SMOKE_DRY_RUN=1` to print the selected command and checklist
without launching the runtime.
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
`scripts/check_moon_baseline.sh` runs `moon info`, verifies tracked
`pkg.generated.mbti` files did not drift, runs `moon info web --target wasm-gc`,
runs `moon fmt --check`, and runs bare moon test on macOS where the current
cross-package native test graph is executable. On Linux/Windows, keep using the
matching host CI branch and backend smoke for native runtime evidence.
Use `scripts/record_moui_evidence.sh <backend>` after a matching-host runtime
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
exact downstream command that produced the evidence.

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
| Linux | `WINDOW_CI_HOST=linux bash scripts/check_ci.sh`; `scripts/check_moui_linux_smoke.sh` | In a Wayland session or Weston, run `scripts/smoke_runtime.sh linux` or `scripts/check_moui_linux_smoke.sh --run`; add `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` for full input evidence |
| Windows | `WINDOW_CI_HOST=windows bash scripts/check_ci.sh`; `scripts/check_moui_windows_smoke.sh` | In an MSVC or Mingw shell, run `scripts/smoke_runtime.sh windows` or `scripts/check_moui_windows_smoke.sh --run` |

Only claim a full backend runtime smoke as passed after observing that the
window opens, receives a resize/redraw event, receives representative input,
and exits cleanly.

For example, after a strict Linux Wayland runtime run with input evidence,
generate a runtime-only entry skeleton with:

```bash
scripts/record_moui_evidence.sh linux --status passed --window-opened yes --resize-redraw yes --input yes --clean-exit yes
```

When generating that entry from a different machine after receiving external
logs, include the matching host explicitly, for example
`--host "Linux Weston CI"`.
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
