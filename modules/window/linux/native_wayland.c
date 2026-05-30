#ifdef __linux__

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <moonbit.h>
#include <wayland-client.h>
#include "generated/xdg-decoration-client-protocol.h"
#include "generated/xdg-shell-client-protocol.h"

typedef void (*mbw_window_event_trampoline_t)(void *closure,
                                              int32_t kind, int32_t raw_id,
                                              int32_t arg0, int32_t arg1,
                                              int32_t arg2, double argd);
typedef void (*mbw_input_event_trampoline_t)(void *closure,
                                             int32_t raw_id, int32_t kind,
                                             int32_t arg0, int32_t arg1,
                                             int32_t arg2, int64_t argi);

static mbw_window_event_trampoline_t g_window_trampoline = NULL;
static void *g_window_closure = NULL;
static mbw_input_event_trampoline_t g_input_trampoline = NULL;
static void *g_input_closure = NULL;

void mbw_wayland_context_destroy(uint64_t raw_context);

enum {
  MBW_LINUX_EVENT_CLOSE = 1,
  MBW_LINUX_EVENT_DESTROYED = 2,
  MBW_LINUX_EVENT_CONFIGURE = 3,
  MBW_LINUX_EVENT_REDRAW = 5,
  MBW_LINUX_EVENT_FOCUS = 6,
  MBW_LINUX_EVENT_PROXY_WAKE = 7,
  MBW_LINUX_INPUT_POINTER_ENTER = 10,
  MBW_LINUX_INPUT_POINTER_MOVE = 11,
  MBW_LINUX_INPUT_POINTER_LEAVE = 12,
  MBW_LINUX_INPUT_POINTER_DOWN = 13,
  MBW_LINUX_INPUT_POINTER_UP = 14,
  MBW_LINUX_INPUT_WHEEL = 15,
  MBW_LINUX_INPUT_KEY_DOWN = 20,
  MBW_LINUX_INPUT_KEY_UP = 21,
};

enum {
  MBW_WAYLAND_TITLEBAR_HEIGHT = 32,
  MBW_WAYLAND_TITLEBAR_BUTTON_SIZE = 18,
  MBW_WAYLAND_TITLEBAR_BUTTON_SLOT = 28,
  MBW_WAYLAND_TITLEBAR_BUTTON_GAP = 8,
  MBW_WAYLAND_TITLEBAR_BUTTON_TOP = 7,
  MBW_WAYLAND_POINTER_LEFT_BUTTON = 0x110,
};

struct mbw_wayland_window;

typedef struct mbw_wayland_context {
  struct wl_display *display;
  struct wl_registry *registry;
  struct wl_compositor *compositor;
  struct wl_shm *shm;
  struct wl_seat *seat;
  struct wl_pointer *pointer;
  struct wl_keyboard *keyboard;
  struct xdg_wm_base *wm_base;
  struct zxdg_decoration_manager_v1 *decoration_manager;
  struct wl_surface *cursor_surface;
  struct wl_buffer *cursor_buffer;
  void *cursor_data;
  size_t cursor_size;
  int wake_fd;
  struct mbw_wayland_window *pointer_window;
  struct mbw_wayland_window *keyboard_window;
} mbw_wayland_context_t;

typedef struct mbw_wayland_window {
  mbw_wayland_context_t *context;
  int32_t raw_id;
  int32_t width;
  int32_t height;
  int mapped;
  int configured;
  int use_shm_placeholder;
  int pending_placeholder;
  int client_decorated;
  int maximized;
  int requested_maximized;
  int pending_unmaximize;
  int restore_width;
  int restore_height;
  int pointer_x;
  int pointer_y;
  int active_titlebar_button;
  struct wl_surface *surface;
  struct xdg_surface *xdg_surface;
  struct xdg_toplevel *xdg_toplevel;
  struct zxdg_toplevel_decoration_v1 *decoration;
  struct wl_buffer *placeholder_buffer;
  void *placeholder_data;
  size_t placeholder_size;
  int placeholder_width;
  int placeholder_height;
} mbw_wayland_window_t;

static void emit_window(int32_t kind, int32_t raw_id, int32_t arg0,
                        int32_t arg1, int32_t arg2, double argd) {
  if (g_window_trampoline && g_window_closure) {
    g_window_trampoline(g_window_closure, kind, raw_id, arg0, arg1, arg2,
                        argd);
  }
}

static void emit_input(int32_t raw_id, int32_t kind, int32_t arg0,
                       int32_t arg1, int32_t arg2, int64_t argi) {
  if (g_input_trampoline && g_input_closure) {
    g_input_trampoline(g_input_closure, raw_id, kind, arg0, arg1, arg2, argi);
  }
}

static char *copy_bytes(const uint8_t *bytes, int32_t len,
                        const char *fallback) {
  if (!bytes || len <= 0) {
    return strdup(fallback);
  }
  char *out = (char *)malloc((size_t)len + 1);
  if (!out) {
    return NULL;
  }
  memcpy(out, bytes, (size_t)len);
  out[len] = '\0';
  return out;
}

static int create_tmpfile(size_t size) {
  char name[] = "/tmp/moonbit-window-wayland-XXXXXX";
  int fd = mkstemp(name);
  if (fd < 0) {
    return -1;
  }
  unlink(name);
  if (ftruncate(fd, (off_t)size) < 0) {
    close(fd);
    return -1;
  }
  return fd;
}

static void placeholder_release(void *data, struct wl_buffer *buffer) {
  (void)data;
  (void)buffer;
}

static const struct wl_buffer_listener placeholder_buffer_listener = {
    .release = placeholder_release,
};

static void destroy_placeholder_buffer(mbw_wayland_window_t *window) {
  if (!window) {
    return;
  }
  if (window->placeholder_buffer) {
    wl_buffer_destroy(window->placeholder_buffer);
    window->placeholder_buffer = NULL;
  }
  if (window->placeholder_data && window->placeholder_size > 0) {
    munmap(window->placeholder_data, window->placeholder_size);
    window->placeholder_data = NULL;
    window->placeholder_size = 0;
  }
  window->placeholder_width = 0;
  window->placeholder_height = 0;
}

static void put_pixel(uint32_t *pixels, int width, int x, int y,
                      uint32_t color) {
  pixels[(size_t)y * (size_t)width + (size_t)x] = color;
}

static void fill_rect(uint32_t *pixels, int width, int height, int x, int y,
                      int rect_width, int rect_height, uint32_t color) {
  int x0 = x < 0 ? 0 : x;
  int y0 = y < 0 ? 0 : y;
  int x1 = x + rect_width > width ? width : x + rect_width;
  int y1 = y + rect_height > height ? height : y + rect_height;
  for (int row = y0; row < y1; ++row) {
    for (int col = x0; col < x1; ++col) {
      put_pixel(pixels, width, col, row, color);
    }
  }
}

static int titlebar_button_left(int width, int index_from_right) {
  return width - MBW_WAYLAND_TITLEBAR_BUTTON_GAP -
         (index_from_right + 1) * MBW_WAYLAND_TITLEBAR_BUTTON_SLOT -
         index_from_right * MBW_WAYLAND_TITLEBAR_BUTTON_GAP;
}

static int titlebar_hit_button(mbw_wayland_window_t *window, int x, int y) {
  if (!window || !window->client_decorated ||
      y < 0 || y >= MBW_WAYLAND_TITLEBAR_HEIGHT) {
    return 0;
  }
  for (int index = 0; index < 3; ++index) {
    int left = titlebar_button_left(window->width, index);
    if (x >= left && x < left + MBW_WAYLAND_TITLEBAR_BUTTON_SLOT) {
      return index + 1;
    }
  }
  return 0;
}

static int titlebar_hit_drag(mbw_wayland_window_t *window, int x, int y) {
  return window && window->client_decorated && y >= 0 &&
         y < MBW_WAYLAND_TITLEBAR_HEIGHT &&
         titlebar_hit_button(window, x, y) == 0;
}

static void draw_client_titlebar(mbw_wayland_window_t *window,
                                 uint32_t *pixels) {
  if (!window || !window->client_decorated || !pixels) {
    return;
  }
  int width = window->width > 0 ? window->width : 1;
  int height = window->height > 0 ? window->height : 1;
  int titlebar_height = height < MBW_WAYLAND_TITLEBAR_HEIGHT
                            ? height
                            : MBW_WAYLAND_TITLEBAR_HEIGHT;
  fill_rect(pixels, width, height, 0, 0, width, titlebar_height, 0xFF2A2D34u);
  fill_rect(pixels, width, height, 0, titlebar_height - 1, width, 1,
            0xFF555A64u);
  int inset = (MBW_WAYLAND_TITLEBAR_BUTTON_SLOT -
               MBW_WAYLAND_TITLEBAR_BUTTON_SIZE) /
              2;
  int close_left = titlebar_button_left(width, 0) + inset;
  int max_left = titlebar_button_left(width, 1) + inset;
  int min_left = titlebar_button_left(width, 2) + inset;
  fill_rect(pixels, width, height, min_left, MBW_WAYLAND_TITLEBAR_BUTTON_TOP,
            MBW_WAYLAND_TITLEBAR_BUTTON_SIZE,
            MBW_WAYLAND_TITLEBAR_BUTTON_SIZE, 0xFFE5B84Cu);
  fill_rect(pixels, width, height, max_left, MBW_WAYLAND_TITLEBAR_BUTTON_TOP,
            MBW_WAYLAND_TITLEBAR_BUTTON_SIZE,
            MBW_WAYLAND_TITLEBAR_BUTTON_SIZE, 0xFF4FB86Au);
  fill_rect(pixels, width, height, close_left, MBW_WAYLAND_TITLEBAR_BUTTON_TOP,
            MBW_WAYLAND_TITLEBAR_BUTTON_SIZE,
            MBW_WAYLAND_TITLEBAR_BUTTON_SIZE, 0xFFE05A5Au);
  fill_rect(pixels, width, height, 12, 12, width > 150 ? width - 150 : 24, 2,
            0xFFB8C0CCu);
}

static void attach_placeholder_buffer(mbw_wayland_window_t *window) {
  if (!window || !window->context || !window->context->shm) {
    return;
  }
  if (!window->configured) {
    window->pending_placeholder = 1;
    return;
  }
  int width = window->width > 0 ? window->width : 1;
  int height = window->height > 0 ? window->height : 1;
  if (window->placeholder_buffer) {
    if (window->placeholder_width == width && window->placeholder_height == height) {
      return;
    }
    destroy_placeholder_buffer(window);
  }
  int stride = width * 4;
  size_t size = (size_t)stride * (size_t)height;
  int fd = create_tmpfile(size);
  if (fd < 0) {
    return;
  }
  void *data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (data == MAP_FAILED) {
    close(fd);
    return;
  }
  uint32_t *pixels = (uint32_t *)data;
  for (int y = 0; y < height; ++y) {
    for (int x = 0; x < width; ++x) {
      uint8_t shade = (uint8_t)(32 + ((x + y) % 64));
      pixels[(size_t)y * (size_t)width + (size_t)x] =
          0xFF000000u | ((uint32_t)shade << 16) | ((uint32_t)(shade + 24) << 8) |
          (uint32_t)(shade + 48);
    }
  }
  draw_client_titlebar(window, pixels);
  struct wl_shm_pool *pool =
      wl_shm_create_pool(window->context->shm, fd, (int32_t)size);
  if (!pool) {
    munmap(data, size);
    close(fd);
    return;
  }
  window->placeholder_buffer =
      wl_shm_pool_create_buffer(pool, 0, width, height, stride,
                                WL_SHM_FORMAT_XRGB8888);
  wl_shm_pool_destroy(pool);
  close(fd);
  if (!window->placeholder_buffer) {
    munmap(data, size);
    return;
  }
  wl_buffer_add_listener(window->placeholder_buffer,
                         &placeholder_buffer_listener, window);
  window->placeholder_data = data;
  window->placeholder_size = size;
  window->placeholder_width = width;
  window->placeholder_height = height;
  wl_surface_attach(window->surface, window->placeholder_buffer, 0, 0);
  wl_surface_damage_buffer(window->surface, 0, 0, width, height);
  wl_surface_commit(window->surface);
}

static void cursor_release(void *data, struct wl_buffer *buffer) {
  (void)data;
  (void)buffer;
}

static const struct wl_buffer_listener cursor_buffer_listener = {
    .release = cursor_release,
};

static int ensure_default_cursor(mbw_wayland_context_t *context) {
  if (!context || !context->compositor || !context->shm) {
    return 0;
  }
  if (context->cursor_surface && context->cursor_buffer) {
    return 1;
  }
  int width = 24;
  int height = 24;
  int stride = width * 4;
  size_t size = (size_t)stride * (size_t)height;
  int fd = create_tmpfile(size);
  if (fd < 0) {
    return 0;
  }
  void *data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (data == MAP_FAILED) {
    close(fd);
    return 0;
  }
  uint32_t *pixels = (uint32_t *)data;
  memset(pixels, 0, size);
  for (int y = 0; y < height; ++y) {
    for (int x = 0; x <= y / 2 && x < 12; ++x) {
      pixels[(size_t)y * (size_t)width + (size_t)x] = 0xFF101010u;
    }
  }
  for (int y = 2; y < 18; ++y) {
    for (int x = 2; x <= y / 2 && x < 9; ++x) {
      pixels[(size_t)y * (size_t)width + (size_t)x] = 0xFFFFFFFFu;
    }
  }
  fill_rect(pixels, width, height, 8, 14, 3, 8, 0xFF101010u);
  fill_rect(pixels, width, height, 9, 15, 1, 6, 0xFFFFFFFFu);
  struct wl_shm_pool *pool = wl_shm_create_pool(context->shm, fd, (int32_t)size);
  if (!pool) {
    munmap(data, size);
    close(fd);
    return 0;
  }
  struct wl_buffer *buffer =
      wl_shm_pool_create_buffer(pool, 0, width, height, stride,
                                WL_SHM_FORMAT_ARGB8888);
  wl_shm_pool_destroy(pool);
  close(fd);
  if (!buffer) {
    munmap(data, size);
    return 0;
  }
  struct wl_surface *surface = wl_compositor_create_surface(context->compositor);
  if (!surface) {
    wl_buffer_destroy(buffer);
    munmap(data, size);
    return 0;
  }
  wl_buffer_add_listener(buffer, &cursor_buffer_listener, context);
  wl_surface_attach(surface, buffer, 0, 0);
  wl_surface_damage_buffer(surface, 0, 0, width, height);
  wl_surface_commit(surface);
  context->cursor_surface = surface;
  context->cursor_buffer = buffer;
  context->cursor_data = data;
  context->cursor_size = size;
  return 1;
}

static void set_default_cursor(mbw_wayland_context_t *context,
                               struct wl_pointer *pointer, uint32_t serial) {
  if (!context || !pointer || !ensure_default_cursor(context)) {
    return;
  }
  wl_pointer_set_cursor(pointer, serial, context->cursor_surface, 1, 1);
  wl_surface_commit(context->cursor_surface);
}

static void xdg_wm_base_ping(void *data, struct xdg_wm_base *wm_base,
                             uint32_t serial) {
  (void)data;
  xdg_wm_base_pong(wm_base, serial);
}

static const struct xdg_wm_base_listener wm_base_listener = {
    .ping = xdg_wm_base_ping,
};

static void xdg_surface_configure(void *data, struct xdg_surface *surface,
                                  uint32_t serial) {
  mbw_wayland_window_t *window = (mbw_wayland_window_t *)data;
  xdg_surface_ack_configure(surface, serial);
  if (window) {
    window->configured = 1;
    if (window->use_shm_placeholder && window->pending_placeholder) {
      window->pending_placeholder = 0;
      attach_placeholder_buffer(window);
    }
    if (window->use_shm_placeholder) {
      attach_placeholder_buffer(window);
    }
    emit_window(MBW_LINUX_EVENT_CONFIGURE, window->raw_id, window->width,
                window->height, 0, 0.0);
  }
}

static const struct xdg_surface_listener xdg_surface_listener = {
    .configure = xdg_surface_configure,
};

static void xdg_toplevel_configure(void *data,
                                   struct xdg_toplevel *xdg_toplevel,
                                   int32_t width, int32_t height,
                                   struct wl_array *states) {
  (void)xdg_toplevel;
  mbw_wayland_window_t *window = (mbw_wayland_window_t *)data;
  if (!window) {
    return;
  }
  int was_maximized = window->maximized || window->requested_maximized ||
                      window->pending_unmaximize;
  window->maximized = 0;
  if (states) {
    uint32_t *state;
    wl_array_for_each(state, states) {
      if (*state == XDG_TOPLEVEL_STATE_MAXIMIZED) {
        window->maximized = 1;
      }
    }
  }
  window->requested_maximized = window->maximized;
  window->pending_unmaximize = 0;
  if (width > 0) {
    window->width = width;
  } else if (was_maximized && !window->maximized && window->restore_width > 0) {
    window->width = window->restore_width;
  }
  if (height > 0) {
    window->height = height;
  } else if (was_maximized && !window->maximized && window->restore_height > 0) {
    window->height = window->restore_height;
  }
}

static void save_restore_size(mbw_wayland_window_t *window) {
  if (!window || window->maximized || window->requested_maximized) {
    return;
  }
  if (window->width > 0) {
    window->restore_width = window->width;
  }
  if (window->height > 0) {
    window->restore_height = window->height;
  }
}

static void request_maximized(mbw_wayland_window_t *window, int maximized) {
  if (!window || !window->xdg_toplevel) {
    return;
  }
  if (maximized) {
    save_restore_size(window);
    xdg_toplevel_set_maximized(window->xdg_toplevel);
    window->requested_maximized = 1;
    window->maximized = 1;
  } else {
    xdg_toplevel_unset_maximized(window->xdg_toplevel);
    window->requested_maximized = 0;
    window->pending_unmaximize = 1;
    window->maximized = 0;
  }
}

static void xdg_toplevel_close(void *data,
                               struct xdg_toplevel *xdg_toplevel) {
  (void)xdg_toplevel;
  mbw_wayland_window_t *window = (mbw_wayland_window_t *)data;
  if (window) {
    emit_window(MBW_LINUX_EVENT_CLOSE, window->raw_id, 0, 0, 0, 0.0);
  }
}

static const struct xdg_toplevel_listener xdg_toplevel_listener = {
    .configure = xdg_toplevel_configure,
    .close = xdg_toplevel_close,
};

static void decoration_configure(
    void *data, struct zxdg_toplevel_decoration_v1 *decoration,
    uint32_t mode) {
  (void)decoration;
  mbw_wayland_window_t *window = (mbw_wayland_window_t *)data;
  if (window) {
    int was_client_decorated = window->client_decorated;
    window->client_decorated =
        mode == ZXDG_TOPLEVEL_DECORATION_V1_MODE_CLIENT_SIDE ? 1 : 0;
    if (was_client_decorated != window->client_decorated &&
        window->use_shm_placeholder) {
      destroy_placeholder_buffer(window);
      attach_placeholder_buffer(window);
    }
    if (was_client_decorated != window->client_decorated) {
      emit_window(MBW_LINUX_EVENT_CONFIGURE, window->raw_id, window->width,
                  window->height, 0, 0.0);
    }
  }
}

static const struct zxdg_toplevel_decoration_v1_listener decoration_listener = {
    .configure = decoration_configure,
};

static void pointer_enter(void *data, struct wl_pointer *pointer,
                          uint32_t serial, struct wl_surface *surface,
                          wl_fixed_t sx, wl_fixed_t sy) {
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context) {
    return;
  }
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)wl_surface_get_user_data(surface);
  context->pointer_window = window;
  set_default_cursor(context, pointer, serial);
  if (window) {
    window->pointer_x = wl_fixed_to_int(sx);
    window->pointer_y = wl_fixed_to_int(sy);
    emit_input(window->raw_id, MBW_LINUX_INPUT_POINTER_ENTER,
               wl_fixed_to_int(sx), wl_fixed_to_int(sy), 0, 0);
  }
}

static void pointer_leave(void *data, struct wl_pointer *pointer,
                          uint32_t serial, struct wl_surface *surface) {
  (void)pointer;
  (void)serial;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context) {
    return;
  }
  mbw_wayland_window_t *window =
      surface ? (mbw_wayland_window_t *)wl_surface_get_user_data(surface)
              : context->pointer_window;
  if (window) {
    emit_input(window->raw_id, MBW_LINUX_INPUT_POINTER_LEAVE, 0, 0, 0, 0);
  }
  if (context) {
    context->pointer_window = NULL;
  }
}

static void pointer_motion(void *data, struct wl_pointer *pointer,
                           uint32_t time, wl_fixed_t sx, wl_fixed_t sy) {
  (void)pointer;
  (void)time;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  mbw_wayland_window_t *window = context ? context->pointer_window : NULL;
  if (window) {
    window->pointer_x = wl_fixed_to_int(sx);
    window->pointer_y = wl_fixed_to_int(sy);
    emit_input(window->raw_id, MBW_LINUX_INPUT_POINTER_MOVE, wl_fixed_to_int(sx),
               wl_fixed_to_int(sy), 0, 0);
  }
}

static void pointer_button(void *data, struct wl_pointer *pointer,
                           uint32_t serial, uint32_t time, uint32_t button,
                           uint32_t state) {
  (void)pointer;
  (void)time;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  mbw_wayland_window_t *window = context ? context->pointer_window : NULL;
  if (window) {
    if (button == MBW_WAYLAND_POINTER_LEFT_BUTTON) {
      if (state != WL_POINTER_BUTTON_STATE_PRESSED) {
        if (window->active_titlebar_button != 0) {
          window->active_titlebar_button = 0;
          return;
        }
      } else {
        window->active_titlebar_button =
            titlebar_hit_button(window, window->pointer_x, window->pointer_y);
      }
      int titlebar_button = window->active_titlebar_button;
      if (titlebar_button == 1) {
        emit_window(MBW_LINUX_EVENT_CLOSE, window->raw_id, 0, 0, 0, 0.0);
        return;
      } else if (titlebar_button == 2 && window->xdg_toplevel) {
        request_maximized(window, !(window->requested_maximized || window->maximized));
        wl_surface_commit(window->surface);
        if (context && context->display) {
          wl_display_flush(context->display);
        }
        return;
      } else if (titlebar_button == 3 && window->xdg_toplevel) {
        xdg_toplevel_set_minimized(window->xdg_toplevel);
        wl_surface_commit(window->surface);
        if (context && context->display) {
          wl_display_flush(context->display);
        }
        return;
      } else if (titlebar_hit_drag(window, window->pointer_x,
                                   window->pointer_y) &&
                 window->xdg_toplevel && context && context->seat) {
        xdg_toplevel_move(window->xdg_toplevel, context->seat, serial);
        return;
      }
    }
    emit_input(window->raw_id,
               state == WL_POINTER_BUTTON_STATE_PRESSED
                   ? MBW_LINUX_INPUT_POINTER_DOWN
                   : MBW_LINUX_INPUT_POINTER_UP,
               0, 0, (int32_t)button, 0);
  }
}

static void pointer_axis(void *data, struct wl_pointer *pointer,
                         uint32_t time, uint32_t axis, wl_fixed_t value) {
  (void)pointer;
  (void)time;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  mbw_wayland_window_t *window = context ? context->pointer_window : NULL;
  if (!window) {
    return;
  }
  int delta = wl_fixed_to_int(value);
  if (axis == WL_POINTER_AXIS_HORIZONTAL_SCROLL) {
    emit_input(window->raw_id, MBW_LINUX_INPUT_WHEEL, delta, 0, 0, 0);
  } else {
    emit_input(window->raw_id, MBW_LINUX_INPUT_WHEEL, 0, delta, 0, 0);
  }
}

static void pointer_frame(void *data, struct wl_pointer *pointer) {
  (void)data;
  (void)pointer;
}

static void pointer_axis_source(void *data, struct wl_pointer *pointer,
                                uint32_t axis_source) {
  (void)data;
  (void)pointer;
  (void)axis_source;
}

static void pointer_axis_stop(void *data, struct wl_pointer *pointer,
                              uint32_t time, uint32_t axis) {
  (void)data;
  (void)pointer;
  (void)time;
  (void)axis;
}

static void pointer_axis_discrete(void *data, struct wl_pointer *pointer,
                                  uint32_t axis, int32_t discrete) {
  (void)data;
  (void)pointer;
  (void)axis;
  (void)discrete;
}

static const struct wl_pointer_listener pointer_listener = {
    .enter = pointer_enter,
    .leave = pointer_leave,
    .motion = pointer_motion,
    .button = pointer_button,
    .axis = pointer_axis,
    .frame = pointer_frame,
    .axis_source = pointer_axis_source,
    .axis_stop = pointer_axis_stop,
    .axis_discrete = pointer_axis_discrete,
};

static void keyboard_keymap(void *data, struct wl_keyboard *keyboard,
                            uint32_t format, int32_t fd, uint32_t size) {
  (void)data;
  (void)keyboard;
  (void)format;
  (void)size;
  if (fd >= 0) {
    close(fd);
  }
}

static void keyboard_enter(void *data, struct wl_keyboard *keyboard,
                           uint32_t serial, struct wl_surface *surface,
                           struct wl_array *keys) {
  (void)keyboard;
  (void)serial;
  (void)keys;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)wl_surface_get_user_data(surface);
  if (context) {
    context->keyboard_window = window;
  }
  if (window) {
    emit_window(MBW_LINUX_EVENT_FOCUS, window->raw_id, 1, 0, 0, 0.0);
  }
}

static void keyboard_leave(void *data, struct wl_keyboard *keyboard,
                           uint32_t serial, struct wl_surface *surface) {
  (void)keyboard;
  (void)serial;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  mbw_wayland_window_t *window =
      surface ? (mbw_wayland_window_t *)wl_surface_get_user_data(surface)
              : context->keyboard_window;
  if (window) {
    emit_window(MBW_LINUX_EVENT_FOCUS, window->raw_id, 0, 0, 0, 0.0);
  }
  if (context) {
    context->keyboard_window = NULL;
  }
}

static void keyboard_key(void *data, struct wl_keyboard *keyboard,
                         uint32_t serial, uint32_t time, uint32_t key,
                         uint32_t state) {
  (void)keyboard;
  (void)serial;
  (void)time;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  mbw_wayland_window_t *window = context ? context->keyboard_window : NULL;
  if (window) {
    emit_input(window->raw_id,
               state == WL_KEYBOARD_KEY_STATE_PRESSED
                   ? MBW_LINUX_INPUT_KEY_DOWN
                   : MBW_LINUX_INPUT_KEY_UP,
               0, 0, 0, (int64_t)key);
  }
}

static void keyboard_modifiers(void *data, struct wl_keyboard *keyboard,
                               uint32_t serial, uint32_t mods_depressed,
                               uint32_t mods_latched, uint32_t mods_locked,
                               uint32_t group) {
  (void)data;
  (void)keyboard;
  (void)serial;
  (void)mods_depressed;
  (void)mods_latched;
  (void)mods_locked;
  (void)group;
}

static void keyboard_repeat_info(void *data, struct wl_keyboard *keyboard,
                                 int32_t rate, int32_t delay) {
  (void)data;
  (void)keyboard;
  (void)rate;
  (void)delay;
}

static const struct wl_keyboard_listener keyboard_listener = {
    .keymap = keyboard_keymap,
    .enter = keyboard_enter,
    .leave = keyboard_leave,
    .key = keyboard_key,
    .modifiers = keyboard_modifiers,
    .repeat_info = keyboard_repeat_info,
};

static void seat_capabilities(void *data, struct wl_seat *seat,
                              uint32_t capabilities) {
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context) {
    return;
  }
  if ((capabilities & WL_SEAT_CAPABILITY_POINTER) && !context->pointer) {
    context->pointer = wl_seat_get_pointer(seat);
    wl_pointer_add_listener(context->pointer, &pointer_listener, context);
  } else if (!(capabilities & WL_SEAT_CAPABILITY_POINTER) &&
             context->pointer) {
    wl_pointer_destroy(context->pointer);
    context->pointer = NULL;
  }
  if ((capabilities & WL_SEAT_CAPABILITY_KEYBOARD) && !context->keyboard) {
    context->keyboard = wl_seat_get_keyboard(seat);
    wl_keyboard_add_listener(context->keyboard, &keyboard_listener, context);
  } else if (!(capabilities & WL_SEAT_CAPABILITY_KEYBOARD) &&
             context->keyboard) {
    wl_keyboard_destroy(context->keyboard);
    context->keyboard = NULL;
  }
}

static void seat_name(void *data, struct wl_seat *seat, const char *name) {
  (void)data;
  (void)seat;
  (void)name;
}

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_capabilities,
    .name = seat_name,
};

static void registry_global(void *data, struct wl_registry *registry,
                            uint32_t name, const char *interface,
                            uint32_t version) {
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (strcmp(interface, wl_compositor_interface.name) == 0) {
    context->compositor =
        wl_registry_bind(registry, name, &wl_compositor_interface,
                         version < 4 ? version : 4);
  } else if (strcmp(interface, wl_shm_interface.name) == 0) {
    context->shm =
        wl_registry_bind(registry, name, &wl_shm_interface,
                         version < 1 ? version : 1);
  } else if (strcmp(interface, wl_seat_interface.name) == 0) {
    context->seat =
        wl_registry_bind(registry, name, &wl_seat_interface,
                         version < 5 ? version : 5);
    wl_seat_add_listener(context->seat, &seat_listener, context);
  } else if (strcmp(interface, xdg_wm_base_interface.name) == 0) {
    context->wm_base =
        wl_registry_bind(registry, name, &xdg_wm_base_interface, 1);
    xdg_wm_base_add_listener(context->wm_base, &wm_base_listener, context);
  } else if (strcmp(interface, zxdg_decoration_manager_v1_interface.name) ==
             0) {
    context->decoration_manager = wl_registry_bind(
        registry, name, &zxdg_decoration_manager_v1_interface, 1);
  }
}

static void registry_global_remove(void *data, struct wl_registry *registry,
                                   uint32_t name) {
  (void)data;
  (void)registry;
  (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_context_new(void) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)calloc(1, sizeof(mbw_wayland_context_t));
  if (!context) {
    return 0;
  }
  context->display = wl_display_connect(NULL);
  if (!context->display) {
    free(context);
    return 0;
  }
  context->wake_fd = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
  context->registry = wl_display_get_registry(context->display);
  wl_registry_add_listener(context->registry, &registry_listener, context);
  wl_display_roundtrip(context->display);
  wl_display_roundtrip(context->display);
  if (!context->compositor || !context->wm_base) {
    mbw_wayland_context_destroy((uint64_t)(uintptr_t)context);
    return 0;
  }
  return (uint64_t)(uintptr_t)context;
}

MOONBIT_FFI_EXPORT
void mbw_wayland_context_destroy(uint64_t raw_context) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  if (!context) {
    return;
  }
  if (context->keyboard) {
    wl_keyboard_destroy(context->keyboard);
  }
  if (context->pointer) {
    wl_pointer_destroy(context->pointer);
  }
  if (context->cursor_buffer) {
    wl_buffer_destroy(context->cursor_buffer);
  }
  if (context->cursor_data && context->cursor_size > 0) {
    munmap(context->cursor_data, context->cursor_size);
  }
  if (context->cursor_surface) {
    wl_surface_destroy(context->cursor_surface);
  }
  if (context->seat) {
    wl_seat_destroy(context->seat);
  }
  if (context->decoration_manager) {
    zxdg_decoration_manager_v1_destroy(context->decoration_manager);
  }
  if (context->wm_base) {
    xdg_wm_base_destroy(context->wm_base);
  }
  if (context->shm) {
    wl_shm_destroy(context->shm);
  }
  if (context->compositor) {
    wl_compositor_destroy(context->compositor);
  }
  if (context->registry) {
    wl_registry_destroy(context->registry);
  }
  if (context->display) {
    wl_display_disconnect(context->display);
  }
  if (context->wake_fd >= 0) {
    close(context->wake_fd);
  }
  free(context);
}

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_context_display_handle(uint64_t raw_context) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  return context ? (uint64_t)(uintptr_t)context->display : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_wake_fd(uint64_t raw_context) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  return context ? context->wake_fd : -1;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_system_theme(uint64_t raw_context) {
  (void)raw_context;
  return -1;
}

MOONBIT_FFI_EXPORT
int64_t mbw_wayland_now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + (int64_t)ts.tv_nsec / 1000000;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_dispatch(uint64_t raw_context, int32_t timeout_ms) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  if (!context || !context->display) {
    return -1;
  }
  if (timeout_ms == 0) {
    int ret = wl_display_dispatch_pending(context->display);
    if (ret < 0) {
      fprintf(stderr, "Wayland dispatch pending failed: errno=%d error=%d\n",
              errno, wl_display_get_error(context->display));
    }
    wl_display_flush(context->display);
    return ret;
  }
  int fd = wl_display_get_fd(context->display);
  struct pollfd fds[2];
  fds[0].fd = fd;
  fds[0].events = POLLIN;
  fds[0].revents = 0;
  fds[1].fd = context->wake_fd;
  fds[1].events = POLLIN;
  fds[1].revents = 0;
  wl_display_flush(context->display);
  int ret = poll(fds, context->wake_fd >= 0 ? 2 : 1, timeout_ms);
  if (ret < 0) {
    return errno == EINTR ? 0 : -1;
  }
  if (context->wake_fd >= 0 && (fds[1].revents & POLLIN)) {
    uint64_t value = 0;
    ssize_t bytes_read = read(context->wake_fd, &value, sizeof(value));
    (void)bytes_read;
    emit_window(MBW_LINUX_EVENT_PROXY_WAKE, 0, 0, 0, 0, 0.0);
  }
  if (fds[0].revents & POLLIN) {
    int dispatch_ret = wl_display_dispatch(context->display);
    if (dispatch_ret < 0) {
      fprintf(stderr, "Wayland dispatch failed: errno=%d error=%d\n", errno,
              wl_display_get_error(context->display));
    }
    return dispatch_ret;
  }
  int pending_ret = wl_display_dispatch_pending(context->display);
  if (pending_ret < 0) {
    fprintf(stderr, "Wayland dispatch pending failed: errno=%d error=%d\n",
            errno, wl_display_get_error(context->display));
  }
  return pending_ret;
}

MOONBIT_FFI_EXPORT
void mbw_wayland_context_wake(uint64_t raw_context) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  if (!context || context->wake_fd < 0) {
    return;
  }
  uint64_t value = 1;
  ssize_t bytes_written = write(context->wake_fd, &value, sizeof(value));
  (void)bytes_written;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_create(uint64_t raw_context, int32_t raw_id,
                                   int32_t width, int32_t height,
                                   const uint8_t *title, int32_t title_len,
                                   const uint8_t *app_id, int32_t app_id_len,
                                   int decorations,
                                   int use_shm_placeholder) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  if (!context || !context->compositor || !context->wm_base) {
    return 0;
  }
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)calloc(1, sizeof(mbw_wayland_window_t));
  if (!window) {
    return 0;
  }
  window->context = context;
  window->raw_id = raw_id;
  window->width = width > 0 ? width : 1;
  window->height = height > 0 ? height : 1;
  window->restore_width = window->width;
  window->restore_height = window->height;
  window->use_shm_placeholder = use_shm_placeholder ? 1 : 0;
  window->client_decorated =
      decorations && !context->decoration_manager && use_shm_placeholder ? 1
                                                                         : 0;
  window->surface = wl_compositor_create_surface(context->compositor);
  if (!window->surface) {
    free(window);
    return 0;
  }
  wl_surface_set_user_data(window->surface, window);
  window->xdg_surface =
      xdg_wm_base_get_xdg_surface(context->wm_base, window->surface);
  window->xdg_toplevel = xdg_surface_get_toplevel(window->xdg_surface);
  xdg_surface_add_listener(window->xdg_surface, &xdg_surface_listener, window);
  xdg_toplevel_add_listener(window->xdg_toplevel, &xdg_toplevel_listener,
                            window);
  char *title_c = copy_bytes(title, title_len, "MoonBit window");
  char *app_id_c = copy_bytes(app_id, app_id_len, "Milky2018.window");
  if (title_c) {
    xdg_toplevel_set_title(window->xdg_toplevel, title_c);
    free(title_c);
  }
  if (app_id_c) {
    xdg_toplevel_set_app_id(window->xdg_toplevel, app_id_c);
    free(app_id_c);
  }
  if (context->decoration_manager && decorations) {
    window->decoration =
        zxdg_decoration_manager_v1_get_toplevel_decoration(
            context->decoration_manager, window->xdg_toplevel);
    if (window->decoration) {
      zxdg_toplevel_decoration_v1_add_listener(window->decoration,
                                               &decoration_listener, window);
      zxdg_toplevel_decoration_v1_set_mode(
          window->decoration,
          ZXDG_TOPLEVEL_DECORATION_V1_MODE_SERVER_SIDE);
    }
  }
  wl_surface_commit(window->surface);
  if (use_shm_placeholder) {
    attach_placeholder_buffer(window);
  }
  wl_display_flush(context->display);
  return (uint64_t)(uintptr_t)window;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_window_wait_configured(uint64_t raw_window,
                                           int32_t timeout_ms) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window || !window->context || !window->context->display) {
    return 0;
  }
  if (window->configured) {
    return 1;
  }
  int64_t start = mbw_wayland_now_ms();
  while (!window->configured) {
    if (timeout_ms >= 0 && mbw_wayland_now_ms() - start >= timeout_ms) {
      return 0;
    }
    int ret = mbw_wayland_context_dispatch(
        (uint64_t)(uintptr_t)window->context, 100);
    if (ret < 0) {
      return 0;
    }
  }
  return 1;
}

MOONBIT_FFI_EXPORT
void mbw_wayland_window_destroy(uint64_t raw_window) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window) {
    return;
  }
  emit_window(MBW_LINUX_EVENT_DESTROYED, window->raw_id, 0, 0, 0, 0.0);
  destroy_placeholder_buffer(window);
  if (window->decoration) {
    zxdg_toplevel_decoration_v1_destroy(window->decoration);
  }
  if (window->xdg_toplevel) {
    xdg_toplevel_destroy(window->xdg_toplevel);
  }
  if (window->xdg_surface) {
    xdg_surface_destroy(window->xdg_surface);
  }
  if (window->surface) {
    wl_surface_destroy(window->surface);
  }
  free(window);
}

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_surface_handle(uint64_t raw_window) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  return window ? (uint64_t)(uintptr_t)window->surface : 0;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_xdg_surface_handle(uint64_t raw_window) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  return window ? (uint64_t)(uintptr_t)window->xdg_surface : 0;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_xdg_toplevel_handle(uint64_t raw_window) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  return window ? (uint64_t)(uintptr_t)window->xdg_toplevel : 0;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_display_handle(uint64_t raw_window) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  return window && window->context
             ? (uint64_t)(uintptr_t)window->context->display
             : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_window_client_decorated(uint64_t raw_window) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  return window ? window->client_decorated : 0;
}

MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_title(uint64_t raw_window, const uint8_t *title,
                                  int32_t title_len) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window || !window->xdg_toplevel) {
    return;
  }
  char *title_c = copy_bytes(title, title_len, "");
  if (!title_c) {
    return;
  }
  xdg_toplevel_set_title(window->xdg_toplevel, title_c);
  free(title_c);
  wl_surface_commit(window->surface);
}

MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_decorations(uint64_t raw_window, int decorations) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window || !window->context || !window->xdg_toplevel) {
    return;
  }
  if (!window->context->decoration_manager) {
    return;
  }
  if (!window->decoration) {
    window->decoration =
        zxdg_decoration_manager_v1_get_toplevel_decoration(
            window->context->decoration_manager, window->xdg_toplevel);
    if (!window->decoration) {
      return;
    }
    zxdg_toplevel_decoration_v1_add_listener(window->decoration,
                                             &decoration_listener, window);
  }
  zxdg_toplevel_decoration_v1_set_mode(
      window->decoration,
      decorations ? ZXDG_TOPLEVEL_DECORATION_V1_MODE_SERVER_SIDE
                  : ZXDG_TOPLEVEL_DECORATION_V1_MODE_CLIENT_SIDE);
  wl_surface_commit(window->surface);
}

MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_minimized(uint64_t raw_window, int minimized) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window || !window->xdg_toplevel || !minimized) {
    return;
  }
  xdg_toplevel_set_minimized(window->xdg_toplevel);
  wl_surface_commit(window->surface);
}

MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_maximized(uint64_t raw_window, int maximized) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window || !window->xdg_toplevel) {
    return;
  }
  if (maximized) {
    request_maximized(window, 1);
  } else {
    request_maximized(window, 0);
  }
  wl_surface_commit(window->surface);
}

MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_visible(uint64_t raw_window, int visible) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window || !visible) {
    return;
  }
  attach_placeholder_buffer(window);
}

MOONBIT_FFI_EXPORT
void mbw_wayland_window_request_surface_size(uint64_t raw_window, int32_t width,
                                             int32_t height) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window) {
    return;
  }
  window->width = width > 0 ? width : 1;
  window->height = height > 0 ? height : 1;
  attach_placeholder_buffer(window);
}

MOONBIT_FFI_EXPORT
void mbw_wayland_window_request_redraw(uint64_t raw_window) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (window && window->context) {
    mbw_wayland_context_wake((uint64_t)(uintptr_t)window->context);
  }
}

MOONBIT_FFI_EXPORT
void mbw_wayland_install_window_event_callback(
    mbw_window_event_trampoline_t trampoline,
    void *closure) {
  g_window_trampoline = trampoline;
  g_window_closure = closure;
}

MOONBIT_FFI_EXPORT
void mbw_wayland_install_input_event_callback(
    mbw_input_event_trampoline_t trampoline,
    void *closure) {
  g_input_trampoline = trampoline;
  g_input_closure = closure;
}

#else

#include <moonbit.h>
#include <stdint.h>

typedef void (*mbw_window_event_trampoline_t)(void *closure,
                                              int32_t kind, int32_t raw_id,
                                              int32_t arg0, int32_t arg1,
                                              int32_t arg2, double argd);
typedef void (*mbw_input_event_trampoline_t)(void *closure,
                                             int32_t raw_id, int32_t kind,
                                             int32_t arg0, int32_t arg1,
                                             int32_t arg2, int64_t argi);

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_context_new(void) { return 0; }
MOONBIT_FFI_EXPORT
void mbw_wayland_context_destroy(uint64_t raw_context) { (void)raw_context; }
MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_context_display_handle(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_wake_fd(uint64_t raw_context) {
  (void)raw_context;
  return -1;
}
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_system_theme(uint64_t raw_context) {
  (void)raw_context;
  return -1;
}
MOONBIT_FFI_EXPORT
int64_t mbw_wayland_now_ms(void) { return 0; }
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_dispatch(uint64_t raw_context, int32_t timeout_ms) {
  (void)raw_context;
  (void)timeout_ms;
  return -1;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_context_wake(uint64_t raw_context) { (void)raw_context; }
MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_create(uint64_t raw_context, int32_t raw_id,
                                   int32_t width, int32_t height,
                                   const uint8_t *title, int32_t title_len,
                                   const uint8_t *app_id, int32_t app_id_len,
                                   int decorations,
                                   int use_shm_placeholder) {
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
int32_t mbw_wayland_window_wait_configured(uint64_t raw_window,
                                           int32_t timeout_ms) {
  (void)raw_window;
  (void)timeout_ms;
  return 0;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_window_destroy(uint64_t raw_window) { (void)raw_window; }
MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_surface_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_xdg_surface_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_xdg_toplevel_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_display_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_window_client_decorated(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_title(uint64_t raw_window, const uint8_t *title,
                                  int32_t title_len) {
  (void)raw_window;
  (void)title;
  (void)title_len;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_decorations(uint64_t raw_window, int decorations) {
  (void)raw_window;
  (void)decorations;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_minimized(uint64_t raw_window, int minimized) {
  (void)raw_window;
  (void)minimized;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_maximized(uint64_t raw_window, int maximized) {
  (void)raw_window;
  (void)maximized;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_window_set_visible(uint64_t raw_window, int visible) {
  (void)raw_window;
  (void)visible;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_window_request_surface_size(uint64_t raw_window, int32_t width,
                                             int32_t height) {
  (void)raw_window;
  (void)width;
  (void)height;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_window_request_redraw(uint64_t raw_window) {
  (void)raw_window;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_install_window_event_callback(
    mbw_window_event_trampoline_t trampoline,
    void *closure) {
  (void)trampoline;
  (void)closure;
}
MOONBIT_FFI_EXPORT
void mbw_wayland_install_input_event_callback(
    mbw_input_event_trampoline_t trampoline,
    void *closure) {
  (void)trampoline;
  (void)closure;
}

#endif
