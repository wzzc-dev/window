#include "mbw_harmonyos_compat.h"

#if defined(__OHOS__)

#include <stddef.h>
#include <stdlib.h>

// The OHOS sysroot ships `posix_spawn_file_actions_addchdir_np` only inside the
// static `libc.a`; the dynamic `libc.so` that a HAP actually links against does
// not export it. The MoonBit native runtime calls it from `thread_pool.c`
// whenever a spawn job carries a `cwd`, so without a definition the shared
// library fails to link with an undefined symbol.
//
// Rather than re-implementing OHOS's private `posix_spawn_file_actions_t`
// layout (which the static object encodes and which is not public ABI), the
// template links OHOS's own `posix_spawn_file_actions_addchdir.o` from
// `libc.a`. That object references `__libc_malloc`, which `libc.so` also does
// not export, so this translation unit provides it as a thin alias of the
// public allocator. Only the allocator indirection is shimmed; the chdir
// semantics come from the platform implementation itself.
void *__libc_malloc(size_t size) {
  return malloc(size);
}

#endif

/* ---------------------------------------------------------------------------
 * VSync frame pacing.
 *
 * The host loop needs to present on the display's refresh boundary; sleeping a
 * fixed number of milliseconds lands the frame at an arbitrary phase and shows
 * up as judder even when the frame itself is cheap. Native ArkUI apps drive
 * their loop from DisplaySync for exactly this reason.
 *
 * `OH_NativeVSync_RequestFrame` delivers a callback on the next vsync; the loop
 * thread waits on a condition variable that the callback signals, with a timeout
 * so a missed vsync (window hidden, backend hiccup) cannot hang the loop.
 *
 * The callback runs on a platform thread, so the handshake uses a mutex and a
 * generation counter rather than assuming anything about the caller's thread.
 * ------------------------------------------------------------------------- */

#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <time.h>

#if __has_include(<native_vsync/native_vsync.h>)
#include <native_vsync/native_vsync.h>
#define MBW_HAS_NATIVE_VSYNC 1
#endif

static pthread_mutex_t g_vsync_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t g_vsync_cond = PTHREAD_COND_INITIALIZER;
/* Incremented by the vsync callback; the waiter compares against the value it
 * read before requesting the frame so a late signal from the previous request
 * cannot release the next wait. */
static unsigned long g_vsync_generation = 0;
#ifdef MBW_HAS_NATIVE_VSYNC
static OH_NativeVSync *g_vsync = NULL;
#endif

#ifdef MBW_HAS_NATIVE_VSYNC
static void mbw_harmonyos_vsync_callback(long long timestamp, void *data) {
  (void)timestamp;
  (void)data;
  pthread_mutex_lock(&g_vsync_mutex);
  g_vsync_generation += 1;
  pthread_cond_broadcast(&g_vsync_cond);
  pthread_mutex_unlock(&g_vsync_mutex);
}
#endif

/* Creates the vsync connection once. Returns 1 when vsync pacing is available. */
int32_t mbw_harmonyos_vsync_init(void) {
#ifdef MBW_HAS_NATIVE_VSYNC
  if (g_vsync != NULL) {
    return 1;
  }
  g_vsync = OH_NativeVSync_Create("moui_frame_pacing", 17);
  return g_vsync != NULL ? 1 : 0;
#else
  return 0;
#endif
}

/* Waits for the next vsync, or `timeout_ms` when no signal arrives. Returns 1
 * when the wait ended on a vsync and 0 on timeout / unavailable vsync. */
int32_t mbw_harmonyos_wait_for_vsync(int32_t timeout_ms) {
#ifdef MBW_HAS_NATIVE_VSYNC
  if (g_vsync == NULL) {
    return 0;
  }
  pthread_mutex_lock(&g_vsync_mutex);
  const unsigned long observed = g_vsync_generation;
  pthread_mutex_unlock(&g_vsync_mutex);

  if (OH_NativeVSync_RequestFrame(g_vsync, mbw_harmonyos_vsync_callback,
                                  NULL) != 0) {
    return 0;
  }

  struct timespec deadline;
  clock_gettime(CLOCK_REALTIME, &deadline);
  const int32_t wait_ms = timeout_ms > 0 ? timeout_ms : 16;
  deadline.tv_nsec += (long)wait_ms * 1000000L;
  while (deadline.tv_nsec >= 1000000000L) {
    deadline.tv_sec += 1;
    deadline.tv_nsec -= 1000000000L;
  }

  int32_t signalled = 0;
  pthread_mutex_lock(&g_vsync_mutex);
  while (g_vsync_generation == observed) {
    if (pthread_cond_timedwait(&g_vsync_cond, &g_vsync_mutex, &deadline) != 0) {
      break; /* timeout */
    }
  }
  signalled = g_vsync_generation != observed ? 1 : 0;
  pthread_mutex_unlock(&g_vsync_mutex);
  return signalled;
#else
  (void)timeout_ms;
  return 0;
#endif
}

/* ---------------------------------------------------------------------------
 * Monotonic clock for frame timing.
 *
 * The runtime advances its animation clock from a frame timestamp; without one
 * every animation stays latched "in flight", so a settle keeps asking for frames
 * but never reaches its end. Milliseconds since an arbitrary epoch are enough —
 * only differences are used.
 * ------------------------------------------------------------------------- */
double mbw_harmonyos_monotonic_ms(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (double)now.tv_sec * 1000.0 + (double)now.tv_nsec / 1000000.0;
}
