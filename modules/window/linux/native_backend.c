// Backend dispatch layer for the wzzc-dev/window Linux package.
//
// Both `native_wayland.c` (`mbw_wayland_*`) and `native_x11.c` (`mbw_x11_*`)
// allocate context/window structs whose FIRST field is an int32 backend tag.
// Every `mbw_native_*` entry point below routes to the matching backend
// implementation by reading that tag. `mbw_native_context_new` performs the
// backend selection probe (MOUI_LINUX_WINDOWING / WAYLAND_DISPLAY / DISPLAY).

#ifdef __linux__

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#include <moonbit.h>
#include <stdint.h>

enum {
  MBW_BACKEND_TAG_WAYLAND = 1,
  MBW_BACKEND_TAG_X11 = 2,
};

typedef void (*mbw_window_event_trampoline_t)(void *closure,
                                              int32_t kind, int32_t raw_id,
                                              int32_t arg0, int32_t arg1,
                                              int32_t arg2, double argd);
typedef void (*mbw_input_event_trampoline_t)(void *closure,
                                             int32_t raw_id, int32_t kind,
                                             int32_t arg0, int32_t arg1,
                                             int32_t arg2, int64_t argi);

// -------------------------------------------------------- backend prototypes

// Wayland backend (native_wayland.c).
uint64_t mbw_wayland_context_new(void);
void mbw_wayland_context_destroy(uint64_t raw_context);
uint64_t mbw_wayland_context_display_handle(uint64_t raw_context);
int32_t mbw_wayland_context_wake_fd(uint64_t raw_context);
int32_t mbw_wayland_context_system_theme(uint64_t raw_context);
int32_t mbw_wayland_context_clipboard_available(uint64_t raw_context);
moonbit_bytes_t mbw_wayland_context_clipboard_read_text(uint64_t raw_context);
int32_t mbw_wayland_context_clipboard_write_text(uint64_t raw_context,
                                                 const uint8_t *text,
                                                 int32_t text_len);
int32_t mbw_wayland_context_drag_drop_available(uint64_t raw_context);
int32_t mbw_wayland_monitor_count(uint64_t raw_context);
uint64_t mbw_wayland_monitor_handle_at(uint64_t raw_context, int32_t index);
int32_t mbw_wayland_monitor_rect_left_at(uint64_t raw_context, int32_t index);
int32_t mbw_wayland_monitor_rect_top_at(uint64_t raw_context, int32_t index);
int32_t mbw_wayland_monitor_rect_width_at(uint64_t raw_context, int32_t index);
int32_t mbw_wayland_monitor_rect_height_at(uint64_t raw_context, int32_t index);
double mbw_wayland_monitor_scale_factor_at(uint64_t raw_context,
                                           int32_t index);
moonbit_bytes_t mbw_wayland_monitor_name_bytes_at(uint64_t raw_context,
                                                  int32_t index);
int32_t mbw_wayland_context_dispatch(uint64_t raw_context, int32_t timeout_ms);
void mbw_wayland_context_wake(uint64_t raw_context);
uint64_t mbw_wayland_window_create(uint64_t raw_context, int32_t raw_id,
                                   int32_t width, int32_t height,
                                   const uint8_t *title, int32_t title_len,
                                   const uint8_t *app_id, int32_t app_id_len,
                                   int decorations, int use_shm_placeholder);
void mbw_wayland_window_destroy(uint64_t raw_window);
int32_t mbw_wayland_window_wait_configured(uint64_t raw_window,
                                           int32_t timeout_ms);
uint64_t mbw_wayland_window_surface_handle(uint64_t raw_window);
uint64_t mbw_wayland_window_xdg_surface_handle(uint64_t raw_window);
uint64_t mbw_wayland_window_xdg_toplevel_handle(uint64_t raw_window);
uint64_t mbw_wayland_window_display_handle(uint64_t raw_window);
uint64_t mbw_wayland_window_current_monitor_handle(uint64_t raw_window);
int32_t mbw_wayland_window_client_decorated(uint64_t raw_window);
moonbit_bytes_t mbw_wayland_window_take_drag_paths(uint64_t raw_window);
void mbw_wayland_window_set_title(uint64_t raw_window, const uint8_t *title,
                                  int32_t title_len);
void mbw_wayland_window_set_decorations(uint64_t raw_window, int decorations);
void mbw_wayland_window_set_minimized(uint64_t raw_window, int minimized);
void mbw_wayland_window_set_maximized(uint64_t raw_window, int maximized);
void mbw_wayland_window_set_fullscreen(uint64_t raw_window, int fullscreen);
void mbw_wayland_window_set_visible(uint64_t raw_window, int visible);
void mbw_wayland_window_request_surface_size(uint64_t raw_window, int32_t width,
                                             int32_t height);
void mbw_wayland_window_request_redraw(uint64_t raw_window);
int32_t mbw_wayland_window_present_rgba_pixels(uint64_t raw_window,
                                               int32_t width, int32_t height,
                                               int32_t row_bytes,
                                               const uint8_t *pixels,
                                               int32_t pixels_len);
void mbw_wayland_install_window_event_callback(
    mbw_window_event_trampoline_t trampoline, void *closure);
void mbw_wayland_install_input_event_callback(
    mbw_input_event_trampoline_t trampoline, void *closure);

// X11 backend (native_x11.c).
uint64_t mbw_x11_context_new(void);
void mbw_x11_context_destroy(uint64_t raw_context);
uint64_t mbw_x11_context_display_handle(uint64_t raw_context);
int32_t mbw_x11_context_wake_fd(uint64_t raw_context);
int32_t mbw_x11_context_system_theme_int(uint64_t raw_context);
int32_t mbw_x11_context_clipboard_available(uint64_t raw_context);
moonbit_bytes_t mbw_x11_context_clipboard_read_text(uint64_t raw_context);
int32_t mbw_x11_context_clipboard_write_text(uint64_t raw_context,
                                             const uint8_t *text,
                                             int32_t text_len);
int32_t mbw_x11_context_drag_drop_available(uint64_t raw_context);
int32_t mbw_x11_monitor_count(uint64_t raw_context);
uint64_t mbw_x11_monitor_handle_at(uint64_t raw_context, int32_t index);
int32_t mbw_x11_monitor_rect_left_at(uint64_t raw_context, int32_t index);
int32_t mbw_x11_monitor_rect_top_at(uint64_t raw_context, int32_t index);
int32_t mbw_x11_monitor_rect_width_at(uint64_t raw_context, int32_t index);
int32_t mbw_x11_monitor_rect_height_at(uint64_t raw_context, int32_t index);
double mbw_x11_monitor_scale_factor_at(uint64_t raw_context, int32_t index);
moonbit_bytes_t mbw_x11_monitor_name_bytes_at(uint64_t raw_context,
                                              int32_t index);
int32_t mbw_x11_context_dispatch(uint64_t raw_context, int32_t timeout_ms);
void mbw_x11_context_wake(uint64_t raw_context);
uint64_t mbw_x11_window_create(uint64_t raw_context, int32_t raw_id,
                               int32_t width, int32_t height,
                               const uint8_t *title, int32_t title_len,
                               const uint8_t *app_id, int32_t app_id_len,
                               int decorations, int use_shm_placeholder);
void mbw_x11_window_destroy(uint64_t raw_window);
int32_t mbw_x11_window_wait_configured(uint64_t raw_window,
                                       int32_t timeout_ms);
uint64_t mbw_x11_window_surface_handle(uint64_t raw_window);
uint64_t mbw_x11_window_xdg_surface_handle(uint64_t raw_window);
uint64_t mbw_x11_window_xdg_toplevel_handle(uint64_t raw_window);
uint64_t mbw_x11_window_display_handle(uint64_t raw_window);
uint64_t mbw_x11_window_current_monitor_handle(uint64_t raw_window);
int32_t mbw_x11_window_client_decorated(uint64_t raw_window);
moonbit_bytes_t mbw_x11_window_take_drag_paths(uint64_t raw_window);
void mbw_x11_window_set_title(uint64_t raw_window, const uint8_t *title,
                              int32_t title_len);
void mbw_x11_window_set_decorations(uint64_t raw_window, int decorations);
void mbw_x11_window_set_minimized(uint64_t raw_window, int minimized);
void mbw_x11_window_set_maximized(uint64_t raw_window, int maximized);
void mbw_x11_window_set_fullscreen(uint64_t raw_window, int fullscreen);
void mbw_x11_window_set_visible(uint64_t raw_window, int visible);
void mbw_x11_window_request_surface_size(uint64_t raw_window, int32_t width,
                                         int32_t height);
void mbw_x11_window_request_redraw(uint64_t raw_window);
int32_t mbw_x11_window_present_rgba_pixels(uint64_t raw_window, int32_t width,
                                           int32_t height, int32_t row_bytes,
                                           const uint8_t *pixels,
                                           int32_t pixels_len);
void mbw_x11_install_window_event_callback(
    mbw_window_event_trampoline_t trampoline, void *closure);
void mbw_x11_install_input_event_callback(mbw_input_event_trampoline_t trampoline,
                                          void *closure);

// ---------------------------------------------------------------- dispatch

static int32_t backend_tag_of(uint64_t raw) {
  if (raw < 4096) {
    return 0;
  }
  return *(int32_t *)(uintptr_t)raw;
}

static int env_nonempty(const char *name) {
  const char *value = getenv(name);
  return value && value[0] != '\0';
}

static int session_type_is_wayland(void) {
  const char *session = getenv("XDG_SESSION_TYPE");
  return session && strcasecmp(session, "wayland") == 0;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_native_context_new(void) {
  const char *override_value = getenv("MOUI_LINUX_WINDOWING");
  const char *requested =
      override_value && override_value[0] ? override_value : "auto";
  int force_x11 = strcasecmp(requested, "x11") == 0;
  int force_wayland = strcasecmp(requested, "wayland") == 0;
  if (force_x11) {
    uint64_t context = mbw_x11_context_new();
    if (context) {
      fprintf(stderr, "moui windowing backend: x11 (MOUI_LINUX_WINDOWING)\n");
      return context;
    }
    fprintf(stderr,
            "moui windowing backend: x11 requested but XOpenDisplay failed\n");
    return 0;
  }
  if (force_wayland) {
    uint64_t context = mbw_wayland_context_new();
    if (context) {
      fprintf(stderr,
              "moui windowing backend: wayland (MOUI_LINUX_WINDOWING)\n");
      return context;
    }
    fprintf(stderr,
            "moui windowing backend: wayland requested but connection failed\n");
    return 0;
  }
  // Auto: prefer Wayland on a Wayland session, X11 when only DISPLAY exists;
  // always fall back to the other backend if the preferred one fails.
  int wayland_first = env_nonempty("WAYLAND_DISPLAY") ||
                      session_type_is_wayland() ||
                      !env_nonempty("DISPLAY");
  for (int attempt = 0; attempt < 2; ++attempt) {
    int try_wayland = wayland_first ? attempt == 0 : attempt == 1;
    uint64_t context = try_wayland ? mbw_wayland_context_new()
                                   : mbw_x11_context_new();
    if (context) {
      fprintf(stderr, "moui windowing backend: %s (auto)\n",
              try_wayland ? "wayland" : "x11");
      return context;
    }
  }
  fprintf(stderr,
          "moui windowing backend: no display server available "
          "(tried wayland and x11)\n");
  return 0;
}

MOONBIT_FFI_EXPORT
void mbw_native_context_destroy(uint64_t raw_context) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    mbw_x11_context_destroy(raw_context);
  } else {
    mbw_wayland_context_destroy(raw_context);
  }
}

MOONBIT_FFI_EXPORT
uint64_t mbw_native_context_display_handle(uint64_t raw_context) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_context_display_handle(raw_context);
  }
  return mbw_wayland_context_display_handle(raw_context);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_context_wake_fd(uint64_t raw_context) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_context_wake_fd(raw_context);
  }
  return mbw_wayland_context_wake_fd(raw_context);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_context_system_theme(uint64_t raw_context) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_context_system_theme_int(raw_context);
  }
  return mbw_wayland_context_system_theme(raw_context);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_context_clipboard_available(uint64_t raw_context) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_context_clipboard_available(raw_context);
  }
  return mbw_wayland_context_clipboard_available(raw_context);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_native_context_clipboard_read_text(uint64_t raw_context) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_context_clipboard_read_text(raw_context);
  }
  return mbw_wayland_context_clipboard_read_text(raw_context);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_context_clipboard_write_text(uint64_t raw_context,
                                                const uint8_t *text,
                                                int32_t text_len) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_context_clipboard_write_text(raw_context, text, text_len);
  }
  return mbw_wayland_context_clipboard_write_text(raw_context, text, text_len);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_context_drag_drop_available(uint64_t raw_context) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_context_drag_drop_available(raw_context);
  }
  return mbw_wayland_context_drag_drop_available(raw_context);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_count(uint64_t raw_context) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_monitor_count(raw_context);
  }
  return mbw_wayland_monitor_count(raw_context);
}

MOONBIT_FFI_EXPORT
uint64_t mbw_native_monitor_handle_at(uint64_t raw_context, int32_t index) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_monitor_handle_at(raw_context, index);
  }
  return mbw_wayland_monitor_handle_at(raw_context, index);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_rect_left_at(uint64_t raw_context, int32_t index) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_monitor_rect_left_at(raw_context, index);
  }
  return mbw_wayland_monitor_rect_left_at(raw_context, index);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_rect_top_at(uint64_t raw_context, int32_t index) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_monitor_rect_top_at(raw_context, index);
  }
  return mbw_wayland_monitor_rect_top_at(raw_context, index);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_rect_width_at(uint64_t raw_context, int32_t index) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_monitor_rect_width_at(raw_context, index);
  }
  return mbw_wayland_monitor_rect_width_at(raw_context, index);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_rect_height_at(uint64_t raw_context, int32_t index) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_monitor_rect_height_at(raw_context, index);
  }
  return mbw_wayland_monitor_rect_height_at(raw_context, index);
}

MOONBIT_FFI_EXPORT
double mbw_native_monitor_scale_factor_at(uint64_t raw_context,
                                          int32_t index) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_monitor_scale_factor_at(raw_context, index);
  }
  return mbw_wayland_monitor_scale_factor_at(raw_context, index);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_native_monitor_name_bytes_at(uint64_t raw_context,
                                                 int32_t index) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_monitor_name_bytes_at(raw_context, index);
  }
  return mbw_wayland_monitor_name_bytes_at(raw_context, index);
}

MOONBIT_FFI_EXPORT
int64_t mbw_native_now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + (int64_t)ts.tv_nsec / 1000000;
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_context_dispatch(uint64_t raw_context, int32_t timeout_ms) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_context_dispatch(raw_context, timeout_ms);
  }
  return mbw_wayland_context_dispatch(raw_context, timeout_ms);
}

MOONBIT_FFI_EXPORT
void mbw_native_context_wake(uint64_t raw_context) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    mbw_x11_context_wake(raw_context);
  } else {
    mbw_wayland_context_wake(raw_context);
  }
}

MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_create(uint64_t raw_context, int32_t raw_id,
                                  int32_t width, int32_t height,
                                  const uint8_t *title, int32_t title_len,
                                  const uint8_t *app_id, int32_t app_id_len,
                                  int decorations, int use_shm_placeholder) {
  if (backend_tag_of(raw_context) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_create(raw_context, raw_id, width, height, title,
                                 title_len, app_id, app_id_len, decorations,
                                 use_shm_placeholder);
  }
  return mbw_wayland_window_create(raw_context, raw_id, width, height, title,
                                   title_len, app_id, app_id_len, decorations,
                                   use_shm_placeholder);
}

MOONBIT_FFI_EXPORT
void mbw_native_window_destroy(uint64_t raw_window) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    mbw_x11_window_destroy(raw_window);
  } else {
    mbw_wayland_window_destroy(raw_window);
  }
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_window_wait_configured(uint64_t raw_window,
                                          int32_t timeout_ms) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_wait_configured(raw_window, timeout_ms);
  }
  return mbw_wayland_window_wait_configured(raw_window, timeout_ms);
}

MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_surface_handle(uint64_t raw_window) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_surface_handle(raw_window);
  }
  return mbw_wayland_window_surface_handle(raw_window);
}

MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_xdg_surface_handle(uint64_t raw_window) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_xdg_surface_handle(raw_window);
  }
  return mbw_wayland_window_xdg_surface_handle(raw_window);
}

MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_xdg_toplevel_handle(uint64_t raw_window) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_xdg_toplevel_handle(raw_window);
  }
  return mbw_wayland_window_xdg_toplevel_handle(raw_window);
}

MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_display_handle(uint64_t raw_window) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_display_handle(raw_window);
  }
  return mbw_wayland_window_display_handle(raw_window);
}

MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_current_monitor_handle(uint64_t raw_window) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_current_monitor_handle(raw_window);
  }
  return mbw_wayland_window_current_monitor_handle(raw_window);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_window_client_decorated(uint64_t raw_window) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_client_decorated(raw_window);
  }
  return mbw_wayland_window_client_decorated(raw_window);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_native_window_take_drag_paths(uint64_t raw_window) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_take_drag_paths(raw_window);
  }
  return mbw_wayland_window_take_drag_paths(raw_window);
}

MOONBIT_FFI_EXPORT
void mbw_native_window_set_title(uint64_t raw_window, const uint8_t *title,
                                 int32_t title_len) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    mbw_x11_window_set_title(raw_window, title, title_len);
  } else {
    mbw_wayland_window_set_title(raw_window, title, title_len);
  }
}

MOONBIT_FFI_EXPORT
void mbw_native_window_set_decorations(uint64_t raw_window, int decorations) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    mbw_x11_window_set_decorations(raw_window, decorations);
  } else {
    mbw_wayland_window_set_decorations(raw_window, decorations);
  }
}

MOONBIT_FFI_EXPORT
void mbw_native_window_set_minimized(uint64_t raw_window, int minimized) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    mbw_x11_window_set_minimized(raw_window, minimized);
  } else {
    mbw_wayland_window_set_minimized(raw_window, minimized);
  }
}

MOONBIT_FFI_EXPORT
void mbw_native_window_set_maximized(uint64_t raw_window, int maximized) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    mbw_x11_window_set_maximized(raw_window, maximized);
  } else {
    mbw_wayland_window_set_maximized(raw_window, maximized);
  }
}

MOONBIT_FFI_EXPORT
void mbw_native_window_set_fullscreen(uint64_t raw_window, int fullscreen) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    mbw_x11_window_set_fullscreen(raw_window, fullscreen);
  } else {
    mbw_wayland_window_set_fullscreen(raw_window, fullscreen);
  }
}

MOONBIT_FFI_EXPORT
void mbw_native_window_set_visible(uint64_t raw_window, int visible) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    mbw_x11_window_set_visible(raw_window, visible);
  } else {
    mbw_wayland_window_set_visible(raw_window, visible);
  }
}

MOONBIT_FFI_EXPORT
void mbw_native_window_request_surface_size(uint64_t raw_window, int32_t width,
                                            int32_t height) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    mbw_x11_window_request_surface_size(raw_window, width, height);
  } else {
    mbw_wayland_window_request_surface_size(raw_window, width, height);
  }
}

MOONBIT_FFI_EXPORT
void mbw_native_window_request_redraw(uint64_t raw_window) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    mbw_x11_window_request_redraw(raw_window);
  } else {
    mbw_wayland_window_request_redraw(raw_window);
  }
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_window_present_rgba_pixels(uint64_t raw_window,
                                              int32_t width, int32_t height,
                                              int32_t row_bytes,
                                              const uint8_t *pixels,
                                              int32_t pixels_len) {
  if (backend_tag_of(raw_window) == MBW_BACKEND_TAG_X11) {
    return mbw_x11_window_present_rgba_pixels(raw_window, width, height,
                                              row_bytes, pixels, pixels_len);
  }
  return mbw_wayland_window_present_rgba_pixels(raw_window, width, height,
                                                row_bytes, pixels, pixels_len);
}

MOONBIT_FFI_EXPORT
void mbw_native_install_window_event_callback(
    mbw_window_event_trampoline_t trampoline, void *closure) {
  // Both backends register the same trampoline; only the selected backend
  // emits events, and backend selection happens after these installs.
  mbw_wayland_install_window_event_callback(trampoline, closure);
  mbw_x11_install_window_event_callback(trampoline, closure);
}

MOONBIT_FFI_EXPORT
void mbw_native_install_input_event_callback(
    mbw_input_event_trampoline_t trampoline, void *closure) {
  mbw_wayland_install_input_event_callback(trampoline, closure);
  mbw_x11_install_input_event_callback(trampoline, closure);
}

MOONBIT_FFI_EXPORT
int32_t mbw_native_backend_tag(uint64_t raw) { return backend_tag_of(raw); }

#else

#include <moonbit.h>
#include <stdint.h>

MOONBIT_FFI_EXPORT
uint64_t mbw_native_context_new(void) { return 0; }
MOONBIT_FFI_EXPORT
void mbw_native_context_destroy(uint64_t raw_context) { (void)raw_context; }
MOONBIT_FFI_EXPORT
uint64_t mbw_native_context_display_handle(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_context_wake_fd(uint64_t raw_context) {
  (void)raw_context;
  return -1;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_context_system_theme(uint64_t raw_context) {
  (void)raw_context;
  return -1;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_context_clipboard_available(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_native_context_clipboard_read_text(uint64_t raw_context) {
  (void)raw_context;
  return moonbit_make_bytes(0, 0);
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_context_clipboard_write_text(uint64_t raw_context,
                                                const uint8_t *text,
                                                int32_t text_len) {
  (void)raw_context;
  (void)text;
  (void)text_len;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_context_drag_drop_available(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_count(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_native_monitor_handle_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_rect_left_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_rect_top_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_rect_width_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_monitor_rect_height_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
double mbw_native_monitor_scale_factor_at(uint64_t raw_context,
                                          int32_t index) {
  (void)raw_context;
  (void)index;
  return 1.0;
}
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_native_monitor_name_bytes_at(uint64_t raw_context,
                                                 int32_t index) {
  (void)raw_context;
  (void)index;
  return moonbit_make_bytes(0, 0);
}
MOONBIT_FFI_EXPORT
int64_t mbw_native_now_ms(void) { return 0; }
MOONBIT_FFI_EXPORT
int32_t mbw_native_context_dispatch(uint64_t raw_context, int32_t timeout_ms) {
  (void)raw_context;
  (void)timeout_ms;
  return -1;
}
MOONBIT_FFI_EXPORT
void mbw_native_context_wake(uint64_t raw_context) { (void)raw_context; }
MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_create(uint64_t raw_context, int32_t raw_id,
                                  int32_t width, int32_t height,
                                  const uint8_t *title, int32_t title_len,
                                  const uint8_t *app_id, int32_t app_id_len,
                                  int decorations, int use_shm_placeholder) {
  (void)raw_context;
  (void)raw_id;
  (void)width;
  (void)height;
  (void)title;
  (void)title_len;
  (void)app_id;
  (void)app_id_len;
  (void)decorations;
  (void)use_shm_placeholder;
  return 0;
}
MOONBIT_FFI_EXPORT
void mbw_native_window_destroy(uint64_t raw_window) { (void)raw_window; }
MOONBIT_FFI_EXPORT
int32_t mbw_native_window_wait_configured(uint64_t raw_window,
                                          int32_t timeout_ms) {
  (void)raw_window;
  (void)timeout_ms;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_surface_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_xdg_surface_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_xdg_toplevel_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_display_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_native_window_current_monitor_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_window_client_decorated(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_native_window_take_drag_paths(uint64_t raw_window) {
  (void)raw_window;
  return moonbit_make_bytes(0, 0);
}
MOONBIT_FFI_EXPORT
void mbw_native_window_set_title(uint64_t raw_window, const uint8_t *title,
                                 int32_t title_len) {
  (void)raw_window;
  (void)title;
  (void)title_len;
}
MOONBIT_FFI_EXPORT
void mbw_native_window_set_decorations(uint64_t raw_window, int decorations) {
  (void)raw_window;
  (void)decorations;
}
MOONBIT_FFI_EXPORT
void mbw_native_window_set_minimized(uint64_t raw_window, int minimized) {
  (void)raw_window;
  (void)minimized;
}
MOONBIT_FFI_EXPORT
void mbw_native_window_set_maximized(uint64_t raw_window, int maximized) {
  (void)raw_window;
  (void)maximized;
}
MOONBIT_FFI_EXPORT
void mbw_native_window_set_fullscreen(uint64_t raw_window, int fullscreen) {
  (void)raw_window;
  (void)fullscreen;
}
MOONBIT_FFI_EXPORT
void mbw_native_window_set_visible(uint64_t raw_window, int visible) {
  (void)raw_window;
  (void)visible;
}
MOONBIT_FFI_EXPORT
void mbw_native_window_request_surface_size(uint64_t raw_window, int32_t width,
                                            int32_t height) {
  (void)raw_window;
  (void)width;
  (void)height;
}
MOONBIT_FFI_EXPORT
void mbw_native_window_request_redraw(uint64_t raw_window) {
  (void)raw_window;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_window_present_rgba_pixels(uint64_t raw_window,
                                              int32_t width, int32_t height,
                                              int32_t row_bytes,
                                              const uint8_t *pixels,
                                              int32_t pixels_len) {
  (void)raw_window;
  (void)width;
  (void)height;
  (void)row_bytes;
  (void)pixels;
  (void)pixels_len;
  return 1;
}
MOONBIT_FFI_EXPORT
void mbw_native_install_window_event_callback(void *trampoline,
                                              void *closure) {
  (void)trampoline;
  (void)closure;
}
MOONBIT_FFI_EXPORT
void mbw_native_install_input_event_callback(void *trampoline, void *closure) {
  (void)trampoline;
  (void)closure;
}
MOONBIT_FFI_EXPORT
int32_t mbw_native_backend_tag(uint64_t raw) {
  (void)raw;
  return 0;
}

#endif
