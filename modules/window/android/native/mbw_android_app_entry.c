/* Bootstraps the MoonBit EventLoop for the window-hosted Android template.
 * HostedActivity JNI (native_android_host.c) enqueues HostCmd; this file only
 * starts the MoonBit main once on a dedicated thread. */

#include <pthread.h>
#include <stdint.h>
#include <stdio.h>

#if defined(__ANDROID__)
#include <android/log.h>
#include <jni.h>
extern void mbw_android_host_set_java_vm(JavaVM *vm);
#ifndef MBW_ANDROID_APP_LOG_TAG
#define MBW_ANDROID_APP_LOG_TAG "WindowAndroidApp"
#endif
#define MBW_ALOG(...) __android_log_print(ANDROID_LOG_INFO, MBW_ANDROID_APP_LOG_TAG, __VA_ARGS__)
#else
#define MBW_ALOG(...) do { fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

/* MoonBit main is renamed via compile define when linked into the shared lib. */
#ifndef MBW_ANDROID_MOONBIT_MAIN
#define MBW_ANDROID_MOONBIT_MAIN moonbit_main_entry
#endif

extern int MBW_ANDROID_MOONBIT_MAIN(void);

static pthread_t g_loop_thread;
static int g_loop_started = 0;

static void *mbw_android_loop_thread(void *arg) {
  (void)arg;
  MBW_ALOG("MoonBit EventLoop thread starting");
  (void)MBW_ANDROID_MOONBIT_MAIN();
  MBW_ALOG("MoonBit EventLoop thread exited");
  return NULL;
}

int mbw_android_start_event_loop(void) {
  if (g_loop_started) {
    return 0;
  }
  g_loop_started = 1;
  if (pthread_create(&g_loop_thread, NULL, mbw_android_loop_thread, NULL) != 0) {
    g_loop_started = 0;
    MBW_ALOG("pthread_create failed");
    return -1;
  }
  pthread_detach(g_loop_thread);
  return 0;
}

#if defined(__ANDROID__)
/* Also start the loop when the library loads if Activity starts late. */
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
  (void)reserved;
  mbw_android_host_set_java_vm(vm);
  return JNI_VERSION_1_6;
}
#endif
