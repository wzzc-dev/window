#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// Touch phases (matches MoonBit TouchPhase: 0..3 must stay in phase order).
#define MBW_IOS_PHASE_BEGAN  0
#define MBW_IOS_PHASE_MOVED  1
#define MBW_IOS_PHASE_ENDED  2
#define MBW_IOS_PHASE_CANCEL 3

// IME payload kinds (matches MoonBit Ime enum variants exported back to host).
#define MBW_IOS_IME_COMMIT       1
#define MBW_IOS_IME_PREEDIT      2
#define MBW_IOS_IME_PREEDIT_END  3
#define MBW_IOS_IME_SET_SELECTION 4
#define MBW_IOS_IME_DELETE_BACK  5

#ifndef MBW_IOS_HOST_TEXT_CAP
#define MBW_IOS_HOST_TEXT_CAP 512
#endif

enum mbw_ios_host_cmd {
  MBW_IOS_HOST_START = 1,
  MBW_IOS_HOST_RESUME = 2,
  MBW_IOS_HOST_PAUSE = 3,
  MBW_IOS_HOST_STOP = 4,
  MBW_IOS_HOST_SURFACE_INIT = 5,
  MBW_IOS_HOST_SURFACE_TERM = 6,
  MBW_IOS_HOST_SURFACE_RESIZE = 7,
  MBW_IOS_HOST_POINTER_MOVED = 8,
  MBW_IOS_HOST_POINTER_BUTTON = 9,
  MBW_IOS_HOST_KEYBOARD_CODEPOINT = 10,
  MBW_IOS_HOST_MEMORY_WARNING = 11,
  MBW_IOS_HOST_DESTROY = 12,
  MBW_IOS_HOST_POINTER_PHASE = 13,
  MBW_IOS_HOST_SCROLL = 14,
  MBW_IOS_HOST_IME_EVENT = 15
};
typedef struct mbw_ios_host_event {
  int32_t kind;
  uint64_t handle;
  uint64_t token;
  int32_t width;
  int32_t height;
  int32_t pressed;
  int32_t codepoint;
  int32_t phase;
  int32_t ime_kind;
  int32_t ime_start;
  int32_t ime_end;
  int32_t text_len;
  double scale;
  double x;
  double y;
  double dx;
  double dy;
  char text[MBW_IOS_HOST_TEXT_CAP];
} mbw_ios_host_event;
void mbw_ios_host_on_start(void);
void mbw_ios_host_on_resume(void);
void mbw_ios_host_on_pause(void);
void mbw_ios_host_on_stop(void);
void mbw_ios_host_on_destroy(void);
void mbw_ios_host_on_memory_warning(void);
void mbw_ios_host_on_surface_init(uint64_t handle, uint64_t token, int32_t width, int32_t height, double scale);
void mbw_ios_host_on_surface_term(void);
void mbw_ios_host_on_surface_resize(int32_t width, int32_t height, double scale);
void mbw_ios_host_on_pointer_moved(double x, double y);
void mbw_ios_host_on_pointer_button(int32_t pressed, double x, double y);
void mbw_ios_host_on_pointer_phase(int32_t phase, double x, double y, double time_ms);
void mbw_ios_host_on_scroll(double x, double y, double dx, double dy, int32_t phase);
void mbw_ios_host_on_keyboard_codepoint(int32_t codepoint);
void mbw_ios_host_on_ime_event(int32_t ime_kind, const char *text, int32_t start, int32_t end);
int32_t mbw_ios_host_poll_raw(uint64_t *handle_out, uint64_t *token_out, int32_t *width_out, int32_t *height_out, int32_t *pressed_out, int32_t *codepoint_out, double *scale_out, double *x_out, double *y_out, int32_t *phase_out, int32_t *ime_kind_out, int32_t *ime_start_out, int32_t *ime_end_out, double *dx_out, double *dy_out);
void mbw_ios_host_queue_reset(void);
#ifdef __cplusplus
}
#endif

#include <moonbit.h>
#ifdef __cplusplus
extern "C" {
#endif
MOONBIT_FFI_EXPORT moonbit_bytes_t mbw_ios_host_take_pending_ime_text(void);

///|
// IME state callback table installed by the UIKit AppDelegate template.
// When no template is linked (host-sim tests), the runtime side calls are
// no-ops, allowing window-hosted iOS tests to link without UIKit.
typedef void (*mbw_ios_ime_set_state_fn)(
    int32_t enabled,
    const char *text,
    int32_t sel_location,
    int32_t sel_length,
    double caret_x,
    double caret_y,
    double caret_w,
    double caret_h);
typedef void (*mbw_ios_ime_reset_fn)(void);
void mbw_ios_ime_install_callbacks(
    mbw_ios_ime_set_state_fn set_state,
    mbw_ios_ime_reset_fn reset);
#ifdef __cplusplus
}
#endif

int32_t mbw_ios_window_present_rgba_pixels(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    int32_t stride_bytes,
    const uint8_t *pixels,
    int32_t pixel_len);
int32_t mbw_ios_window_clear_color(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a);
