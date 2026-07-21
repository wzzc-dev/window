/* Bootstraps the MoonBit EventLoop for the window-hosted HarmonyOS template. */
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>

#ifndef MBW_HARMONYOS_MOONBIT_MAIN
#define MBW_HARMONYOS_MOONBIT_MAIN moonbit_main_entry
#endif

extern int MBW_HARMONYOS_MOONBIT_MAIN(void);

static pthread_t g_loop_thread;
static int g_loop_started = 0;

static void *mbw_harmonyos_loop_thread(void *arg) {
  (void)arg;
  fprintf(stderr, "WindowHarmonyOSApp: MoonBit EventLoop thread starting\n");
  (void)MBW_HARMONYOS_MOONBIT_MAIN();
  fprintf(stderr, "WindowHarmonyOSApp: MoonBit EventLoop thread exited\n");
  return NULL;
}

int mbw_harmonyos_start_event_loop(void) {
  if (g_loop_started) {
    return 0;
  }
  g_loop_started = 1;
  if (pthread_create(&g_loop_thread, NULL, mbw_harmonyos_loop_thread, NULL) != 0) {
    g_loop_started = 0;
    fprintf(stderr, "WindowHarmonyOSApp: pthread_create failed\n");
    return -1;
  }
  pthread_detach(g_loop_thread);
  return 0;
}
