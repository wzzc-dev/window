#include <stdlib.h>
#include "native_harmonyos_host.h"
#include <string.h>
#ifndef MBW_HARMONYOS_HOST_QUEUE_CAP
#define MBW_HARMONYOS_HOST_QUEUE_CAP 256
#endif
static mbw_harmonyos_host_event g_queue[MBW_HARMONYOS_HOST_QUEUE_CAP];
static int32_t g_head = 0;
static int32_t g_tail = 0;
static void enqueue(mbw_harmonyos_host_event event) {
  int32_t next = (g_tail + 1) % MBW_HARMONYOS_HOST_QUEUE_CAP;
  if (next == g_head) g_head = (g_head + 1) % MBW_HARMONYOS_HOST_QUEUE_CAP;
  g_queue[g_tail] = event;
  g_tail = next;
}
static mbw_harmonyos_host_event simple(int32_t kind) {
  mbw_harmonyos_host_event event; memset(&event, 0, sizeof(event)); event.kind = kind; return event;
}
void mbw_harmonyos_host_queue_reset(void) { g_head = 0; g_tail = 0; }
int32_t mbw_harmonyos_host_poll_raw(uint64_t *handle_out, uint64_t *token_out, int32_t *width_out, int32_t *height_out, int32_t *pressed_out, int32_t *codepoint_out, double *scale_out, double *x_out, double *y_out) {
  if (g_head == g_tail) return 0;
  mbw_harmonyos_host_event event = g_queue[g_head];
  g_head = (g_head + 1) % MBW_HARMONYOS_HOST_QUEUE_CAP;
  if (handle_out) *handle_out = event.handle;
  if (token_out) *token_out = event.token;
  if (width_out) *width_out = event.width;
  if (height_out) *height_out = event.height;
  if (pressed_out) *pressed_out = event.pressed;
  if (codepoint_out) *codepoint_out = event.codepoint;
  if (scale_out) *scale_out = event.scale;
  if (x_out) *x_out = event.x;
  if (y_out) *y_out = event.y;
  return event.kind;
}
void mbw_harmonyos_host_on_start(void) { enqueue(simple(MBW_HARMONYOS_HOST_START)); }
void mbw_harmonyos_host_on_resume(void) { enqueue(simple(MBW_HARMONYOS_HOST_RESUME)); }
void mbw_harmonyos_host_on_pause(void) { enqueue(simple(MBW_HARMONYOS_HOST_PAUSE)); }
void mbw_harmonyos_host_on_stop(void) { enqueue(simple(MBW_HARMONYOS_HOST_STOP)); }
void mbw_harmonyos_host_on_destroy(void) { enqueue(simple(MBW_HARMONYOS_HOST_DESTROY)); }
void mbw_harmonyos_host_on_memory_warning(void) { enqueue(simple(MBW_HARMONYOS_HOST_MEMORY_WARNING)); }
void mbw_harmonyos_host_on_surface_init(uint64_t handle, uint64_t token, int32_t width, int32_t height, double scale) {
  mbw_harmonyos_host_event event = simple(MBW_HARMONYOS_HOST_SURFACE_INIT);
  event.handle = handle; event.token = token; event.width = width; event.height = height; event.scale = scale;
  enqueue(event);
}
void mbw_harmonyos_host_on_surface_term(void) { enqueue(simple(MBW_HARMONYOS_HOST_SURFACE_TERM)); }
void mbw_harmonyos_host_on_surface_resize(int32_t width, int32_t height, double scale) {
  mbw_harmonyos_host_event event = simple(MBW_HARMONYOS_HOST_SURFACE_RESIZE);
  event.width = width; event.height = height; event.scale = scale; enqueue(event);
}
void mbw_harmonyos_host_on_pointer_moved(double x, double y) {
  mbw_harmonyos_host_event event = simple(MBW_HARMONYOS_HOST_POINTER_MOVED); event.x = x; event.y = y; enqueue(event);
}
void mbw_harmonyos_host_on_pointer_button(int32_t pressed, double x, double y) {
  mbw_harmonyos_host_event event = simple(MBW_HARMONYOS_HOST_POINTER_BUTTON); event.pressed = pressed; event.x = x; event.y = y; enqueue(event);
}
void mbw_harmonyos_host_on_keyboard_codepoint(int32_t codepoint) {
  mbw_harmonyos_host_event event = simple(MBW_HARMONYOS_HOST_KEYBOARD_CODEPOINT); event.codepoint = codepoint; enqueue(event);
}

int32_t mbw_harmonyos_window_present_rgba_pixels(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    int32_t stride_bytes,
    const uint8_t *pixels,
    int32_t pixel_len) {
  (void)window_handle;
  (void)width;
  (void)height;
  (void)stride_bytes;
  (void)pixels;
  (void)pixel_len;
  /* Device metal/egl present lands with full UIView/XComponent ownership. */
  return window_handle == 0 ? -10 : 0;
}

int32_t mbw_harmonyos_window_clear_color(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a) {
  (void)width; (void)height; (void)r; (void)g; (void)b; (void)a;
  return window_handle == 0 ? -10 : 0;
}

#include <unistd.h>
void mbw_harmonyos_sleep_ms(int32_t ms) {
  if (ms <= 0) {
    return;
  }
  usleep((useconds_t)ms * 1000u);
}
