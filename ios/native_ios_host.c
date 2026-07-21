#include <stdlib.h>
#include "native_ios_host.h"
#include <string.h>
#if defined(__MOONBIT__) || 1
#import <moonbit.h>
#endif
#ifndef MBW_IOS_HOST_QUEUE_CAP
#define MBW_IOS_HOST_QUEUE_CAP 256
#endif
static mbw_ios_host_event g_queue[MBW_IOS_HOST_QUEUE_CAP];
static int32_t g_head = 0;
static int32_t g_tail = 0;

// Snapshot of the most recently polled IME event text. MoonBit polls every
// host event in one tight loop; the wrapper is expected to call
// mbw_ios_host_take_pending_ime_text() immediately after seeing kind == 15.
static char g_pending_ime_text[MBW_IOS_HOST_TEXT_CAP];
static int32_t g_pending_ime_text_len = 0;

static void enqueue(mbw_ios_host_event event) {
  int32_t next = (g_tail + 1) % MBW_IOS_HOST_QUEUE_CAP;
  if (next == g_head) {
    g_head = (g_head + 1) % MBW_IOS_HOST_QUEUE_CAP;
  }
  g_queue[g_tail] = event;
  g_tail = next;
}
static mbw_ios_host_event simple(int32_t kind) {
  mbw_ios_host_event event; memset(&event, 0, sizeof(event)); event.kind = kind; return event;
}
void mbw_ios_host_queue_reset(void) {
  g_head = 0;
  g_tail = 0;
  g_pending_ime_text_len = 0;
  g_pending_ime_text[0] = '\0';
}
int32_t mbw_ios_host_poll_raw(uint64_t *handle_out, uint64_t *token_out, int32_t *width_out, int32_t *height_out, int32_t *pressed_out, int32_t *codepoint_out, double *scale_out, double *x_out, double *y_out, int32_t *phase_out, int32_t *ime_kind_out, int32_t *ime_start_out, int32_t *ime_end_out, double *dx_out, double *dy_out) {
  if (g_head == g_tail) return 0;
  mbw_ios_host_event event = g_queue[g_head];
  g_head = (g_head + 1) % MBW_IOS_HOST_QUEUE_CAP;
  if (handle_out) *handle_out = event.handle;
  if (token_out) *token_out = event.token;
  if (width_out) *width_out = event.width;
  if (height_out) *height_out = event.height;
  if (pressed_out) *pressed_out = event.pressed;
  if (codepoint_out) *codepoint_out = event.codepoint;
  if (scale_out) *scale_out = event.scale;
  if (x_out) *x_out = event.x;
  if (y_out) *y_out = event.y;
  if (phase_out) *phase_out = event.phase;
  if (ime_kind_out) *ime_kind_out = event.ime_kind;
  if (ime_start_out) *ime_start_out = event.ime_start;
  if (ime_end_out) *ime_end_out = event.ime_end;
  if (dx_out) *dx_out = event.dx;
  if (dy_out) *dy_out = event.dy;
  if (event.kind == MBW_IOS_HOST_IME_EVENT) {
    int32_t len = event.text_len > 0 ? event.text_len : 0;
    if (len > MBW_IOS_HOST_TEXT_CAP) len = MBW_IOS_HOST_TEXT_CAP;
    memcpy(g_pending_ime_text, event.text, (size_t)len);
    g_pending_ime_text_len = len;
  }
  return event.kind;
}
MOONBIT_FFI_EXPORT
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_ios_host_take_pending_ime_text(void) {
  int32_t len = g_pending_ime_text_len;
  if (len < 0) len = 0;
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  if (len > 0) {
    memcpy(bytes, g_pending_ime_text, (size_t)len);
  }
  g_pending_ime_text_len = 0;
  return bytes;
}

// IME callback table installed by the UIKit AppDelegate template. When no
// template is linked (host-sim tests), these remain NULL and the runtime's
// ime_set_state / ime_reset calls become no-ops.
static mbw_ios_ime_set_state_fn g_ime_set_state = NULL;
static mbw_ios_ime_reset_fn g_ime_reset = NULL;
void mbw_ios_ime_install_callbacks(
    mbw_ios_ime_set_state_fn set_state,
    mbw_ios_ime_reset_fn reset) {
  g_ime_set_state = set_state;
  g_ime_reset = reset;
}

MOONBIT_FFI_EXPORT
void mbw_ios_ime_set_state(int32_t enabled,
                           const char *text,
                           int32_t sel_location,
                           int32_t sel_length,
                           double caret_x,
                           double caret_y,
                           double caret_w,
                           double caret_h) {
  if (g_ime_set_state) {
    g_ime_set_state(enabled, text, sel_location, sel_length,
                    caret_x, caret_y, caret_w, caret_h);
  }
  (void)enabled;
}

MOONBIT_FFI_EXPORT
void mbw_ios_ime_reset(void) {
  if (g_ime_reset) {
    g_ime_reset();
  }
}
void mbw_ios_host_on_start(void) { enqueue(simple(MBW_IOS_HOST_START)); }
void mbw_ios_host_on_resume(void) { enqueue(simple(MBW_IOS_HOST_RESUME)); }
void mbw_ios_host_on_pause(void) { enqueue(simple(MBW_IOS_HOST_PAUSE)); }
void mbw_ios_host_on_stop(void) { enqueue(simple(MBW_IOS_HOST_STOP)); }
void mbw_ios_host_on_destroy(void) { enqueue(simple(MBW_IOS_HOST_DESTROY)); }
void mbw_ios_host_on_memory_warning(void) { enqueue(simple(MBW_IOS_HOST_MEMORY_WARNING)); }
void mbw_ios_host_on_surface_init(uint64_t handle, uint64_t token, int32_t width, int32_t height, double scale) {
  mbw_ios_host_event event = simple(MBW_IOS_HOST_SURFACE_INIT);
  event.handle = handle; event.token = token; event.width = width; event.height = height; event.scale = scale;
  enqueue(event);
}
void mbw_ios_host_on_surface_term(void) { enqueue(simple(MBW_IOS_HOST_SURFACE_TERM)); }
void mbw_ios_host_on_surface_resize(int32_t width, int32_t height, double scale) {
  mbw_ios_host_event event = simple(MBW_IOS_HOST_SURFACE_RESIZE);
  event.width = width; event.height = height; event.scale = scale; enqueue(event);
}
void mbw_ios_host_on_pointer_moved(double x, double y) {
  mbw_ios_host_event event = simple(MBW_IOS_HOST_POINTER_MOVED); event.x = x; event.y = y; enqueue(event);
}
void mbw_ios_host_on_pointer_button(int32_t pressed, double x, double y) {
  mbw_ios_host_event event = simple(MBW_IOS_HOST_POINTER_BUTTON); event.pressed = pressed; event.x = x; event.y = y; enqueue(event);
}
void mbw_ios_host_on_pointer_phase(int32_t phase, double x, double y, double time_ms) {
  mbw_ios_host_event event = simple(MBW_IOS_HOST_POINTER_PHASE); event.phase = phase; event.x = x; event.y = y; event.scale = time_ms; enqueue(event);
}
void mbw_ios_host_on_scroll(double x, double y, double dx, double dy, int32_t phase) {
  mbw_ios_host_event event = simple(MBW_IOS_HOST_SCROLL); event.x = x; event.y = y; event.dx = dx; event.dy = dy; event.phase = phase; enqueue(event);
}
void mbw_ios_host_on_ime_event(int32_t ime_kind, const char *text, int32_t start, int32_t end) {
  mbw_ios_host_event event = simple(MBW_IOS_HOST_IME_EVENT); event.ime_kind = ime_kind; event.ime_start = start; event.ime_end = end;
  event.text_len = 0;
  if (text != NULL) {
    size_t len = strlen(text);
    if (len > MBW_IOS_HOST_TEXT_CAP) len = MBW_IOS_HOST_TEXT_CAP;
    memcpy(event.text, text, len);
    event.text_len = (int32_t)len;
  }
  enqueue(event);
}
void mbw_ios_host_on_keyboard_codepoint(int32_t codepoint) {
  mbw_ios_host_event event = simple(MBW_IOS_HOST_KEYBOARD_CODEPOINT); event.codepoint = codepoint; enqueue(event);
}

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

int32_t mbw_ios_window_present_rgba_pixels(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    int32_t stride_bytes,
    const uint8_t *pixels,
    int32_t pixel_len) {
  if (window_handle == 0 || width <= 0 || height <= 0 || pixels == NULL ||
      pixel_len <= 0 || stride_bytes < width * 4) {
    return -1;
  }
  UIView *view = (__bridge UIView *)(void *)(uintptr_t)window_handle;
  if (view == nil) {
    return -2;
  }
  size_t nbytes = (size_t)height * (size_t)stride_bytes;
  if ((int32_t)nbytes > pixel_len) {
    nbytes = (size_t)pixel_len;
  }
  /* Soft present: bitmap on the main layer for host smoke / CPU path. */
  CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
  if (space == NULL) {
    return -3;
  }
  CGContextRef ctx = CGBitmapContextCreate(
      (void *)pixels, (size_t)width, (size_t)height, 8, (size_t)stride_bytes,
      space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
  CGColorSpaceRelease(space);
  if (ctx == NULL) {
    return -4;
  }
  CGImageRef image = CGBitmapContextCreateImage(ctx);
  CGContextRelease(ctx);
  if (image == NULL) {
    return -5;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    /* Transfer CGImage ownership into the layer contents. */
    view.layer.contents = CFBridgingRelease(image);
  });
  return 0;
}

int32_t mbw_ios_window_clear_color(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a) {
  if (width <= 0 || height <= 0 || width > 8192 || height > 8192) {
    return -1;
  }
  int32_t stride = width * 4;
  int32_t len = stride * height;
  uint8_t *pixels = (uint8_t *)malloc((size_t)len);
  if (pixels == NULL) {
    return -2;
  }
  for (int32_t i = 0; i < width * height; i++) {
    pixels[i * 4 + 0] = r;
    pixels[i * 4 + 1] = g;
    pixels[i * 4 + 2] = b;
    pixels[i * 4 + 3] = a;
  }
  int32_t rc = mbw_ios_window_present_rgba_pixels(window_handle, width, height,
                                                  stride, pixels, len);
  free(pixels);
  return rc;
}
#else
int32_t mbw_ios_window_present_rgba_pixels(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    int32_t stride_bytes,
    const uint8_t *pixels,
    int32_t pixel_len) {
  (void)width;
  (void)height;
  (void)stride_bytes;
  (void)pixels;
  (void)pixel_len;
  /* Host-sim / non-iOS: succeed for non-zero handles so present smoke works. */
  return window_handle == 0 ? -10 : 0;
}

int32_t mbw_ios_window_clear_color(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a) {
  (void)width;
  (void)height;
  (void)r;
  (void)g;
  (void)b;
  (void)a;
  return window_handle == 0 ? -10 : 0;
}
#endif

#include <unistd.h>
void mbw_ios_sleep_ms(int32_t ms) {
  if (ms <= 0) {
    return;
  }
  usleep((useconds_t)ms * 1000u);
}
