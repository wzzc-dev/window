# Mobile hosted backend changelog (window)

## 0.5.4-0.1.0+ (moui-support worktree)

Breaking mobile API:

- Removed `inject_*` and `bind_surface` from android/ios/harmonyos.
- Added HostCmd queue (`host_push`) + C host queue (`mbw_*_host_on_*` / poll).
- `create_window` requires host surface readiness (`can_create_surfaces`).
- Added `surface_generation`, soft `present_rgba_pixels` / `clear_color`.
- Templates under `{android,ios,harmonyos}/template`.

Desktop/Web:

- Web `pkg.generated.mbti` committed.
- Windows/Linux MoUI-critical API smoke tests.
- macOS remains reference; only intentional gap is macOS-only `content_view_handle`.
