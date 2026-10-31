#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
enum mbw_harmonyos_host_cmd {
  MBW_HARMONYOS_HOST_START = 1,
  MBW_HARMONYOS_HOST_RESUME = 2,
  MBW_HARMONYOS_HOST_PAUSE = 3,
  MBW_HARMONYOS_HOST_STOP = 4,
  MBW_HARMONYOS_HOST_SURFACE_INIT = 5,
  MBW_HARMONYOS_HOST_SURFACE_TERM = 6,
  MBW_HARMONYOS_HOST_SURFACE_RESIZE = 7,
  MBW_HARMONYOS_HOST_POINTER_MOVED = 8,
  MBW_HARMONYOS_HOST_POINTER_BUTTON = 9,
  MBW_HARMONYOS_HOST_KEYBOARD_CODEPOINT = 10,
  MBW_HARMONYOS_HOST_MEMORY_WARNING = 11,
  MBW_HARMONYOS_HOST_DESTROY = 12,
  /* Mouse wheel / trackpad scroll. delta_x/delta_y carry the axis values. */
  MBW_HARMONYOS_HOST_SCROLL = 13,
  /* Non-character key press/release (Backspace, Delete, arrows, shortcuts).
     Character keys still travel through KEYBOARD_CODEPOINT so text entry keeps
     its existing path. */
  MBW_HARMONYOS_HOST_KEY = 14
};
typedef struct mbw_harmonyos_host_event {
  int32_t kind;
  uint64_t handle;
  uint64_t token;
  int32_t width;
  int32_t height;
  int32_t pressed;
  int32_t codepoint;
  double scale;
  double x;
  double y;
  /* SCROLL: axis deltas (positive = right/down). */
  double delta_x;
  double delta_y;
  /* KEY: platform key code, modifier bitmask, 1 = pressed. */
  int32_t key_code;
  int32_t key_modifiers;
  /* KEY: 1 when the key event matched a named key we can decode. */
  int32_t key_kind;
} mbw_harmonyos_host_event;
void mbw_harmonyos_host_on_start(void);
void mbw_harmonyos_host_on_resume(void);
void mbw_harmonyos_host_on_pause(void);
void mbw_harmonyos_host_on_stop(void);
void mbw_harmonyos_host_on_destroy(void);
void mbw_harmonyos_host_on_memory_warning(void);
void mbw_harmonyos_host_on_surface_init(uint64_t handle, uint64_t token, int32_t width, int32_t height, double scale);
void mbw_harmonyos_host_on_surface_term(void);
void mbw_harmonyos_host_on_surface_resize(int32_t width, int32_t height, double scale);
void mbw_harmonyos_host_on_pointer_moved(double x, double y);
void mbw_harmonyos_host_on_pointer_button(int32_t pressed, double x, double y);
void mbw_harmonyos_host_on_keyboard_codepoint(int32_t codepoint);
void mbw_harmonyos_host_on_scroll(double delta_x, double delta_y);
void mbw_harmonyos_host_on_scroll_at(double x, double y, double delta_x, double delta_y);
void mbw_harmonyos_host_on_key(int32_t key_code, int32_t key_modifiers, int32_t pressed);
int32_t mbw_harmonyos_host_poll_raw(uint64_t *handle_out, uint64_t *token_out, int32_t *width_out, int32_t *height_out, int32_t *pressed_out, int32_t *codepoint_out, double *scale_out, double *x_out, double *y_out, double *delta_x_out, double *delta_y_out, int32_t *key_code_out, int32_t *key_modifiers_out, int32_t *key_kind_out);
void mbw_harmonyos_host_queue_reset(void);
#ifdef __cplusplus
}
#endif

int32_t mbw_harmonyos_window_present_rgba_pixels(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    int32_t stride_bytes,
    const uint8_t *pixels,
    int32_t pixel_len);
int32_t mbw_harmonyos_window_clear_color(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a);
