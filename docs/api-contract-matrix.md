# Window API contract matrix (MoUI-ready)

Generated as part of the cross-platform parity plan
(`docs/plans/active/window-cross-platform-parity.md` in the MoUI superrepo).

**Bar**: MoUI-ready semantics, not full winit. Contract kinds:

| Kind | Meaning |
|------|---------|
| `native` | Real OS / compositor / browser behavior |
| `state-only` | Public getter/setter stores state; no native effect claimed |
| `NotSupported` | Explicit `RequestError::not_supported` (or documented fail) |
| `no-op` | Intentionally inert |
| `placeholder` | Stable fallback identity / value for cross-platform compile |
| `hosted` | HostCmd / host surface gate (mobile) |

macOS-only APIs (`content_view_handle`, system menu product, tabbing) are
**out of scope** for non-macOS backends.

## Critical path

| Capability | macOS | Windows | Linux | Web | Android | iOS | HarmonyOS |
|---|---|---|---|---|---|---|---|
| EventLoop + ApplicationHandler | native | native | native | native | hosted | hosted | hosted |
| create_window / size / scale | native | native | native | native | host-gated | host-gated | host-gated |
| can_create / destroy_surfaces | native | native | native | native | HostCmd | HostCmd | HostCmd |
| Raw GPU handle | content view | HWND | wl_surface | canvas id | ANativeWindow* | UIView* | XComponent |
| Soft present / clear | n/a (GPU app) | n/a | present_rgba | n/a | present_rgba (+ANativeWindow on device) | present_rgba (+CG layer on device) | present_rgba host-sim; device GPU app-owned |
| Resize / redraw | native | native | native | native | HostCmd | HostCmd | HostCmd |
| Pointer | native | native | native* | native | HostCmd | HostCmd | HostCmd |
| Keyboard / text | native | native | native* | native | text MVP | text MVP | text MVP |
| request_ime_update | native | state+native path | state+protocol | browser input | state-only MVP | state-only MVP | state-only MVP |
| Monitor / cursor probes | native | native | native | placeholder / primary | placeholder | placeholder | placeholder |
| Clean exit | native | native | native | native | HostCmd Destroy | HostCmd Destroy | HostCmd Destroy |

\*Linux interactive input evidence still requires matching Wayland session +
`WINDOW_MOUI_LINUX_REQUIRE_INPUT=1`.

## Selected Window API contracts (parity notes)

| API | macOS | Windows | Linux | Web | Mobile |
|-----|-------|---------|-------|-----|--------|
| `set_cursor_visible` | native | **native** (`ShowCursor`) | state-only | canvas CSS cursor | no-op / state |
| `set_cursor_grab` | confined NotSupported | confined NotSupported; Locked clips | only None | only None | NotSupported |
| `set_cursor_position` | native | native | NotSupported | NotSupported | NotSupported |
| `focus_window` / `has_focus` | native | native (foreground HWND) | **state from keyboard focus events** (cannot force focus on Wayland) | **browser focus + Focused events** | state / host |
| `set_fullscreen` | native AppKit | native borderless | **xdg_toplevel set/unset_fullscreen** | **Fullscreen API best-effort + state** | state-only |
| `set_maximized` / `set_minimized` | native | native | native xdg | no-op | no-op |
| `drag_window` / `drag_resize` | native / NotSupported | native | NotSupported | NotSupported | NotSupported |
| `set_decorations` | native | native | decoration protocol | state-only | state-only |
| `content_view_handle` | macOS-only | — | — | — | — |

## Evidence commands

See `docs/moui-ready-matrix.md` and `docs/platform-gaps.md`.

## Change log

| Date | Note |
|------|------|
| 2026-07-21 | Initial matrix; Windows cursor visible native; Linux focus state + fullscreen; Web focus/fullscreen; iOS soft present on device. |
