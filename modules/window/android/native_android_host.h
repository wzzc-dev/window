#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum mbw_android_host_cmd {
  MBW_ANDROID_HOST_START = 1,
  MBW_ANDROID_HOST_RESUME = 2,
  MBW_ANDROID_HOST_PAUSE = 3,
  MBW_ANDROID_HOST_STOP = 4,
  MBW_ANDROID_HOST_SURFACE_INIT = 5,
  MBW_ANDROID_HOST_SURFACE_TERM = 6,
  MBW_ANDROID_HOST_SURFACE_RESIZE = 7,
  MBW_ANDROID_HOST_POINTER_MOVED = 8,
  MBW_ANDROID_HOST_POINTER_BUTTON = 9,
  MBW_ANDROID_HOST_KEYBOARD_CODEPOINT = 10,
  MBW_ANDROID_HOST_MEMORY_WARNING = 11,
  MBW_ANDROID_HOST_DESTROY = 12
};

typedef struct mbw_android_host_event {
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
} mbw_android_host_event;

/* Host/JNI push into the C queue. */
void mbw_android_host_on_create(void);
void mbw_android_host_on_resume(void);
void mbw_android_host_on_pause(void);
void mbw_android_host_on_stop(void);
void mbw_android_host_on_destroy(void);
void mbw_android_host_on_memory_warning(void);
void mbw_android_host_on_surface_init(
    uint64_t handle,
    uint64_t token,
    int32_t width,
    int32_t height,
    double scale);
void mbw_android_host_on_surface_term(void);
void mbw_android_host_on_surface_resize(int32_t width, int32_t height, double scale);
void mbw_android_host_on_pointer_moved(double x, double y);
void mbw_android_host_on_pointer_button(int32_t pressed, double x, double y);
void mbw_android_host_on_keyboard_codepoint(int32_t codepoint);

/* MoonBit drains the queue one event at a time. Returns 1 if an event was written. */
int32_t mbw_android_host_poll(mbw_android_host_event *out);
int32_t mbw_android_host_poll_raw(
    uint64_t *handle_out,
    uint64_t *token_out,
    int32_t *width_out,
    int32_t *height_out,
    int32_t *pressed_out,
    int32_t *codepoint_out,
    double *scale_out,
    double *x_out,
    double *y_out);
void mbw_android_host_queue_reset(void);

int32_t mbw_android_window_present_rgba_pixels(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    int32_t stride_bytes,
    const uint8_t *pixels,
    int32_t pixel_len);
int32_t mbw_android_window_clear_color(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    uint8_t r,
    uint8_t g,
    uint8_t b,
    uint8_t a);

/* Configure visible system bars from the MoonBit platform entry. */
int32_t mbw_android_set_status_bar_immersive(int32_t immersive);

#ifdef __cplusplus
}
#endif
