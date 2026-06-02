#ifndef __linux__

// MOONBIT_WINDOW_WAYLAND_PROTOCOL_PLACEHOLDER
//
// Moon's build graph requires native-stub inputs to exist even on hosts that
// cannot generate Wayland protocol sources. The Linux prebuild step replaces
// this placeholder with `wayland-scanner private-code` output before compiling
// the real Wayland backend.

typedef int mbw_xdg_shell_protocol_placeholder;

#else
#error "xdg-shell protocol source placeholder reached a Linux build; install wayland-protocols and rerun the prebuild step"
#endif
