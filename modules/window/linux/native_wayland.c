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
  MBW_LINUX_INPUT_DRAG_ENTER = 30,
  MBW_LINUX_INPUT_DRAG_MOVE = 31,
  MBW_LINUX_INPUT_DRAG_DROP = 32,
  MBW_LINUX_INPUT_DRAG_LEAVE = 33,
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

typedef struct mbw_wayland_data_offer {
  struct wl_data_offer *offer;
  int has_text;
  int has_uri_list;
} mbw_wayland_data_offer_t;

typedef struct mbw_wayland_output {
  uint32_t registry_name;
  struct wl_output *output;
  int32_t x;
  int32_t y;
  int32_t width;
  int32_t height;
  int32_t scale;
  char name[256];
  struct mbw_wayland_output *next;
} mbw_wayland_output_t;

typedef struct mbw_wayland_present_buffer {
  struct mbw_wayland_window *window;
  struct wl_buffer *buffer;
  void *data;
  size_t size;
  struct mbw_wayland_present_buffer *next;
} mbw_wayland_present_buffer_t;

typedef struct mbw_wayland_context {
  struct wl_display *display;
  struct wl_registry *registry;
  struct wl_compositor *compositor;
  struct wl_shm *shm;
  struct wl_seat *seat;
  struct wl_pointer *pointer;
  struct wl_keyboard *keyboard;
  struct wl_data_device_manager *data_device_manager;
  struct wl_data_device *data_device;
  mbw_wayland_data_offer_t *selection_offer;
  mbw_wayland_data_offer_t *drag_offer;
  struct xdg_wm_base *wm_base;
  struct zxdg_decoration_manager_v1 *decoration_manager;
  mbw_wayland_output_t *outputs;
  struct mbw_wayland_window *windows;
  struct wl_surface *cursor_surface;
  struct wl_buffer *cursor_buffer;
  void *cursor_data;
  size_t cursor_size;
  int wake_fd;
  struct mbw_wayland_window *pointer_window;
  struct mbw_wayland_window *keyboard_window;
  struct mbw_wayland_window *drag_window;
  struct wl_data_source *selection_source;
  char *selection_text;
  size_t selection_text_len;
  uint32_t last_serial;
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
  int resizing;
  // Pending pointer events buffered between wl_pointer.frame callbacks.
  // Wayland delivers motion/button/axis as a stream terminated by a frame
  // event; emitting each sub-event immediately causes the MoonBit runtime to
  // be re-entered many times per physical input, which is the primary source
  // of click/scroll jank on Linux. Buffer them and flush in pointer_frame.
  int pending_pointer_move;       // boolean: a motion event is buffered
  int pending_move_x;
  int pending_move_y;
  int pending_pointer_button;     // boolean: a button event is buffered
  int pending_button_state;       // 0=up, 1=down
  int pending_button_code;        // raw Wayland button code
  int pending_wheel;              // boolean: a wheel event is buffered
  double pending_wheel_dx;        // accumulated horizontal pixel delta
  double pending_wheel_dy;        // accumulated vertical pixel delta (+up)
  struct wl_output *current_output;
  struct wl_surface *surface;
  struct xdg_surface *xdg_surface;
  struct xdg_toplevel *xdg_toplevel;
  struct zxdg_toplevel_decoration_v1 *decoration;
  struct wl_buffer *placeholder_buffer;
  void *placeholder_data;
  size_t placeholder_size;
  int placeholder_width;
  int placeholder_height;
  char *pending_drag_paths;
  mbw_wayland_present_buffer_t *present_buffers;
  struct mbw_wayland_window *next;
} mbw_wayland_window_t;

static mbw_wayland_window_t *window_from_raw(uint64_t raw_window) {
  if (raw_window < 4096) {
    return NULL;
  }
  return (mbw_wayland_window_t *)(uintptr_t)raw_window;
}

enum {
  MBW_WAYLAND_PRESENT_OK = 0,
  MBW_WAYLAND_PRESENT_BAD_WINDOW = 1,
  MBW_WAYLAND_PRESENT_BAD_DIMENSIONS = 2,
  MBW_WAYLAND_PRESENT_BAD_PIXELS = 3,
  MBW_WAYLAND_PRESENT_ALLOC_FAILED = 4,
};

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

static moonbit_bytes_t bytes_from_string(const char *text) {
  if (!text || !text[0]) {
    return moonbit_make_bytes(0, 0);
  }
  int32_t len = (int32_t)strlen(text);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, text, (size_t)len);
  return bytes;
}

static int mime_is_text(const char *mime_type) {
  return mime_type &&
         (strcmp(mime_type, "text/plain;charset=utf-8") == 0 ||
          strcmp(mime_type, "text/plain") == 0 ||
          strcmp(mime_type, "UTF8_STRING") == 0);
}

static int mime_is_uri_list(const char *mime_type) {
  return mime_type && strcmp(mime_type, "text/uri-list") == 0;
}

static void free_data_offer(mbw_wayland_data_offer_t *offer) {
  if (!offer) {
    return;
  }
  if (offer->offer) {
    wl_data_offer_destroy(offer->offer);
    offer->offer = NULL;
  }
  free(offer);
}

static char *read_fd_to_string(int fd, int timeout_ms) {
  if (fd < 0) {
    return NULL;
  }
  size_t capacity = 4096;
  size_t length = 0;
  char *buffer = (char *)malloc(capacity);
  if (!buffer) {
    close(fd);
    return NULL;
  }
  int elapsed = 0;
  while (1) {
    struct pollfd pfd = {.fd = fd, .events = POLLIN | POLLHUP, .revents = 0};
    int wait_ms = timeout_ms < 0 ? -1 : timeout_ms - elapsed;
    if (wait_ms < 0) {
      wait_ms = 0;
    }
    int ret = poll(&pfd, 1, wait_ms);
    if (ret < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    if (ret == 0) {
      break;
    }
    if (pfd.revents & POLLIN) {
      char chunk[2048];
      ssize_t count = read(fd, chunk, sizeof(chunk));
      if (count > 0) {
        if (length + (size_t)count + 1 > capacity) {
          size_t next_capacity = capacity * 2;
          while (length + (size_t)count + 1 > next_capacity) {
            next_capacity *= 2;
          }
          char *next = (char *)realloc(buffer, next_capacity);
          if (!next) {
            free(buffer);
            close(fd);
            return NULL;
          }
          buffer = next;
          capacity = next_capacity;
        }
        memcpy(buffer + length, chunk, (size_t)count);
        length += (size_t)count;
        continue;
      }
      if (count == 0) {
        break;
      }
      if (errno == EINTR || errno == EAGAIN) {
        continue;
      }
      break;
    }
    if (pfd.revents & (POLLHUP | POLLERR | POLLNVAL)) {
      char chunk[2048];
      ssize_t count = read(fd, chunk, sizeof(chunk));
      if (count > 0) {
        if (length + (size_t)count + 1 > capacity) {
          char *next = (char *)realloc(buffer, length + (size_t)count + 1);
          if (!next) {
            free(buffer);
            close(fd);
            return NULL;
          }
          buffer = next;
          capacity = length + (size_t)count + 1;
        }
        memcpy(buffer + length, chunk, (size_t)count);
        length += (size_t)count;
      }
      break;
    }
    if (timeout_ms >= 0) {
      elapsed += wait_ms;
      if (elapsed >= timeout_ms) {
        break;
      }
    }
  }
  close(fd);
  buffer[length] = '\0';
  return buffer;
}

static void flush_wayland_display(struct wl_display *display,
                                  const char *reason) {
  (void)reason;
  if (!display) {
    return;
  }
  int ret = wl_display_flush(display);
  if (ret < 0 && errno == EAGAIN) {
    struct pollfd pfd = {
        .fd = wl_display_get_fd(display), .events = POLLOUT, .revents = 0};
    if (poll(&pfd, 1, -1) > 0) {
      (void)wl_display_flush(display);
    }
  }
}

static char *read_data_offer_text(mbw_wayland_context_t *context,
                                  mbw_wayland_data_offer_t *offer,
                                  const char *mime_type) {
  if (!context || !context->display || !offer || !offer->offer || !mime_type) {
    return NULL;
  }
  int fds[2];
  if (pipe(fds) != 0) {
    return NULL;
  }
  wl_data_offer_receive(offer->offer, mime_type, fds[1]);
  close(fds[1]);
  (void)flush_wayland_display(context->display, "data offer receive");
  return read_fd_to_string(fds[0], 750);
}

static int hex_digit(char c) {
  if (c >= '0' && c <= '9') {
    return c - '0';
  }
  if (c >= 'a' && c <= 'f') {
    return 10 + c - 'a';
  }
  if (c >= 'A' && c <= 'F') {
    return 10 + c - 'A';
  }
  return -1;
}

static char *decode_file_uri_line(const char *line, size_t len) {
  const char *prefix = "file://";
  size_t prefix_len = strlen(prefix);
  if (!line || len < prefix_len || strncmp(line, prefix, prefix_len) != 0) {
    return NULL;
  }
  const char *cursor = line + prefix_len;
  size_t remaining = len - prefix_len;
  if (remaining >= 10 && strncmp(cursor, "localhost/", 10) == 0) {
    cursor += 9;
    remaining -= 9;
  } else if (remaining > 0 && cursor[0] != '/') {
    const char *slash = memchr(cursor, '/', remaining);
    if (!slash) {
      return NULL;
    }
    remaining -= (size_t)(slash - cursor);
    cursor = slash;
  }
  char *out = (char *)malloc(remaining + 1);
  if (!out) {
    return NULL;
  }
  size_t out_len = 0;
  for (size_t i = 0; i < remaining; ++i) {
    if (cursor[i] == '%' && i + 2 < remaining) {
      int hi = hex_digit(cursor[i + 1]);
      int lo = hex_digit(cursor[i + 2]);
      if (hi >= 0 && lo >= 0) {
        out[out_len++] = (char)((hi << 4) | lo);
        i += 2;
        continue;
      }
    }
    out[out_len++] = cursor[i];
  }
  out[out_len] = '\0';
  return out;
}

static char *uri_list_to_paths(const char *uri_list) {
  if (!uri_list || !uri_list[0]) {
    return strdup("");
  }
  size_t capacity = strlen(uri_list) + 1;
  char *paths = (char *)malloc(capacity);
  if (!paths) {
    return NULL;
  }
  size_t paths_len = 0;
  const char *line = uri_list;
  while (*line) {
    const char *end = strpbrk(line, "\r\n");
    size_t len = end ? (size_t)(end - line) : strlen(line);
    if (len > 0 && line[0] != '#') {
      char *path = decode_file_uri_line(line, len);
      if (path && path[0]) {
        size_t path_len = strlen(path);
        if (paths_len + path_len + 2 > capacity) {
          size_t next_capacity = capacity * 2 + path_len + 2;
          char *next = (char *)realloc(paths, next_capacity);
          if (!next) {
            free(path);
            free(paths);
            return NULL;
          }
          paths = next;
          capacity = next_capacity;
        }
        if (paths_len > 0) {
          paths[paths_len++] = '\n';
        }
        memcpy(paths + paths_len, path, path_len);
        paths_len += path_len;
      }
      free(path);
    }
    if (!end) {
      break;
    }
    line = end + 1;
    if (*end == '\r' && *line == '\n') {
      line++;
    }
  }
  paths[paths_len] = '\0';
  return paths;
}

static void window_store_drag_paths(mbw_wayland_window_t *window,
                                    const char *paths) {
  if (!window) {
    return;
  }
  free(window->pending_drag_paths);
  window->pending_drag_paths = paths ? strdup(paths) : strdup("");
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

static void unlink_present_buffer(mbw_wayland_present_buffer_t *frame) {
  if (!frame || !frame->window) {
    return;
  }
  mbw_wayland_present_buffer_t **cursor = &frame->window->present_buffers;
  while (*cursor) {
    if (*cursor == frame) {
      *cursor = frame->next;
      break;
    }
    cursor = &(*cursor)->next;
  }
  frame->window = NULL;
  frame->next = NULL;
}

static void destroy_present_buffer(mbw_wayland_present_buffer_t *frame) {
  if (!frame) {
    return;
  }
  if (frame->buffer) {
    wl_buffer_destroy(frame->buffer);
    frame->buffer = NULL;
  }
  if (frame->data && frame->size > 0) {
    munmap(frame->data, frame->size);
    frame->data = NULL;
    frame->size = 0;
  }
  free(frame);
}

static void present_buffer_release(void *data, struct wl_buffer *buffer) {
  (void)buffer;
  mbw_wayland_present_buffer_t *frame =
      (mbw_wayland_present_buffer_t *)data;
  unlink_present_buffer(frame);
  destroy_present_buffer(frame);
}

static const struct wl_buffer_listener present_buffer_listener = {
    .release = present_buffer_release,
};

static void destroy_present_buffers(mbw_wayland_window_t *window) {
  if (!window) {
    return;
  }
  mbw_wayland_present_buffer_t *frame = window->present_buffers;
  window->present_buffers = NULL;
  while (frame) {
    mbw_wayland_present_buffer_t *next = frame->next;
    frame->window = NULL;
    frame->next = NULL;
    destroy_present_buffer(frame);
    frame = next;
  }
}

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

static void destroy_window_resources(mbw_wayland_window_t *window) {
  if (!window) {
    return;
  }
  destroy_present_buffers(window);
  destroy_placeholder_buffer(window);
  if (window->decoration) {
    zxdg_toplevel_decoration_v1_destroy(window->decoration);
    window->decoration = NULL;
  }
  if (window->xdg_toplevel) {
    xdg_toplevel_destroy(window->xdg_toplevel);
    window->xdg_toplevel = NULL;
  }
  if (window->xdg_surface) {
    xdg_surface_destroy(window->xdg_surface);
    window->xdg_surface = NULL;
  }
  if (window->surface) {
    wl_surface_destroy(window->surface);
    window->surface = NULL;
  }
  free(window->pending_drag_paths);
  window->pending_drag_paths = NULL;
  free(window);
}

static void detach_window_from_context(mbw_wayland_window_t *window) {
  if (!window || !window->context) {
    return;
  }
  if (window->context->pointer_window == window) {
    window->context->pointer_window = NULL;
  }
  if (window->context->keyboard_window == window) {
    window->context->keyboard_window = NULL;
  }
  mbw_wayland_window_t **cursor = &window->context->windows;
  while (*cursor) {
    if (*cursor == window) {
      *cursor = window->next;
      break;
    }
    cursor = &(*cursor)->next;
  }
  window->next = NULL;
}

static void destroy_context_windows(mbw_wayland_context_t *context) {
  if (!context) {
    return;
  }
  context->pointer_window = NULL;
  context->keyboard_window = NULL;
  mbw_wayland_window_t *window = context->windows;
  context->windows = NULL;
  while (window) {
    mbw_wayland_window_t *next = window->next;
    window->next = NULL;
    destroy_window_resources(window);
    window = next;
  }
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

static void data_offer_offer(void *data, struct wl_data_offer *offer,
                             const char *mime_type) {
  (void)offer;
  mbw_wayland_data_offer_t *wrapped = (mbw_wayland_data_offer_t *)data;
  if (!wrapped || !mime_type) {
    return;
  }
  if (mime_is_text(mime_type)) {
    wrapped->has_text = 1;
  } else if (mime_is_uri_list(mime_type)) {
    wrapped->has_uri_list = 1;
  }
}

static void data_offer_source_actions(void *data,
                                      struct wl_data_offer *offer,
                                      uint32_t source_actions) {
  (void)data;
  (void)offer;
  (void)source_actions;
}

static void data_offer_action(void *data, struct wl_data_offer *offer,
                              uint32_t dnd_action) {
  (void)data;
  (void)offer;
  (void)dnd_action;
}

static const struct wl_data_offer_listener data_offer_listener = {
    .offer = data_offer_offer,
    .source_actions = data_offer_source_actions,
    .action = data_offer_action,
};

static void data_source_target(void *data, struct wl_data_source *source,
                               const char *mime_type) {
  (void)data;
  (void)source;
  (void)mime_type;
}

static void data_source_send(void *data, struct wl_data_source *source,
                             const char *mime_type, int32_t fd) {
  (void)source;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context || !mime_is_text(mime_type) || fd < 0) {
    if (fd >= 0) {
      close(fd);
    }
    return;
  }
  size_t written = 0;
  while (written < context->selection_text_len) {
    ssize_t result = write(fd, context->selection_text + written,
                           context->selection_text_len - written);
    if (result > 0) {
      written += (size_t)result;
    } else if (result < 0 && errno == EINTR) {
      continue;
    } else {
      break;
    }
  }
  close(fd);
}

static void data_source_cancelled(void *data, struct wl_data_source *source) {
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (context && context->selection_source == source) {
    context->selection_source = NULL;
  }
  if (source) {
    wl_data_source_destroy(source);
  }
}

static void data_source_dnd_drop_performed(void *data,
                                           struct wl_data_source *source) {
  (void)data;
  (void)source;
}

static void data_source_dnd_finished(void *data,
                                     struct wl_data_source *source) {
  (void)data;
  (void)source;
}

static void data_source_action(void *data, struct wl_data_source *source,
                               uint32_t dnd_action) {
  (void)data;
  (void)source;
  (void)dnd_action;
}

static const struct wl_data_source_listener data_source_listener = {
    .target = data_source_target,
    .send = data_source_send,
    .cancelled = data_source_cancelled,
    .dnd_drop_performed = data_source_dnd_drop_performed,
    .dnd_finished = data_source_dnd_finished,
    .action = data_source_action,
};

static char *read_drag_paths(mbw_wayland_context_t *context,
                             mbw_wayland_data_offer_t *offer) {
  if (!offer || !offer->has_uri_list) {
    return strdup("");
  }
  char *uri_list = read_data_offer_text(context, offer, "text/uri-list");
  if (!uri_list) {
    return strdup("");
  }
  char *paths = uri_list_to_paths(uri_list);
  free(uri_list);
  return paths ? paths : strdup("");
}

static void data_device_data_offer(void *data,
                                   struct wl_data_device *data_device,
                                   struct wl_data_offer *offer) {
  (void)data_device;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context || !offer) {
    return;
  }
  mbw_wayland_data_offer_t *wrapped =
      (mbw_wayland_data_offer_t *)calloc(1, sizeof(*wrapped));
  if (!wrapped) {
    wl_data_offer_destroy(offer);
    return;
  }
  wrapped->offer = offer;
  wl_data_offer_add_listener(offer, &data_offer_listener, wrapped);
}

static void data_device_enter(void *data, struct wl_data_device *data_device,
                              uint32_t serial, struct wl_surface *surface,
                              wl_fixed_t x, wl_fixed_t y,
                              struct wl_data_offer *offer) {
  (void)data_device;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context) {
    return;
  }
  context->last_serial = serial;
  context->drag_window =
      surface ? (mbw_wayland_window_t *)wl_surface_get_user_data(surface)
              : NULL;
  context->drag_offer =
      offer ? (mbw_wayland_data_offer_t *)wl_data_offer_get_user_data(offer)
            : NULL;
  if (context->drag_window) {
    char *paths = read_drag_paths(context, context->drag_offer);
    window_store_drag_paths(context->drag_window, paths);
    free(paths);
    emit_input(context->drag_window->raw_id, MBW_LINUX_INPUT_DRAG_ENTER,
               wl_fixed_to_int(x), wl_fixed_to_int(y), 0, 0);
  }
}

static void data_device_leave(void *data, struct wl_data_device *data_device) {
  (void)data_device;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context) {
    return;
  }
  if (context->drag_window) {
    emit_input(context->drag_window->raw_id, MBW_LINUX_INPUT_DRAG_LEAVE,
               context->drag_window->pointer_x, context->drag_window->pointer_y,
               0, 0);
  }
  context->drag_window = NULL;
  context->drag_offer = NULL;
}

static void data_device_motion(void *data, struct wl_data_device *data_device,
                               uint32_t time, wl_fixed_t x, wl_fixed_t y) {
  (void)data_device;
  (void)time;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (context && context->drag_window) {
    context->drag_window->pointer_x = wl_fixed_to_int(x);
    context->drag_window->pointer_y = wl_fixed_to_int(y);
    emit_input(context->drag_window->raw_id, MBW_LINUX_INPUT_DRAG_MOVE,
               wl_fixed_to_int(x), wl_fixed_to_int(y), 0, 0);
  }
}

static void data_device_drop(void *data, struct wl_data_device *data_device) {
  (void)data_device;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context || !context->drag_window) {
    return;
  }
  char *paths = read_drag_paths(context, context->drag_offer);
  window_store_drag_paths(context->drag_window, paths);
  free(paths);
  emit_input(context->drag_window->raw_id, MBW_LINUX_INPUT_DRAG_DROP,
             context->drag_window->pointer_x, context->drag_window->pointer_y,
             0, 0);
}

static void data_device_selection(void *data,
                                  struct wl_data_device *data_device,
                                  struct wl_data_offer *offer) {
  (void)data_device;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context) {
    return;
  }
  if (context->selection_offer &&
      (!offer || context->selection_offer->offer != offer)) {
    free_data_offer(context->selection_offer);
  }
  context->selection_offer =
      offer ? (mbw_wayland_data_offer_t *)wl_data_offer_get_user_data(offer)
            : NULL;
}

static const struct wl_data_device_listener data_device_listener = {
    .data_offer = data_device_data_offer,
    .enter = data_device_enter,
    .leave = data_device_leave,
    .motion = data_device_motion,
    .drop = data_device_drop,
    .selection = data_device_selection,
};

static void ensure_data_device(mbw_wayland_context_t *context) {
  if (!context || context->data_device || !context->data_device_manager ||
      !context->seat) {
    return;
  }
  context->data_device =
      wl_data_device_manager_get_data_device(context->data_device_manager,
                                             context->seat);
  if (context->data_device) {
    wl_data_device_add_listener(context->data_device, &data_device_listener,
                                context);
  }
}

static void pointer_enter(void *data, struct wl_pointer *pointer,
                          uint32_t serial, struct wl_surface *surface,
                          wl_fixed_t sx, wl_fixed_t sy) {
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (!context) {
    return;
  }
  context->last_serial = serial;
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
    // Buffer until the next wl_pointer.frame; emitting per-motion re-enters
    // the MoonBit runtime many times per physical pointer movement.
    window->pending_pointer_move = 1;
    window->pending_move_x = window->pointer_x;
    window->pending_move_y = window->pointer_y;
  }
}

static void pointer_button(void *data, struct wl_pointer *pointer,
                           uint32_t serial, uint32_t time, uint32_t button,
                           uint32_t state) {
  (void)pointer;
  (void)time;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (context) {
    context->last_serial = serial;
  }
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
    // Buffer until the next wl_pointer.frame; emitting per-button re-enters
    // the MoonBit runtime for every sub-event of a logical click.
    window->pending_pointer_button = 1;
    window->pending_button_state =
        state == WL_POINTER_BUTTON_STATE_PRESSED ? 1 : 0;
    window->pending_button_code = (int32_t)button;
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
  // Buffer until the next wl_pointer.frame. Wayland delivers axis as a 24.8
  // fixed-point pixel delta. The host (event.mbt) feeds this directly into
  // MouseScrollDelta::PixelDelta, so we must preserve the pixel magnitude —
  // do NOT scale to 1/120-notch units (that inflates scroll ~47x). Use
  // wl_fixed_to_double to keep sub-pixel precision on touchpads instead of
  // the old wl_fixed_to_int which truncated it.
  double delta_px = wl_fixed_to_double(value);
  window->pending_wheel = 1;
  if (axis == WL_POINTER_AXIS_HORIZONTAL_SCROLL) {
    // Horizontal: keep Wayland sign convention (positive = right).
    window->pending_wheel_dx += delta_px;
  } else {
    // Vertical: Wayland reports positive for downward scroll; the window
    // library convention (shared with Windows/macOS) is positive for
    // upward, so invert.
    window->pending_wheel_dy += -delta_px;
  }
}

static void pointer_frame(void *data, struct wl_pointer *pointer) {
  (void)pointer;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  mbw_wayland_window_t *window = context ? context->pointer_window : NULL;
  if (!window) {
    return;
  }
  // Flush all buffered sub-events in one pass. Order matters: motion first
  // (update pointer position), then button, then wheel — this matches the
  // Wayland protocol's per-frame delivery order and lets the MoonBit runtime
  // process a complete logical input event without re-entry.
  if (window->pending_pointer_move) {
    emit_input(window->raw_id, MBW_LINUX_INPUT_POINTER_MOVE,
               window->pending_move_x, window->pending_move_y, 0, 0);
    window->pending_pointer_move = 0;
  }
  if (window->pending_pointer_button) {
    emit_input(window->raw_id,
               window->pending_button_state ? MBW_LINUX_INPUT_POINTER_DOWN
                                            : MBW_LINUX_INPUT_POINTER_UP,
               window->pointer_x, window->pointer_y,
               window->pending_button_code, 0);
    window->pending_pointer_button = 0;
    window->pending_button_state = 0;
    window->pending_button_code = 0;
  }
  if (window->pending_wheel) {
    // emit_input takes int32 args; truncate the accumulated double pixel
    // delta. Sub-pixel remainder is intentionally dropped here (the host
    // treats MouseWheel as integer PixelDelta anyway).
    emit_input(window->raw_id, MBW_LINUX_INPUT_WHEEL,
               (int32_t)window->pending_wheel_dx,
               (int32_t)window->pending_wheel_dy, 0, 0);
    window->pending_wheel = 0;
    window->pending_wheel_dx = 0;
    window->pending_wheel_dy = 0;
  }
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
  (void)keys;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)wl_surface_get_user_data(surface);
  if (context) {
    context->last_serial = serial;
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
  (void)time;
  mbw_wayland_context_t *context = (mbw_wayland_context_t *)data;
  if (context) {
    context->last_serial = serial;
  }
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
  ensure_data_device(context);
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

static void output_geometry(void *data, struct wl_output *output, int32_t x,
                            int32_t y, int32_t physical_width,
                            int32_t physical_height, int32_t subpixel,
                            const char *make, const char *model,
                            int32_t transform) {
  (void)output;
  (void)physical_width;
  (void)physical_height;
  (void)subpixel;
  (void)make;
  (void)model;
  (void)transform;
  mbw_wayland_output_t *out = (mbw_wayland_output_t *)data;
  out->x = x;
  out->y = y;
}

static void output_mode(void *data, struct wl_output *output, uint32_t flags,
                        int32_t width, int32_t height, int32_t refresh) {
  (void)output;
  (void)refresh;
  mbw_wayland_output_t *out = (mbw_wayland_output_t *)data;
  if (flags & WL_OUTPUT_MODE_CURRENT) {
    out->width = width;
    out->height = height;
  }
}

static void output_done(void *data, struct wl_output *output) {
  (void)data;
  (void)output;
}

static void output_scale(void *data, struct wl_output *output,
                         int32_t factor) {
  (void)output;
  mbw_wayland_output_t *out = (mbw_wayland_output_t *)data;
  out->scale = factor;
}

static const struct wl_output_listener output_listener = {
    .geometry = output_geometry,
    .mode = output_mode,
    .done = output_done,
    .scale = output_scale,
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
  } else if (strcmp(interface, wl_output_interface.name) == 0) {
    mbw_wayland_output_t *output =
        (mbw_wayland_output_t *)calloc(1, sizeof(mbw_wayland_output_t));
    if (!output) {
      return;
    }
    output->registry_name = name;
    output->scale = 1;
    snprintf(output->name, sizeof(output->name), "Wayland output %u", name);
    output->output = wl_registry_bind(registry, name, &wl_output_interface,
                                      version < 2 ? version : 2);
    if (!output->output) {
      free(output);
      return;
    }
    wl_output_add_listener(output->output, &output_listener, output);
    output->next = context->outputs;
    context->outputs = output;
  } else if (strcmp(interface, wl_data_device_manager_interface.name) == 0) {
    context->data_device_manager =
        wl_registry_bind(registry, name, &wl_data_device_manager_interface,
                         version < 3 ? version : 3);
    ensure_data_device(context);
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
  if (context->selection_source) {
    wl_data_source_destroy(context->selection_source);
    context->selection_source = NULL;
  }
  mbw_wayland_data_offer_t *destroyed_selection_offer = context->selection_offer;
  if (destroyed_selection_offer) {
    free_data_offer(destroyed_selection_offer);
    context->selection_offer = NULL;
  }
  if (context->drag_offer && context->drag_offer != destroyed_selection_offer) {
    free_data_offer(context->drag_offer);
    context->drag_offer = NULL;
  }
  if (context->data_device) {
    wl_data_device_destroy(context->data_device);
    context->data_device = NULL;
  }
  if (context->data_device_manager) {
    wl_data_device_manager_destroy(context->data_device_manager);
    context->data_device_manager = NULL;
  }
  free(context->selection_text);
  context->selection_text = NULL;
  context->selection_text_len = 0;
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

static mbw_wayland_output_t *output_at(mbw_wayland_context_t *context,
                                       int32_t index) {
  if (!context || index < 0) {
    return NULL;
  }
  mbw_wayland_output_t *output = context->outputs;
  int32_t i = 0;
  while (output) {
    if (i == index) {
      return output;
    }
    i++;
    output = output->next;
  }
  return NULL;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_monitor_count(uint64_t raw_context) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  int32_t count = 0;
  mbw_wayland_output_t *output = context ? context->outputs : NULL;
  while (output) {
    count++;
    output = output->next;
  }
  return count;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_monitor_handle_at(uint64_t raw_context, int32_t index) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  mbw_wayland_output_t *output = output_at(context, index);
  return output ? (uint64_t)(uintptr_t)output->output : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_monitor_rect_left_at(uint64_t raw_context, int32_t index) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  mbw_wayland_output_t *output = output_at(context, index);
  return output ? output->x : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_monitor_rect_top_at(uint64_t raw_context, int32_t index) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  mbw_wayland_output_t *output = output_at(context, index);
  return output ? output->y : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_monitor_rect_width_at(uint64_t raw_context, int32_t index) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  mbw_wayland_output_t *output = output_at(context, index);
  return output && output->width > 0 ? output->width : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_monitor_rect_height_at(uint64_t raw_context, int32_t index) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  mbw_wayland_output_t *output = output_at(context, index);
  return output && output->height > 0 ? output->height : 0;
}

MOONBIT_FFI_EXPORT
double mbw_wayland_monitor_scale_factor_at(uint64_t raw_context,
                                           int32_t index) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  mbw_wayland_output_t *output = output_at(context, index);
  return output && output->scale > 0 ? (double)output->scale : 1.0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_wayland_monitor_name_bytes_at(uint64_t raw_context,
                                                  int32_t index) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  mbw_wayland_output_t *output = output_at(context, index);
  if (!output || !output->name[0]) {
    return moonbit_make_bytes(0, 0);
  }
  int32_t len = (int32_t)strlen(output->name);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, output->name, (size_t)len);
  return bytes;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_current_monitor_handle(uint64_t raw_window) {
  mbw_wayland_window_t *window = window_from_raw(raw_window);
  return window && window->current_output
             ? (uint64_t)(uintptr_t)window->current_output
             : 0;
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
  destroy_present_buffers(window);
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
void mbw_wayland_window_set_fullscreen(uint64_t raw_window, int fullscreen) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window || !window->xdg_toplevel) {
    return;
  }
  if (fullscreen) {
    save_restore_size(window);
    xdg_toplevel_set_fullscreen(window->xdg_toplevel, NULL);
  } else {
    xdg_toplevel_unset_fullscreen(window->xdg_toplevel);
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
  mbw_wayland_window_t *window = window_from_raw(raw_window);
  if (window && window->context) {
    mbw_wayland_context_wake((uint64_t)(uintptr_t)window->context);
  }
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_window_present_rgba_pixels(uint64_t raw_window,
                                               int32_t width,
                                               int32_t height,
                                               int32_t row_bytes,
                                               const uint8_t *pixels,
                                               int32_t pixels_len) {
  mbw_wayland_window_t *window =
      (mbw_wayland_window_t *)(uintptr_t)raw_window;
  if (!window || !window->context || !window->context->shm ||
      !window->surface) {
    return MBW_WAYLAND_PRESENT_BAD_WINDOW;
  }
  if (width <= 0 || height <= 0 || width > INT32_MAX / 4) {
    return MBW_WAYLAND_PRESENT_BAD_DIMENSIONS;
  }
  int32_t packed_row_bytes = width * 4;
  if (row_bytes < packed_row_bytes || height > INT32_MAX / packed_row_bytes) {
    return MBW_WAYLAND_PRESENT_BAD_DIMENSIONS;
  }
  int64_t required_len = (int64_t)row_bytes * (int64_t)height;
  if (!pixels || required_len <= 0 || required_len > INT32_MAX ||
      pixels_len < required_len) {
    return MBW_WAYLAND_PRESENT_BAD_PIXELS;
  }
  size_t size = (size_t)packed_row_bytes * (size_t)height;
  mbw_wayland_present_buffer_t *frame =
      (mbw_wayland_present_buffer_t *)calloc(1, sizeof(*frame));
  if (!frame) {
    return MBW_WAYLAND_PRESENT_ALLOC_FAILED;
  }
  int fd = create_tmpfile(size);
  if (fd < 0) {
    free(frame);
    return MBW_WAYLAND_PRESENT_ALLOC_FAILED;
  }
  void *data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (data == MAP_FAILED) {
    close(fd);
    free(frame);
    return MBW_WAYLAND_PRESENT_ALLOC_FAILED;
  }
  uint8_t *dst_base = (uint8_t *)data;
  for (int32_t y = 0; y < height; ++y) {
    const uint8_t *src = pixels + (size_t)y * (size_t)row_bytes;
    uint8_t *dst = dst_base + (size_t)y * (size_t)packed_row_bytes;
    for (int32_t x = 0; x < width; ++x) {
      size_t offset = (size_t)x * 4;
      dst[offset] = src[offset + 2];
      dst[offset + 1] = src[offset + 1];
      dst[offset + 2] = src[offset];
      dst[offset + 3] = src[offset + 3];
    }
  }
  struct wl_shm_pool *pool =
      wl_shm_create_pool(window->context->shm, fd, (int32_t)size);
  if (!pool) {
    munmap(data, size);
    close(fd);
    free(frame);
    return MBW_WAYLAND_PRESENT_ALLOC_FAILED;
  }
  frame->buffer = wl_shm_pool_create_buffer(pool, 0, width, height,
                                            packed_row_bytes,
                                            WL_SHM_FORMAT_ARGB8888);
  wl_shm_pool_destroy(pool);
  close(fd);
  if (!frame->buffer) {
    munmap(data, size);
    free(frame);
    return MBW_WAYLAND_PRESENT_ALLOC_FAILED;
  }
  frame->window = window;
  frame->data = data;
  frame->size = size;
  frame->next = window->present_buffers;
  window->present_buffers = frame;
  wl_buffer_add_listener(frame->buffer, &present_buffer_listener, frame);
  wl_surface_attach(window->surface, frame->buffer, 0, 0);
  wl_surface_damage_buffer(window->surface, 0, 0, width, height);
  wl_surface_commit(window->surface);
  if (window->context->display) {
    wl_display_flush(window->context->display);
  }
  return MBW_WAYLAND_PRESENT_OK;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_clipboard_available(uint64_t raw_context) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  return context && context->data_device_manager && context->data_device ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_wayland_context_clipboard_read_text(uint64_t raw_context) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  if (!context) {
    return moonbit_make_bytes(0, 0);
  }
  if (context->selection_offer && context->selection_offer->has_text) {
    char *text = read_data_offer_text(context, context->selection_offer,
                                      "text/plain;charset=utf-8");
    if (!text) {
      text = read_data_offer_text(context, context->selection_offer,
                                  "text/plain");
    }
    if (text) {
      moonbit_bytes_t bytes = bytes_from_string(text);
      free(text);
      return bytes;
    }
  }
  if (context->selection_text && context->selection_text_len > 0) {
    moonbit_bytes_t bytes =
        moonbit_make_bytes((int32_t)context->selection_text_len, 0);
    memcpy(bytes, context->selection_text, context->selection_text_len);
    return bytes;
  }
  return moonbit_make_bytes(0, 0);
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_clipboard_write_text(uint64_t raw_context,
                                                 const uint8_t *text,
                                                 int32_t text_len) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  if (!context || !context->data_device_manager || !context->data_device) {
    return 0;
  }
  char *copy = copy_bytes(text, text_len, "");
  if (!copy) {
    return 0;
  }
  struct wl_data_source *source =
      wl_data_device_manager_create_data_source(context->data_device_manager);
  if (!source) {
    free(copy);
    return 0;
  }
  if (context->selection_source) {
    wl_data_source_destroy(context->selection_source);
    context->selection_source = NULL;
  }
  free(context->selection_text);
  context->selection_text = copy;
  context->selection_text_len = strlen(copy);
  context->selection_source = source;
  wl_data_source_add_listener(source, &data_source_listener, context);
  wl_data_source_offer(source, "text/plain;charset=utf-8");
  wl_data_source_offer(source, "text/plain");
  wl_data_device_set_selection(context->data_device, source,
                               context->last_serial);
  if (context->display) {
    (void)flush_wayland_display(context->display, "clipboard set selection");
  }
  return 1;
}

MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_drag_drop_available(uint64_t raw_context) {
  mbw_wayland_context_t *context =
      (mbw_wayland_context_t *)(uintptr_t)raw_context;
  return context && context->data_device_manager && context->data_device ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_wayland_window_take_drag_paths(uint64_t raw_window) {
  mbw_wayland_window_t *window = window_from_raw(raw_window);
  if (!window || !window->pending_drag_paths) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t bytes = bytes_from_string(window->pending_drag_paths);
  free(window->pending_drag_paths);
  window->pending_drag_paths = NULL;
  return bytes;
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
int32_t mbw_wayland_monitor_count(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_monitor_handle_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_monitor_rect_left_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_monitor_rect_top_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_monitor_rect_width_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_monitor_rect_height_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
double mbw_wayland_monitor_scale_factor_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 1.0;
}
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_wayland_monitor_name_bytes_at(uint64_t raw_context,
                                                  int32_t index) {
  (void)raw_context;
  (void)index;
  return moonbit_make_bytes(0, 0);
}
MOONBIT_FFI_EXPORT
uint64_t mbw_wayland_window_current_monitor_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
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
void mbw_wayland_window_set_fullscreen(uint64_t raw_window, int fullscreen) {
  (void)raw_window;
  (void)fullscreen;
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
int32_t mbw_wayland_window_present_rgba_pixels(uint64_t raw_window,
                                               int32_t width,
                                               int32_t height,
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
int32_t mbw_wayland_context_clipboard_available(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_wayland_context_clipboard_read_text(uint64_t raw_context) {
  (void)raw_context;
  return moonbit_make_bytes(0, 0);
}
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_clipboard_write_text(uint64_t raw_context,
                                                 const uint8_t *text,
                                                 int32_t text_len) {
  (void)raw_context;
  (void)text;
  (void)text_len;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_wayland_context_drag_drop_available(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_wayland_window_take_drag_paths(uint64_t raw_window) {
  (void)raw_window;
  return moonbit_make_bytes(0, 0);
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
