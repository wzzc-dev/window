# MoUI-ready matrix (window backends)

Acceptance bar for this fork: **MoUI-ready parity**, not full winit / every
macOS-only API. A backend is MoUI-ready when matching-host smoke proves the
rows below, or gaps are explicitly accepted with a platform contract.

Contract kinds: `native` | `state-only` | `NotSupported` | `no-op` | `placeholder`.

## Critical path (all backends)

| Capability | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS |
|------------|-------|---------|-------|-----|---------|-----|-----------|
| EventLoop + ApplicationHandler | native | native | native | native | hosted host-sim | hosted host-sim | hosted host-sim |
| create_window / surface size / scale | native | native | native | native | host-gated | host-gated | host-gated |
| can_create_surfaces / destroy_surfaces | native | native | native | native | HostCmd | HostCmd | HostCmd |
| Raw window handle for GPU | content view | HWND | wl_surface | canvas id | ANativeWindow* | UIView* | XComponent |
| Soft present / clear | native | n/a (GPU app) | present_rgba | canvas | present_rgba host-sim | present_rgba host-sim | present_rgba host-sim |
| Resize / redraw | native | native | native | native | HostCmd | HostCmd | HostCmd |
| Pointer | native | native | native* | native | HostCmd | HostCmd | HostCmd |
| Keyboard / text | native | native | native* | native | HostCmd text MVP | HostCmd text MVP | HostCmd text MVP |
| request_ime_update | native | state+native path | state+protocol | n/a / web input | state-only MVP | state-only MVP | state-only MVP |
| Monitor / cursor probes | native | native | native | placeholder | placeholder | placeholder | placeholder |
| Clean exit | native | native | native | native | HostCmd Destroy | HostCmd Destroy | HostCmd Destroy |

\*Linux interactive pointer/keyboard evidence still requires a matching Wayland
session with `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` for full MoUI-ready promotion.

## Non-goals (do not block MoUI-ready)

- macOS-only: `content_view_handle`, system menu bar product, tabbing APIs
- Exclusive fullscreen / rich decorations / DnD productization beyond MoUI use
- Multi-window mobile
- Soft keyboard full IME UI on mobile (committed text + state IME is MVP)

## Evidence commands

| Backend | Build | Runtime |
|---------|-------|---------|
| macOS | `bash scripts/check_ci.sh` | `scripts/check_moui_macos_smoke.sh` |
| Windows | `WINDOW_CI_HOST=windows bash scripts/check_ci.sh` | `scripts/check_moui_windows_smoke.sh --run` |
| Linux | `WINDOW_CI_HOST=linux bash scripts/check_ci.sh` | `scripts/check_moui_linux_smoke.sh --run` (+ `--require-input`) |
| Web | `moon check -p web --target wasm-gc` | `scripts/check_moui_web_smoke.sh` |
| Android | `bash scripts/check_android_hosted_smoke.sh` | host-sim + C queue bridge tests; device present M3 |
| iOS | `bash scripts/check_ios_hosted_smoke.sh` | host-sim + C queue bridge tests; UIKit device M3 |
| HarmonyOS | `bash scripts/check_harmonyos_hosted_smoke.sh` | host-sim + C queue bridge tests; XComponent device M3 |

See also `docs/mobile-hosted-backend.md` and `docs/platform-gaps.md`.
