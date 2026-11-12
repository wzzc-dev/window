#import "native_appkit_bridge.h"

#import <CoreVideo/CoreVideo.h>
#import <dispatch/dispatch.h>

#include <stdint.h>

// Display-refresh frame clock for hosts that drive their own pump loop.
//
// The clock is a CVDisplayLink bound to the display that owns the window's
// content view. Its callback runs on a dedicated CoreVideo thread and only
// signals a dispatch semaphore: MoonBit callbacks must never run on a foreign
// thread, and AppKit must not be touched off the main thread here. Hosts call
// `mbw_frame_clock_wait` on the main thread to block until the next refresh
// boundary, bounded by a timeout.
//
// The semaphore is created once and deliberately kept alive for the process
// lifetime. A late callback after shutdown then signals a valid object instead
// of racing a release; the link itself is stopped and released synchronously
// in `mbw_frame_clock_shutdown`.

static CVDisplayLinkRef g_frame_link = NULL;
static dispatch_semaphore_t g_frame_semaphore = NULL;
static uint32_t g_frame_display_id = 0;

MOONBIT_FFI_EXPORT
void mbw_frame_clock_shutdown(void);

static CVReturn mbw_frame_clock_callback(CVDisplayLinkRef link,
                                         const CVTimeStamp *now,
                                         const CVTimeStamp *output_time,
                                         CVOptionFlags flags_in,
                                         CVOptionFlags *flags_out,
                                         void *context) {
  (void)link;
  (void)now;
  (void)output_time;
  (void)flags_in;
  (void)flags_out;
  (void)context;
  dispatch_semaphore_t semaphore = g_frame_semaphore;
  if (semaphore != NULL) {
    dispatch_semaphore_signal(semaphore);
  }
  return kCVReturnSuccess;
}

static void mbw_frame_clock_drain(void) {
  dispatch_semaphore_t semaphore = g_frame_semaphore;
  if (semaphore == NULL) {
    return;
  }
  while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) == 0) {
    // Consume ticks that arrived while the host was busy. The next wait should
    // observe the next refresh, not a backlog of stale ones.
  }
}

static uint32_t mbw_frame_clock_display_for_view(uint64_t ns_view) {
  uint32_t display_id = 0;
  if (ns_view != 0) {
    NSView *view = (__bridge NSView *)(void *)(uintptr_t)ns_view;
    NSWindow *window = [view window];
    NSScreen *screen = [window screen];
    if (screen == nil) {
      screen = [NSScreen mainScreen];
    }
    if (screen != nil) {
      NSDictionary *description = [screen deviceDescription];
      NSNumber *number = [description objectForKey:@"NSScreenNumber"];
      if (number != nil) {
        display_id = [number unsignedIntValue];
      }
    }
  }
  if (display_id == 0) {
    display_id = CGMainDisplayID();
  }
  return display_id;
}

MOONBIT_FFI_EXPORT
int32_t mbw_frame_clock_init(uint64_t ns_view) {
  uint32_t display_id = mbw_frame_clock_display_for_view(ns_view);
  if (display_id == 0) {
    return 0;
  }
  if (g_frame_link != NULL) {
    if (g_frame_display_id == display_id) {
      return 1;
    }
    mbw_frame_clock_shutdown();
  }
  if (g_frame_semaphore == NULL) {
    g_frame_semaphore = dispatch_semaphore_create(0);
    if (g_frame_semaphore == NULL) {
      return 0;
    }
  }
  mbw_frame_clock_drain();

  CVDisplayLinkRef link = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CVReturn created =
      CVDisplayLinkCreateWithCGDisplay((CGDirectDisplayID)display_id, &link);
  if (created != kCVReturnSuccess || link == NULL) {
    return 0;
  }
  CVReturn configured =
      CVDisplayLinkSetOutputCallback(link, mbw_frame_clock_callback, NULL);
  CVReturn started = configured == kCVReturnSuccess ? CVDisplayLinkStart(link)
                                                    : configured;
#pragma clang diagnostic pop
  if (started != kCVReturnSuccess) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CVDisplayLinkRelease(link);
#pragma clang diagnostic pop
    return 0;
  }
  g_frame_link = link;
  g_frame_display_id = display_id;
  return 1;
}

MOONBIT_FFI_EXPORT
int32_t mbw_frame_clock_wait(int32_t timeout_ms) {
  dispatch_semaphore_t semaphore = g_frame_semaphore;
  if (semaphore == NULL || g_frame_link == NULL) {
    return 0;
  }
  // Return immediately when a refresh already happened while the previous
  // frame was produced. Otherwise block until the next one, capped by the
  // timeout so a stopped display cannot stall the host.
  if (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW) == 0) {
    mbw_frame_clock_drain();
    return 1;
  }
  if (timeout_ms < 0) {
    timeout_ms = 0;
  }
  dispatch_time_t deadline =
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)timeout_ms * NSEC_PER_MSEC);
  if (dispatch_semaphore_wait(semaphore, deadline) != 0) {
    return 0;
  }
  mbw_frame_clock_drain();
  return 1;
}

MOONBIT_FFI_EXPORT
void mbw_frame_clock_shutdown(void) {
  if (g_frame_link != NULL) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CVDisplayLinkStop(g_frame_link);
    CVDisplayLinkRelease(g_frame_link);
#pragma clang diagnostic pop
    g_frame_link = NULL;
  }
  g_frame_display_id = 0;
  mbw_frame_clock_drain();
}

MOONBIT_FFI_EXPORT
uint32_t mbw_frame_clock_display_id(void) {
  return g_frame_display_id;
}

MOONBIT_FFI_EXPORT
int32_t mbw_frame_clock_refresh_millihz(void) {
  if (g_frame_link == NULL) {
    return 0;
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CVTime time = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(g_frame_link);
#pragma clang diagnostic pop
  if ((time.flags & kCVTimeIsIndefinite) != 0 || time.timeScale <= 0 ||
      time.timeValue <= 0) {
    return 0;
  }
  int64_t numerator = (int64_t)time.timeScale * 1000;
  int64_t millihertz = numerator / time.timeValue;
  int64_t remainder = numerator % time.timeValue;
  int64_t rounding_threshold = time.timeValue / 2 + time.timeValue % 2;
  if (remainder >= rounding_threshold) {
    millihertz += 1;
  }
  if (millihertz <= 0) {
    return 0;
  }
  if (millihertz > INT32_MAX) {
    return INT32_MAX;
  }
  return (int32_t)millihertz;
}
