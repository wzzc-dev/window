/* Bootstraps the MoonBit EventLoop for the window-hosted iOS template. */
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if TARGET_OS_IPHONE
#include <os/log.h>
#define MBW_ILOG(fmt, ...) os_log(OS_LOG_DEFAULT, "WindowIosApp: " fmt, ##__VA_ARGS__)
#else
#define MBW_ILOG(...) do { fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); } while (0)
#endif

#ifndef MBW_IOS_MOONBIT_MAIN
#define MBW_IOS_MOONBIT_MAIN moonbit_main_entry
#endif

extern int MBW_IOS_MOONBIT_MAIN(void);

static pthread_t g_loop_thread;
static int g_loop_started = 0;

static void *mbw_ios_loop_thread(void *arg) {
  (void)arg;
  MBW_ILOG("MoonBit EventLoop thread starting");
  MBW_ILOG("mbw_ios_loop_thread: about to call MBW_IOS_MOONBIT_MAIN");
  int rc = MBW_IOS_MOONBIT_MAIN();
  MBW_ILOG("mbw_ios_loop_thread: MBW_IOS_MOONBIT_MAIN returned %{public}d", rc);
  MBW_ILOG("MoonBit EventLoop thread exited");
  return NULL;
}

int mbw_ios_start_event_loop(void) {
  if (g_loop_started) {
    return 0;
  }
  g_loop_started = 1;
  if (pthread_create(&g_loop_thread, NULL, mbw_ios_loop_thread, NULL) != 0) {
    g_loop_started = 0;
    MBW_ILOG("pthread_create failed");
    return -1;
  }
  pthread_detach(g_loop_thread);
  return 0;
}
