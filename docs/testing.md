# Testing

This repository uses `scripts/check_ci.sh` as the default local validation gate.

```bash
bash scripts/check_ci.sh
```

The gate runs:

- `scripts/check_ci_host.sh`
- `scripts/check_runtime_smoke.sh`
- `scripts/check_docs_smoke.sh`
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
- `scripts/check_web_assets.sh`
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

`scripts/check_web_assets.sh` builds `examples/window_web`, verifies the host
page references the expected runtime and wasm artifacts, checks the runtime
glue and wasm export names, and imports `web/runtime.js` with Node when Node is
available to verify the glue API and dispatch binding.

Runtime smoke is intentionally separate from the default gate because it opens
windows or serves a browser page. Use `scripts/smoke_runtime.sh <backend>` to
run the matching interactive smoke entry point. Set
`WINDOW_RUNTIME_SMOKE_DRY_RUN=1` to print the selected command and checklist
without launching the runtime.
The default gate still runs `scripts/check_runtime_smoke.sh` to verify these
dry-run and host-mismatch paths without opening windows.
It also runs `scripts/check_docs_smoke.sh` so the documented gate and smoke
entry points stay in sync with the scripts on disk.

## Smoke Matrix

Use these as the minimum backend smoke paths while the fork is being prepared
for MoUI integration:

| Backend | Build smoke | Runtime smoke |
| --- | --- | --- |
| macOS | `WINDOW_CI_HOST=macos bash scripts/check_ci.sh` | Build-only until framework-linked `moon run` is fixed; then run `scripts/smoke_runtime.sh macos` |
| Web | `scripts/check_web_assets.sh` | `scripts/smoke_runtime.sh web`, then open `http://127.0.0.1:8000/examples/window_web/index.html` |
| Linux | `WINDOW_CI_HOST=linux bash scripts/check_ci.sh` | In a Wayland session or Weston, run `scripts/smoke_runtime.sh linux` |
| Windows | `WINDOW_CI_HOST=windows bash scripts/check_ci.sh` | In an MSVC or Mingw shell, run `scripts/smoke_runtime.sh windows` |

Only claim a runtime smoke as passed after observing that the window opens,
receives a resize/redraw event, and exits cleanly.

See `docs/platform-gaps.md` for backend-specific gaps that remain after these
smoke checks.

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
