#include "native_android_host.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(__ANDROID__)
#include <android/log.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <jni.h>
#include <pthread.h>
#endif

#ifndef MBW_ANDROID_HOST_QUEUE_CAP
#define MBW_ANDROID_HOST_QUEUE_CAP 256
#endif

static mbw_android_host_event g_queue[MBW_ANDROID_HOST_QUEUE_CAP];
static int32_t g_head = 0;
static int32_t g_tail = 0;

#if defined(__ANDROID__)
static JavaVM *g_android_vm = NULL;
static jobject g_android_activity = NULL;
static pthread_mutex_t g_android_activity_mutex = PTHREAD_MUTEX_INITIALIZER;

void mbw_android_host_set_java_vm(JavaVM *vm) {
  g_android_vm = vm;
}

static void mbw_android_host_set_activity(JNIEnv *env, jobject activity) {
  if (env == NULL || activity == NULL) {
    return;
  }
  pthread_mutex_lock(&g_android_activity_mutex);
  if (g_android_activity != NULL) {
    (*env)->DeleteGlobalRef(env, g_android_activity);
  }
  g_android_activity = (*env)->NewGlobalRef(env, activity);
  pthread_mutex_unlock(&g_android_activity_mutex);
}

static void mbw_android_host_clear_activity(JNIEnv *env) {
  if (env == NULL) {
    return;
  }
  pthread_mutex_lock(&g_android_activity_mutex);
  if (g_android_activity != NULL) {
    (*env)->DeleteGlobalRef(env, g_android_activity);
    g_android_activity = NULL;
  }
  pthread_mutex_unlock(&g_android_activity_mutex);
}
#endif

static void mbw_android_host_enqueue(mbw_android_host_event event) {
  int32_t next = (g_tail + 1) % MBW_ANDROID_HOST_QUEUE_CAP;
  if (next == g_head) {
    /* Drop oldest on overflow to keep the loop live. */
    g_head = (g_head + 1) % MBW_ANDROID_HOST_QUEUE_CAP;
  }
  g_queue[g_tail] = event;
  g_tail = next;
}

static mbw_android_host_event mbw_android_host_simple(int32_t kind) {
  mbw_android_host_event event;
  memset(&event, 0, sizeof(event));
  event.kind = kind;
  return event;
}

void mbw_android_host_queue_reset(void) {
  g_head = 0;
  g_tail = 0;
}

int32_t mbw_android_host_poll(mbw_android_host_event *out) {
  if (out == NULL || g_head == g_tail) {
    return 0;
  }
  *out = g_queue[g_head];
  g_head = (g_head + 1) % MBW_ANDROID_HOST_QUEUE_CAP;
  return 1;
}

int32_t mbw_android_host_poll_raw(
    uint64_t *handle_out,
    uint64_t *token_out,
    int32_t *width_out,
    int32_t *height_out,
    int32_t *pressed_out,
    int32_t *codepoint_out,
    double *scale_out,
    double *x_out,
    double *y_out) {
  mbw_android_host_event event;
  if (!mbw_android_host_poll(&event)) {
    return 0;
  }
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

void mbw_android_host_on_create(void) {
  mbw_android_host_enqueue(mbw_android_host_simple(MBW_ANDROID_HOST_START));
}

void mbw_android_host_on_resume(void) {
  mbw_android_host_enqueue(mbw_android_host_simple(MBW_ANDROID_HOST_RESUME));
}

void mbw_android_host_on_pause(void) {
  mbw_android_host_enqueue(mbw_android_host_simple(MBW_ANDROID_HOST_PAUSE));
}

void mbw_android_host_on_stop(void) {
  mbw_android_host_enqueue(mbw_android_host_simple(MBW_ANDROID_HOST_STOP));
}

void mbw_android_host_on_destroy(void) {
  mbw_android_host_enqueue(mbw_android_host_simple(MBW_ANDROID_HOST_DESTROY));
}

void mbw_android_host_on_memory_warning(void) {
  mbw_android_host_enqueue(mbw_android_host_simple(MBW_ANDROID_HOST_MEMORY_WARNING));
}

void mbw_android_host_on_surface_init(
    uint64_t handle,
    uint64_t token,
    int32_t width,
    int32_t height,
    double scale) {
  mbw_android_host_event event = mbw_android_host_simple(MBW_ANDROID_HOST_SURFACE_INIT);
  event.handle = handle;
  event.token = token;
  event.width = width;
  event.height = height;
  event.scale = scale;
  mbw_android_host_enqueue(event);
}

void mbw_android_host_on_surface_term(void) {
  mbw_android_host_enqueue(mbw_android_host_simple(MBW_ANDROID_HOST_SURFACE_TERM));
}

void mbw_android_host_on_surface_resize(int32_t width, int32_t height, double scale) {
  mbw_android_host_event event = mbw_android_host_simple(MBW_ANDROID_HOST_SURFACE_RESIZE);
  event.width = width;
  event.height = height;
  event.scale = scale;
  mbw_android_host_enqueue(event);
}

void mbw_android_host_on_pointer_moved(double x, double y) {
  mbw_android_host_event event = mbw_android_host_simple(MBW_ANDROID_HOST_POINTER_MOVED);
  event.x = x;
  event.y = y;
  mbw_android_host_enqueue(event);
}

void mbw_android_host_on_pointer_button(int32_t pressed, double x, double y) {
  mbw_android_host_event event = mbw_android_host_simple(MBW_ANDROID_HOST_POINTER_BUTTON);
  event.pressed = pressed;
  event.x = x;
  event.y = y;
  mbw_android_host_enqueue(event);
}

void mbw_android_host_on_keyboard_codepoint(int32_t codepoint) {
  mbw_android_host_event event = mbw_android_host_simple(MBW_ANDROID_HOST_KEYBOARD_CODEPOINT);
  event.codepoint = codepoint;
  mbw_android_host_enqueue(event);
}


/* Soft present for smoke: lock ANativeWindow and fill solid color / RGBA buffer. */
int32_t mbw_android_window_present_rgba_pixels(
    uint64_t window_handle,
    int32_t width,
    int32_t height,
    int32_t stride_bytes,
    const uint8_t *pixels,
    int32_t pixel_len) {
#if defined(__ANDROID__)
  if (window_handle == 0 || width <= 0 || height <= 0 || pixels == NULL ||
      pixel_len <= 0 || stride_bytes < width * 4) {
    return -1;
  }
  ANativeWindow *window = (ANativeWindow *)(uintptr_t)window_handle;
  if (window == NULL) {
    return -2;
  }
  ANativeWindow_Buffer buffer;
  if (ANativeWindow_lock(window, &buffer, NULL) != 0) {
    return -3;
  }
  int32_t copy_w = width < buffer.width ? width : buffer.width;
  int32_t copy_h = height < buffer.height ? height : buffer.height;
  uint8_t *dst = (uint8_t *)buffer.bits;
  int32_t dst_stride = buffer.stride * 4;
  for (int32_t y = 0; y < copy_h; y++) {
    const uint8_t *src_row = pixels + (size_t)y * (size_t)stride_bytes;
    uint8_t *dst_row = dst + (size_t)y * (size_t)dst_stride;
    if ((y + 1) * stride_bytes > pixel_len) {
      break;
    }
    memcpy(dst_row, src_row, (size_t)copy_w * 4);
  }
  if (ANativeWindow_unlockAndPost(window) != 0) {
    return -4;
  }
  return 0;
#else
  (void)window_handle;
  (void)width;
  (void)height;
  (void)stride_bytes;
  (void)pixels;
  (void)pixel_len;
  /* Host-sim / non-Android: accept as no-op success for API smoke. */
  return 0;
#endif
}

int32_t mbw_android_window_clear_color(
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
  int32_t rc = mbw_android_window_present_rgba_pixels(
      window_handle, width, height, stride, pixels, len);
  free(pixels);
  return rc;
}

int32_t mbw_android_set_status_bar_immersive(int32_t immersive) {
#if defined(__ANDROID__)
  JavaVM *vm = g_android_vm;
  JNIEnv *env = NULL;
  jobject activity = NULL;
  int attached = 0;
  if (vm == NULL) {
    return -1;
  }

  jint env_status = (*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_6);
  if (env_status == JNI_EDETACHED) {
    if ((*vm)->AttachCurrentThread(vm, &env, NULL) != JNI_OK) {
      return -2;
    }
    attached = 1;
  } else if (env_status != JNI_OK || env == NULL) {
    return -3;
  }

  pthread_mutex_lock(&g_android_activity_mutex);
  if (g_android_activity != NULL) {
    activity = (*env)->NewLocalRef(env, g_android_activity);
  }
  pthread_mutex_unlock(&g_android_activity_mutex);
  if (activity == NULL) {
    if (attached) {
      (*vm)->DetachCurrentThread(vm);
    }
    return -4;
  }

  jclass activity_class = (*env)->GetObjectClass(env, activity);
  jmethodID apply = NULL;
  if (activity_class != NULL) {
    apply = (*env)->GetMethodID(
        env, activity_class, "applyStatusBarImmersive", "(Z)V");
  }
  if (apply == NULL) {
    if ((*env)->ExceptionCheck(env)) {
      (*env)->ExceptionClear(env);
    }
    if (activity_class != NULL) {
      (*env)->DeleteLocalRef(env, activity_class);
    }
    (*env)->DeleteLocalRef(env, activity);
    if (attached) {
      (*vm)->DetachCurrentThread(vm);
    }
    return -5;
  }

  (*env)->CallVoidMethod(
      env, activity, apply, immersive != 0 ? JNI_TRUE : JNI_FALSE);
  int32_t result = 0;
  if ((*env)->ExceptionCheck(env)) {
    (*env)->ExceptionClear(env);
    result = -6;
  }
  (*env)->DeleteLocalRef(env, activity_class);
  (*env)->DeleteLocalRef(env, activity);
  if (attached) {
    (*vm)->DetachCurrentThread(vm);
  }
  return result;
#else
  (void)immersive;
  return 0;
#endif
}

#if defined(__ANDROID__)

/* Started from HostedActivity onCreate so the MoonBit EventLoop can drain HostCmd. */
int mbw_android_start_event_loop(void);


#ifndef MBW_ANDROID_LOG_TAG
#define MBW_ANDROID_LOG_TAG "WindowAndroidHost"
#endif

static double mbw_android_density(JNIEnv *env, jobject activity) {
  if (env == NULL || activity == NULL) {
    return 1.0;
  }
  jclass activity_class = (*env)->GetObjectClass(env, activity);
  if (activity_class == NULL) {
    return 1.0;
  }
  jmethodID get_resources = (*env)->GetMethodID(
      env, activity_class, "getResources", "()Landroid/content/res/Resources;");
  if (get_resources == NULL) {
    return 1.0;
  }
  jobject resources = (*env)->CallObjectMethod(env, activity, get_resources);
  if (resources == NULL) {
    return 1.0;
  }
  jclass resources_class = (*env)->GetObjectClass(env, resources);
  jmethodID get_display_metrics = (*env)->GetMethodID(
      env, resources_class, "getDisplayMetrics",
      "()Landroid/util/DisplayMetrics;");
  if (get_display_metrics == NULL) {
    return 1.0;
  }
  jobject metrics =
      (*env)->CallObjectMethod(env, resources, get_display_metrics);
  if (metrics == NULL) {
    return 1.0;
  }
  jclass metrics_class = (*env)->GetObjectClass(env, metrics);
  jfieldID density_field =
      (*env)->GetFieldID(env, metrics_class, "density", "F");
  if (density_field == NULL) {
    return 1.0;
  }
  return (double)(*env)->GetFloatField(env, metrics, density_field);
}

JNIEXPORT void JNICALL
Java_dev_wzzc_window_template_HostedActivity_nativeOnHostCreate(JNIEnv *env,
                                                                jobject thiz) {
  mbw_android_host_set_activity(env, thiz);
  mbw_android_host_on_create();
  if (mbw_android_start_event_loop() != 0) {
    __android_log_print(ANDROID_LOG_ERROR, MBW_ANDROID_LOG_TAG,
                        "failed to start MoonBit EventLoop thread");
  }
}

JNIEXPORT void JNICALL
Java_dev_wzzc_window_template_HostedActivity_nativeOnHostResume(JNIEnv *env,
                                                                jobject thiz) {
  (void)env;
  (void)thiz;
  mbw_android_host_on_resume();
}

JNIEXPORT void JNICALL
Java_dev_wzzc_window_template_HostedActivity_nativeOnHostPause(JNIEnv *env,
                                                               jobject thiz) {
  (void)env;
  (void)thiz;
  mbw_android_host_on_pause();
}

JNIEXPORT void JNICALL
Java_dev_wzzc_window_template_HostedActivity_nativeOnHostDestroy(JNIEnv *env,
                                                                 jobject thiz) {
  (void)thiz;
  mbw_android_host_on_destroy();
  mbw_android_host_clear_activity(env);
}

JNIEXPORT void JNICALL
Java_dev_wzzc_window_template_HostedActivity_nativeOnSurfaceChanged(
    JNIEnv *env, jobject thiz, jobject surface, jint width, jint height) {
  if (surface == NULL || width <= 0 || height <= 0) {
    mbw_android_host_on_surface_term();
    return;
  }
  ANativeWindow *window = ANativeWindow_fromSurface(env, surface);
  if (window == NULL) {
    __android_log_print(ANDROID_LOG_ERROR, MBW_ANDROID_LOG_TAG,
                        "ANativeWindow_fromSurface failed");
    return;
  }
  uint64_t handle = (uint64_t)(uintptr_t)window;
  double scale = mbw_android_density(env, thiz);
  mbw_android_host_on_surface_init(handle, 0, (int32_t)width, (int32_t)height,
                                   scale);
}

JNIEXPORT void JNICALL
Java_dev_wzzc_window_template_HostedActivity_nativeOnSurfaceDestroyed(
    JNIEnv *env, jobject thiz) {
  (void)env;
  (void)thiz;
  mbw_android_host_on_surface_term();
}

JNIEXPORT void JNICALL Java_dev_wzzc_window_template_HostedActivity_nativeOnPointer(
    JNIEnv *env, jobject thiz, jint action, jfloat x, jfloat y) {
  (void)env;
  (void)thiz;
  if (action == 0) {
    mbw_android_host_on_pointer_moved((double)x, (double)y);
  } else if (action == 1) {
    mbw_android_host_on_pointer_button(1, (double)x, (double)y);
  } else if (action == 2) {
    mbw_android_host_on_pointer_button(0, (double)x, (double)y);
  }
}

JNIEXPORT void JNICALL
Java_dev_wzzc_window_template_HostedActivity_nativeOnKeyboardCodepoint(
    JNIEnv *env, jobject thiz, jint codepoint) {
  (void)env;
  (void)thiz;
  mbw_android_host_on_keyboard_codepoint((int32_t)codepoint);
}

#endif /* __ANDROID__ */

#include <unistd.h>
void mbw_android_sleep_ms(int32_t ms) {
  if (ms <= 0) {
    return;
  }
  usleep((useconds_t)ms * 1000u);
}
