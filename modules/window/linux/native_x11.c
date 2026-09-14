// X11 (Xlib) implementation of the wzzc-dev/window Linux backend.
//
// The public entry points are the `mbw_x11_*` symbols; `native_backend.c`
// dispatches between this file and `native_wayland.c` based on a backend tag
// stored as the first field of the context/window structs.
//
// Presentation is CPU raster only: RGBA pixels are converted to BGRA and
// committed with MIT-SHM (double-buffered, completion-event tracked) or a
// plain XPutImage fallback. GPU surfaces (Vulkan/GLX) are not implemented.

#ifdef __linux__

// pipe2(O_CLOEXEC|O_NONBLOCK) is GNU-specific.
#define _GNU_SOURCE 1

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <time.h>
#include <unistd.h>
#include <moonbit.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/XShm.h>
#include <X11/extensions/Xrandr.h>

typedef void (*mbw_window_event_trampoline_t)(void *closure,
                                              int32_t kind, int32_t raw_id,
                                              int32_t arg0, int32_t arg1,
                                              int32_t arg2, double argd);
typedef void (*mbw_input_event_trampoline_t)(void *closure,
                                             int32_t raw_id, int32_t kind,
                                             int32_t arg0, int32_t arg1,
                                             int32_t arg2, int64_t argi);

static mbw_window_event_trampoline_t g_x11_window_trampoline = NULL;
static void *g_x11_window_closure = NULL;
static mbw_input_event_trampoline_t g_x11_input_trampoline = NULL;
static void *g_x11_input_closure = NULL;

enum {
  MBW_LINUX_EVENT_CLOSE = 1,
  MBW_LINUX_EVENT_DESTROYED = 2,
  MBW_LINUX_EVENT_CONFIGURE = 3,
  MBW_LINUX_EVENT_REDRAW = 5,
  MBW_LINUX_EVENT_FOCUS = 6,
  MBW_LINUX_EVENT_PROXY_WAKE = 7,
  MBW_LINUX_INPUT_POINTER_ENTER = 10,
  MBW_LINUX_INPUT_POINTER_MOVE = 11,
  MBW_LINUX_INPUT_POINTER_LEAVE = 12,
  MBW_LINUX_INPUT_POINTER_DOWN = 13,
  MBW_LINUX_INPUT_POINTER_UP = 14,
  MBW_LINUX_INPUT_WHEEL = 15,
  MBW_LINUX_INPUT_KEY_DOWN = 20,
  MBW_LINUX_INPUT_KEY_UP = 21,
};

enum {
  MBW_BACKEND_TAG_X11 = 2,
};

enum {
  MBW_X11_PRESENT_OK = 0,
  MBW_X11_PRESENT_BAD_WINDOW = 1,
  MBW_X11_PRESENT_BAD_DIMENSIONS = 2,
  MBW_X11_PRESENT_BAD_PIXELS = 3,
  MBW_X11_PRESENT_ALLOC_FAILED = 4,
};

// Mouse wheel scroll distance per X11 button 4/5/6/7 notch, in pixels.
// The host (event.mbt) consumes MouseScrollDelta::PixelDelta and the Wayland
// backend delivers compositor pixel deltas, so keep the same unit.
enum {
  MBW_X11_WHEEL_STEP_PX = 53,
};

// evdev keycodes are the shared unit between both Linux backends; X11
// keycodes are evdev + 8 on every modern (XKB/evdev) X server.
enum {
  MBW_X11_KEYCODE_EVDEV_OFFSET = 8,
};

typedef struct mbw_x11_monitor {
  RROutput output;
  int32_t x;
  int32_t y;
  int32_t width;
  int32_t height;
  double scale;
  char name[256];
  struct mbw_x11_monitor *next;
} mbw_x11_monitor_t;

typedef struct mbw_x11_present_buffer {
  XImage *image;
  XShmSegmentInfo *shm; // NULL when MIT-SHM is unavailable
  int busy;
} mbw_x11_present_buffer_t;

typedef struct mbw_x11_window {
  int32_t backend; // MBW_BACKEND_TAG_X11, must stay the first field
  struct mbw_x11_context *context;
  int32_t raw_id;
  Window xwindow;
  GC gc;
  Visual *visual;
  int32_t depth;
  int32_t width;
  int32_t height;
  int mapped;
  int destroyed;
  int destroy_requested;
  int focused;
  mbw_x11_present_buffer_t buffers[2];
  int32_t current_buffer;
  struct mbw_x11_window *next;
} mbw_x11_window_t;

typedef struct mbw_x11_context {
  int32_t backend; // MBW_BACKEND_TAG_X11, must stay the first field
  Display *display;
  int screen;
  Window root;
  int wake_pipe[2];
  mbw_x11_window_t *windows;
  mbw_x11_monitor_t *monitors;
  // Interned atoms.
  Atom wm_protocols;
  Atom wm_delete_window;
  Atom wm_take_focus;
  Atom net_wm_name;
  Atom net_wm_state;
  Atom net_wm_state_maximized_vert;
  Atom net_wm_state_maximized_horz;
  Atom net_wm_state_fullscreen;
  Atom motif_wm_hints;
  Atom utf8_string;
  Atom clipboard;
  Atom targets;
  Atom selection_property;
  Atom text_plain;
  // Clipboard state. `owned_text` is retained after losing ownership so the
  // process can still paste its own last copy (mirrors the Wayland backend).
  char *owned_text;
  size_t owned_text_len;
  int owns_clipboard;
  Window request_window;
  int selection_pending;
  int selection_done;
  char *selection_data;
  size_t selection_len;
  int shm_supported;
  int shm_event_base;
  struct mbw_x11_window *pointer_window;
} mbw_x11_context_t;

MOONBIT_FFI_EXPORT
void mbw_x11_context_destroy(uint64_t raw_context);

// ---------------------------------------------------------------- utilities

static void emit_window(int32_t kind, int32_t raw_id, int32_t arg0,
                        int32_t arg1, int32_t arg2, double argd) {
  if (g_x11_window_trampoline && g_x11_window_closure) {
    g_x11_window_trampoline(g_x11_window_closure, kind, raw_id, arg0, arg1,
                            arg2, argd);
  }
}

static void emit_input(int32_t raw_id, int32_t kind, int32_t arg0,
                       int32_t arg1, int32_t arg2, int64_t argi) {
  if (g_x11_input_trampoline && g_x11_input_closure) {
    g_x11_input_trampoline(g_x11_input_closure, raw_id, kind, arg0, arg1,
                           arg2, argi);
  }
}

static mbw_x11_window_t *window_from_raw(uint64_t raw_window) {
  if (raw_window < 4096) {
    return NULL;
  }
  mbw_x11_window_t *window = (mbw_x11_window_t *)(uintptr_t)raw_window;
  if (window->backend != MBW_BACKEND_TAG_X11) {
    return NULL;
  }
  return window;
}

static mbw_x11_context_t *context_from_raw(uint64_t raw_context) {
  if (raw_context < 4096) {
    return NULL;
  }
  mbw_x11_context_t *context = (mbw_x11_context_t *)(uintptr_t)raw_context;
  if (context->backend != MBW_BACKEND_TAG_X11) {
    return NULL;
  }
  return context;
}

static mbw_x11_window_t *window_for_xwindow(mbw_x11_context_t *context,
                                            Window xwindow) {
  mbw_x11_window_t *window = context->windows;
  while (window) {
    if (window->xwindow == xwindow) {
      return window;
    }
    window = window->next;
  }
  return NULL;
}

static void unlink_window(mbw_x11_context_t *context,
                          mbw_x11_window_t *target) {
  mbw_x11_window_t **link = &context->windows;
  while (*link) {
    if (*link == target) {
      *link = target->next;
      return;
    }
    link = &(*link)->next;
  }
}

static char *copy_bytes(const uint8_t *bytes, int32_t len,
                        const char *fallback) {
  if (!bytes || len <= 0) {
    return fallback ? strdup(fallback) : NULL;
  }
  char *out = (char *)malloc((size_t)len + 1);
  if (!out) {
    return NULL;
  }
  memcpy(out, bytes, (size_t)len);
  out[len] = '\0';
  return out;
}

static moonbit_bytes_t bytes_from_buffer(const char *data, size_t len) {
  if (!data || len == 0) {
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)len, 0);
  memcpy(bytes, data, len);
  return bytes;
}

static int x11_error_handler(Display *display, XErrorEvent *event) {
  // Benign races (destroyed windows during clipboard traffic, resize during
  // map) surface as X errors; swallow them instead of aborting the process.
  (void)display;
  (void)event;
  return 0;
}

// ------------------------------------------------------------- presentation

static void release_present_buffer(mbw_x11_context_t *context,
                                   mbw_x11_window_t *window,
                                   mbw_x11_present_buffer_t *buffer) {
  if (buffer->image) {
    buffer->image->data = NULL; // data is owned by us or by the shm segment
    XDestroyImage(buffer->image);
    buffer->image = NULL;
  }
  if (buffer->shm) {
    if (buffer->shm->shmid >= 0) {
      shmctl(buffer->shm->shmid, IPC_RMID, NULL);
    }
    if (buffer->shm->shmaddr) {
      shmdt(buffer->shm->shmaddr);
    }
    free(buffer->shm);
    buffer->shm = NULL;
  }
  buffer->busy = 0;
  (void)context;
  (void)window;
}

static int create_present_buffer(mbw_x11_context_t *context,
                                 mbw_x11_window_t *window,
                                 mbw_x11_present_buffer_t *buffer,
                                 int32_t width, int32_t height) {
  release_present_buffer(context, window, buffer);
  XShmSegmentInfo *shm = NULL;
  if (context->shm_supported) {
    shm = (XShmSegmentInfo *)calloc(1, sizeof(XShmSegmentInfo));
    if (!shm) {
      return MBW_X11_PRESENT_ALLOC_FAILED;
    }
    shm->shmid = -1;
    shm->shmaddr = NULL;
    XImage *image =
        XShmCreateImage(context->display, window->visual, window->depth,
                        ZPixmap, NULL, shm, width, height);
    if (!image) {
      free(shm);
      return MBW_X11_PRESENT_ALLOC_FAILED;
    }
    size_t size = (size_t)image->bytes_per_line * (size_t)height;
    shm->shmid =
        shmget(IPC_PRIVATE, size, IPC_CREAT | 0600);
    if (shm->shmid < 0) {
      XDestroyImage(image);
      free(shm);
      // Fall back to the non-shm path on shmget failure (e.g. /dev/shm
      // restrictions) instead of failing the whole present pipeline.
      context->shm_supported = 0;
      return create_present_buffer(context, window, buffer, width, height);
    }
    shm->shmaddr = (char *)shmat(shm->shmid, NULL, 0);
    if (shm->shmaddr == (char *)-1) {
      shm->shmaddr = NULL;
      shmctl(shm->shmid, IPC_RMID, NULL);
      XDestroyImage(image);
      free(shm);
      context->shm_supported = 0;
      return create_present_buffer(context, window, buffer, width, height);
    }
    image->data = shm->shmaddr;
    shm->readOnly = False;
    if (!XShmAttach(context->display, shm)) {
      XDestroyImage(image);
      shmdt(shm->shmaddr);
      shm->shmaddr = NULL;
      shmctl(shm->shmid, IPC_RMID, NULL);
      free(shm);
      context->shm_supported = 0;
      return create_present_buffer(context, window, buffer, width, height);
    }
    buffer->image = image;
    buffer->shm = shm;
    buffer->busy = 0;
    XSync(context->display, False);
    return MBW_X11_PRESENT_OK;
  }
  size_t size = (size_t)width * 4 * (size_t)height;
  char *data = (char *)malloc(size);
  if (!data) {
    return MBW_X11_PRESENT_ALLOC_FAILED;
  }
  XImage *image = XCreateImage(context->display, window->visual, window->depth,
                               ZPixmap, 0, data, width, height, 32,
                               width * 4);
  if (!image) {
    free(data);
    return MBW_X11_PRESENT_ALLOC_FAILED;
  }
  image->byte_order = LSBFirst;
  buffer->image = image;
  buffer->shm = NULL;
  buffer->busy = 0;
  return MBW_X11_PRESENT_OK;
}

// Convert a packed RGBA8 source into the XImage layout (BGRA on every
// little-endian X server) honoring the image's row stride.
static void fill_present_buffer(mbw_x11_window_t *window,
                                mbw_x11_present_buffer_t *buffer,
                                int32_t width, int32_t height,
                                int32_t row_bytes, const uint8_t *pixels) {
  int32_t dst_stride = buffer->image->bytes_per_line;
  uint8_t *dst_base = (uint8_t *)buffer->image->data;
  for (int32_t y = 0; y < height; ++y) {
    const uint8_t *src = pixels + (size_t)y * (size_t)row_bytes;
    uint8_t *dst = dst_base + (size_t)y * (size_t)dst_stride;
    for (int32_t x = 0; x < width; ++x) {
      size_t offset = (size_t)x * 4;
      dst[offset] = src[offset + 2];
      dst[offset + 1] = src[offset + 1];
      dst[offset + 2] = src[offset];
      dst[offset + 3] = src[offset + 3];
    }
  }
  (void)window;
}

// ------------------------------------------------------------- monitors

static void refresh_monitors(mbw_x11_context_t *context) {
  while (context->monitors) {
    mbw_x11_monitor_t *next = context->monitors->next;
    free(context->monitors);
    context->monitors = next;
  }
  XRRScreenResources *resources =
      XRRGetScreenResourcesCurrent(context->display, context->root);
  if (!resources) {
    return;
  }
  RROutput primary = XRRGetOutputPrimary(context->display, context->root);
  mbw_x11_monitor_t *head = NULL;
  mbw_x11_monitor_t *primary_entry = NULL;
  for (int i = 0; i < resources->noutput; ++i) {
    RROutput output = resources->outputs[i];
    XRROutputInfo *info = XRRGetOutputInfo(context->display, resources, output);
    if (!info || info->connection != RR_Connected || info->crtc == None) {
      if (info) {
        XRRFreeOutputInfo(info);
      }
      continue;
    }
    XRRCrtcInfo *crtc = XRRGetCrtcInfo(context->display, resources, info->crtc);
    if (!crtc) {
      XRRFreeOutputInfo(info);
      continue;
    }
    mbw_x11_monitor_t *monitor =
        (mbw_x11_monitor_t *)calloc(1, sizeof(mbw_x11_monitor_t));
    if (monitor) {
      monitor->output = output;
      monitor->x = (int32_t)crtc->x;
      monitor->y = (int32_t)crtc->y;
      monitor->width = (int32_t)crtc->width;
      monitor->height = (int32_t)crtc->height;
      monitor->scale = 1.0;
      snprintf(monitor->name, sizeof(monitor->name), "%s",
               info->name && info->name[0] ? info->name : "X11 display");
      // Stable order: primary output first, remaining in enumeration order.
      if (output == primary) {
        monitor->next = head;
        head = monitor;
        primary_entry = monitor;
      } else if (primary_entry) {
        monitor->next = primary_entry->next;
        primary_entry->next = monitor;
      } else {
        monitor->next = head;
        head = monitor;
      }
    }
    XRRFreeCrtcInfo(crtc);
    XRRFreeOutputInfo(info);
  }
  XRRFreeScreenResources(resources);
  context->monitors = head;
  if (!context->monitors) {
    // No usable XRandR outputs (or XRandR missing): fall back to the root
    // geometry as a single monitor so monitor APIs remain functional.
    mbw_x11_monitor_t *monitor =
        (mbw_x11_monitor_t *)calloc(1, sizeof(mbw_x11_monitor_t));
    if (monitor) {
      Screen *screen = ScreenOfDisplay(context->display, context->screen);
      monitor->output = (RROutput)1;
      monitor->width = (int32_t)WidthOfScreen(screen);
      monitor->height = (int32_t)HeightOfScreen(screen);
      monitor->scale = 1.0;
      snprintf(monitor->name, sizeof(monitor->name), "X11 display");
      context->monitors = monitor;
    }
  }
}

static mbw_x11_monitor_t *monitor_at(mbw_x11_context_t *context,
                                     int32_t index) {
  if (!context || index < 0) {
    return NULL;
  }
  mbw_x11_monitor_t *monitor = context->monitors;
  for (int32_t i = 0; monitor && i < index; ++i) {
    monitor = monitor->next;
  }
  return monitor;
}

static mbw_x11_monitor_t *monitor_for_window(mbw_x11_context_t *context,
                                             mbw_x11_window_t *window) {
  if (!context || !window) {
    return NULL;
  }
  int32_t rx = 0;
  int32_t ry = 0;
  Window child = None;
  if (XTranslateCoordinates(context->display, window->xwindow, context->root,
                            window->width / 2, window->height / 2, &rx, &ry,
                            &child)) {
    mbw_x11_monitor_t *monitor = context->monitors;
    while (monitor) {
      if (rx >= monitor->x && rx < monitor->x + monitor->width &&
          ry >= monitor->y && ry < monitor->y + monitor->height) {
        return monitor;
      }
      monitor = monitor->next;
    }
  }
  return context->monitors;
}

// ------------------------------------------------------------ event handling

static void send_net_wm_state(mbw_x11_context_t *context,
                              mbw_x11_window_t *window, Atom first, Atom second,
                              long action) {
  XClientMessageEvent event;
  memset(&event, 0, sizeof(event));
  event.type = ClientMessage;
  event.display = context->display;
  event.window = window->xwindow;
  event.message_type = context->net_wm_state;
  event.format = 32;
  event.data.l[0] = action;
  event.data.l[1] = (long)first;
  event.data.l[2] = (long)second;
  event.data.l[3] = 1; // source indication: normal application
  XSendEvent(context->display, context->root, False,
             SubstructureRedirectMask | SubstructureNotifyMask,
             (XEvent *)&event);
  XFlush(context->display);
}

static void handle_client_message(mbw_x11_context_t *context,
                                  XClientMessageEvent *event) {
  if (event->message_type == context->wm_protocols) {
    Atom protocol = (Atom)event->data.l[0];
    if (protocol == context->wm_delete_window) {
      mbw_x11_window_t *window = window_for_xwindow(context, event->window);
      if (window) {
        emit_window(MBW_LINUX_EVENT_CLOSE, window->raw_id, 0, 0, 0, 0.0);
      }
      return;
    }
    if (protocol == context->wm_take_focus) {
      Time time = (Time)event->data.l[1];
      mbw_x11_window_t *window = window_for_xwindow(context, event->window);
      if (window) {
        XSetInputFocus(context->display, window->xwindow, RevertToParent,
                       time ? time : CurrentTime);
      }
      return;
    }
  }
}

static void serve_selection_request(mbw_x11_context_t *context,
                                    XSelectionRequestEvent *request) {
  XSelectionEvent notify;
  memset(&notify, 0, sizeof(notify));
  notify.type = SelectionNotify;
  notify.display = request->display;
  notify.requestor = request->requestor;
  notify.selection = request->selection;
  notify.target = request->target;
  notify.time = request->time;
  notify.property = request->property;
  if (request->property == None) {
    request->property = request->target;
    notify.property = request->property;
  }
  if (request->target == context->targets) {
    Atom supported[3];
    supported[0] = context->targets;
    supported[1] = context->utf8_string;
    supported[2] = XA_STRING;
    XChangeProperty(context->display, request->requestor, request->property,
                    XA_ATOM, 32, PropModeReplace,
                    (unsigned char *)supported,
                    (int)(sizeof(supported) / sizeof(supported[0])));
  } else if (request->target == context->utf8_string ||
             request->target == XA_STRING ||
             request->target == context->text_plain) {
    if (context->owned_text) {
      XChangeProperty(context->display, request->requestor, request->property,
                      request->target, 8, PropModeReplace,
                      (unsigned char *)context->owned_text,
                      (int)context->owned_text_len);
    } else {
      notify.property = None;
    }
  } else {
    notify.property = None;
  }
  XSendEvent(context->display, request->requestor, False, 0, (XEvent *)&notify);
  XFlush(context->display);
}

static void read_selection_property(mbw_x11_context_t *context,
                                    Window requestor, Atom property) {
  if (property == None) {
    return;
  }
  Atom actual_type = None;
  int actual_format = 0;
  unsigned long nitems = 0;
  unsigned long bytes_after = 0;
  unsigned char *data = NULL;
  int status = XGetWindowProperty(context->display, requestor, property, 0,
                                  0x1000000, False, AnyPropertyType,
                                  &actual_type, &actual_format, &nitems,
                                  &bytes_after, &data);
  if (status == Success && data && actual_format == 8 &&
      actual_type != None && nitems > 0) {
    // Incremental (INCR) transfers are not supported in this slice; a partial
    // read returns whatever arrived so callers degrade to empty text.
    if (context->selection_data) {
      XFree(context->selection_data);
    }
    context->selection_data = (char *)data;
    context->selection_len = (size_t)nitems;
  } else if (data) {
    XFree(data);
  }
}

static void x11_handle_event(mbw_x11_context_t *context, XEvent *event) {
  switch (event->type) {
    case MapNotify: {
      mbw_x11_window_t *window =
          window_for_xwindow(context, event->xmap.window);
      if (window) {
        window->mapped = 1;
      }
      break;
    }
    case UnmapNotify: {
      mbw_x11_window_t *window =
          window_for_xwindow(context, event->xunmap.window);
      if (window) {
        window->mapped = 0;
      }
      break;
    }
    case ConfigureNotify: {
      mbw_x11_window_t *window =
          window_for_xwindow(context, event->xconfigure.window);
      if (window) {
        int32_t width = (int32_t)event->xconfigure.width;
        int32_t height = (int32_t)event->xconfigure.height;
        if (width > 0 && height > 0 &&
            (width != window->width || height != window->height)) {
          window->width = width;
          window->height = height;
          emit_window(MBW_LINUX_EVENT_CONFIGURE, window->raw_id, width, height,
                      0, 0.0);
        }
      }
      break;
    }
    case Expose: {
      mbw_x11_window_t *window =
          window_for_xwindow(context, event->xexpose.window);
      if (window && event->xexpose.count == 0) {
        emit_window(MBW_LINUX_EVENT_REDRAW, window->raw_id, 0, 0, 0, 0.0);
      }
      break;
    }
    case FocusIn:
    case FocusOut: {
      if (event->xfocus.mode == NotifyNormal) {
        mbw_x11_window_t *window =
            window_for_xwindow(context, event->xfocus.window);
        if (window) {
          int focused = event->type == FocusIn;
          window->focused = focused;
          emit_window(MBW_LINUX_EVENT_FOCUS, window->raw_id, focused ? 1 : 0,
                      0, 0, 0.0);
        }
      }
      break;
    }
    case ClientMessage:
      handle_client_message(context, &event->xclient);
      break;
    case DestroyNotify: {
      mbw_x11_window_t *window =
          window_for_xwindow(context, event->xdestroywindow.window);
      if (window && !window->destroy_requested) {
        emit_window(MBW_LINUX_EVENT_DESTROYED, window->raw_id, 0, 0, 0, 0.0);
        if (context->pointer_window == window) {
          context->pointer_window = NULL;
        }
        unlink_window(context, window);
        free(window);
      }
      break;
    }
    case MotionNotify: {
      mbw_x11_window_t *window =
          window_for_xwindow(context, event->xmotion.window);
      if (window) {
        context->pointer_window = window;
        emit_input(window->raw_id, MBW_LINUX_INPUT_POINTER_MOVE,
                   (int32_t)event->xmotion.x, (int32_t)event->xmotion.y, 0, 0);
      }
      break;
    }
    case EnterNotify: {
      if (event->xcrossing.mode != NotifyGrab &&
          event->xcrossing.mode != NotifyUngrab) {
        mbw_x11_window_t *window =
            window_for_xwindow(context, event->xcrossing.window);
        if (window) {
          context->pointer_window = window;
          emit_input(window->raw_id, MBW_LINUX_INPUT_POINTER_ENTER,
                     (int32_t)event->xcrossing.x, (int32_t)event->xcrossing.y,
                     0, 0);
        }
      }
      break;
    }
    case LeaveNotify: {
      if (event->xcrossing.mode != NotifyGrab &&
          event->xcrossing.mode != NotifyUngrab) {
        mbw_x11_window_t *window =
            window_for_xwindow(context, event->xcrossing.window);
        if (window) {
          emit_input(window->raw_id, MBW_LINUX_INPUT_POINTER_LEAVE, 0, 0, 0, 0);
        }
      }
      break;
    }
    case ButtonPress:
    case ButtonRelease: {
      mbw_x11_window_t *window =
          window_for_xwindow(context, event->xbutton.window);
      if (!window) {
        break;
      }
      context->pointer_window = window;
      unsigned int button = event->xbutton.button;
      if (event->type == ButtonPress && button >= 4 && button <= 7) {
        int32_t dx = 0;
        int32_t dy = 0;
        // X11 wheel buttons: 4=up, 5=down, 6=left, 7=right. Vertical deltas
        // follow the shared convention (positive = upward scroll).
        if (button == 4) {
          dy = MBW_X11_WHEEL_STEP_PX;
        } else if (button == 5) {
          dy = -MBW_X11_WHEEL_STEP_PX;
        } else if (button == 6) {
          dx = -MBW_X11_WHEEL_STEP_PX;
        } else {
          dx = MBW_X11_WHEEL_STEP_PX;
        }
        emit_input(window->raw_id, MBW_LINUX_INPUT_WHEEL, dx, dy, 0, 0);
        break;
      }
      int32_t code = 0;
      switch (button) {
        case 1: code = 0x110; break; // BTN_LEFT
        case 2: code = 0x112; break; // BTN_MIDDLE
        case 3: code = 0x111; break; // BTN_RIGHT
        case 8: code = 0x113; break; // BTN_SIDE (back)
        case 9: code = 0x114; break; // BTN_EXTRA (forward)
        default: break;
      }
      if (code != 0) {
        emit_input(window->raw_id,
                   event->type == ButtonPress ? MBW_LINUX_INPUT_POINTER_DOWN
                                              : MBW_LINUX_INPUT_POINTER_UP,
                   (int32_t)event->xbutton.x, (int32_t)event->xbutton.y, code,
                   0);
      }
      break;
    }
    case KeyPress:
    case KeyRelease: {
      mbw_x11_window_t *window =
          window_for_xwindow(context, event->xkey.window);
      if (window) {
        int32_t evdev_code =
            (int32_t)event->xkey.keycode - MBW_X11_KEYCODE_EVDEV_OFFSET;
        if (evdev_code > 0) {
          emit_input(window->raw_id,
                     event->type == KeyPress ? MBW_LINUX_INPUT_KEY_DOWN
                                             : MBW_LINUX_INPUT_KEY_UP,
                     0, 0, 0, (int64_t)evdev_code);
        }
      }
      break;
    }
    case SelectionRequest:
      if (context->owns_clipboard) {
        serve_selection_request(context, &event->xselectionrequest);
      }
      break;
    case SelectionClear:
      if (event->xselectionclear.selection == context->clipboard) {
        context->owns_clipboard = 0;
      }
      break;
    case SelectionNotify: {
      if (event->xselection.requestor == context->request_window) {
        read_selection_property(context, context->request_window,
                                event->xselection.property);
        context->selection_done = 1;
      }
      break;
    }
    default:
      break;
  }
}

static int32_t process_queued_events(mbw_x11_context_t *context) {
  int32_t processed = 0;
  while (XPending(context->display) > 0) {
    XEvent event;
    XNextEvent(context->display, &event);
    x11_handle_event(context, &event);
    processed++;
  }
  return processed;
}

static void drain_wake_pipe(mbw_x11_context_t *context) {
  char buffer[64];
  while (read(context->wake_pipe[0], buffer, sizeof(buffer)) > 0) {
    // Drain until non-blocking read reports empty.
  }
}

// ------------------------------------------------------------ context setup

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_context_new(void) {
  mbw_x11_context_t *context =
      (mbw_x11_context_t *)calloc(1, sizeof(mbw_x11_context_t));
  if (!context) {
    return 0;
  }
  context->backend = MBW_BACKEND_TAG_X11;
  context->wake_pipe[0] = -1;
  context->wake_pipe[1] = -1;
  context->display = XOpenDisplay(NULL);
  if (!context->display) {
    free(context);
    return 0;
  }
  XSetErrorHandler(x11_error_handler);
  context->screen = DefaultScreen(context->display);
  context->root = RootWindow(context->display, context->screen);
  if (pipe2(context->wake_pipe, O_CLOEXEC | O_NONBLOCK) != 0) {
    context->wake_pipe[0] = -1;
    context->wake_pipe[1] = -1;
  }
  context->wm_protocols = XInternAtom(context->display, "WM_PROTOCOLS", False);
  context->wm_delete_window =
      XInternAtom(context->display, "WM_DELETE_WINDOW", False);
  context->wm_take_focus = XInternAtom(context->display, "WM_TAKE_FOCUS", False);
  context->net_wm_name = XInternAtom(context->display, "_NET_WM_NAME", False);
  context->net_wm_state =
      XInternAtom(context->display, "_NET_WM_STATE", False);
  context->net_wm_state_maximized_vert = XInternAtom(
      context->display, "_NET_WM_STATE_MAXIMIZED_VERT", False);
  context->net_wm_state_maximized_horz = XInternAtom(
      context->display, "_NET_WM_STATE_MAXIMIZED_HORZ", False);
  context->net_wm_state_fullscreen =
      XInternAtom(context->display, "_NET_WM_STATE_FULLSCREEN", False);
  context->motif_wm_hints =
      XInternAtom(context->display, "_MOTIF_WM_HINTS", False);
  context->utf8_string = XInternAtom(context->display, "UTF8_STRING", False);
  context->clipboard = XInternAtom(context->display, "CLIPBOARD", False);
  context->targets = XInternAtom(context->display, "TARGETS", False);
  context->selection_property =
      XInternAtom(context->display, "MOUI_CLIPBOARD", False);
  context->text_plain = XInternAtom(context->display, "TEXT", False);
  int shm_major = 0;
  int shm_minor = 0;
  Bool shm_pixmaps = False;
  context->shm_supported = XShmQueryExtension(context->display) &&
                           XShmQueryVersion(context->display, &shm_major,
                                            &shm_minor, &shm_pixmaps);
  context->shm_event_base = XShmGetEventBase(context->display);
  refresh_monitors(context);
  return (uint64_t)(uintptr_t)context;
}

MOONBIT_FFI_EXPORT
void mbw_x11_context_destroy(uint64_t raw_context) {
  mbw_x11_context_t *context =
      (mbw_x11_context_t *)(uintptr_t)raw_context;
  if (!context || context->backend != MBW_BACKEND_TAG_X11) {
    return;
  }
  while (context->windows) {
    mbw_x11_window_t *window = context->windows;
    context->windows = window->next;
    release_present_buffer(context, window, &window->buffers[0]);
    release_present_buffer(context, window, &window->buffers[1]);
    if (window->gc) {
      XFreeGC(context->display, window->gc);
    }
    if (window->xwindow && !window->destroyed) {
      XDestroyWindow(context->display, window->xwindow);
    }
    free(window);
  }
  while (context->monitors) {
    mbw_x11_monitor_t *monitor = context->monitors;
    context->monitors = monitor->next;
    free(monitor);
  }
  if (context->selection_data) {
    XFree(context->selection_data);
    context->selection_data = NULL;
  }
  free(context->owned_text);
  context->owned_text = NULL;
  if (context->request_window) {
    XDestroyWindow(context->display, context->request_window);
    context->request_window = None;
  }
  if (context->display) {
    XCloseDisplay(context->display);
    context->display = NULL;
  }
  if (context->wake_pipe[0] >= 0) {
    close(context->wake_pipe[0]);
  }
  if (context->wake_pipe[1] >= 0) {
    close(context->wake_pipe[1]);
  }
  free(context);
}

// ----------------------------------------------------------------- monitors

MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_count(uint64_t raw_context) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  if (!context) {
    return 0;
  }
  refresh_monitors(context);
  int32_t count = 0;
  mbw_x11_monitor_t *monitor = context->monitors;
  while (monitor) {
    count++;
    monitor = monitor->next;
  }
  return count;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_monitor_handle_at(uint64_t raw_context, int32_t index) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  mbw_x11_monitor_t *monitor = monitor_at(context, index);
  return monitor ? (uint64_t)monitor->output : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_rect_left_at(uint64_t raw_context, int32_t index) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  mbw_x11_monitor_t *monitor = monitor_at(context, index);
  return monitor ? monitor->x : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_rect_top_at(uint64_t raw_context, int32_t index) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  mbw_x11_monitor_t *monitor = monitor_at(context, index);
  return monitor ? monitor->y : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_rect_width_at(uint64_t raw_context, int32_t index) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  mbw_x11_monitor_t *monitor = monitor_at(context, index);
  return monitor && monitor->width > 0 ? monitor->width : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_rect_height_at(uint64_t raw_context, int32_t index) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  mbw_x11_monitor_t *monitor = monitor_at(context, index);
  return monitor && monitor->height > 0 ? monitor->height : 0;
}

MOONBIT_FFI_EXPORT
double mbw_x11_monitor_scale_factor_at(uint64_t raw_context, int32_t index) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  mbw_x11_monitor_t *monitor = monitor_at(context, index);
  return monitor && monitor->scale > 0.0 ? monitor->scale : 1.0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_x11_monitor_name_bytes_at(uint64_t raw_context,
                                              int32_t index) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  mbw_x11_monitor_t *monitor = monitor_at(context, index);
  if (!monitor || !monitor->name[0]) {
    return moonbit_make_bytes(0, 0);
  }
  return bytes_from_buffer(monitor->name, strlen(monitor->name));
}

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_current_monitor_handle(uint64_t raw_window) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window) {
    return 0;
  }
  mbw_x11_monitor_t *monitor =
      monitor_for_window((mbw_x11_context_t *)window->context, window);
  return monitor ? (uint64_t)monitor->output : 0;
}

// -------------------------------------------------------------- event loop

MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_dispatch(uint64_t raw_context, int32_t timeout_ms) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  if (!context || !context->display) {
    return -1;
  }
  int32_t processed = process_queued_events(context);
  if (timeout_ms == 0 || processed > 0) {
    return processed;
  }
  struct pollfd fds[2];
  fds[0].fd = ConnectionNumber(context->display);
  fds[0].events = POLLIN;
  fds[0].revents = 0;
  int fd_count = 1;
  if (context->wake_pipe[0] >= 0) {
    fds[1].fd = context->wake_pipe[0];
    fds[1].events = POLLIN;
    fds[1].revents = 0;
    fd_count = 2;
  }
  int ready = poll(fds, fd_count, timeout_ms);
  if (ready < 0) {
    return errno == EINTR ? 0 : -1;
  }
  if (fd_count == 2 && (fds[1].revents & POLLIN)) {
    drain_wake_pipe(context);
    emit_window(MBW_LINUX_EVENT_PROXY_WAKE, 0, 0, 0, 0, 0.0);
    processed++;
  }
  if (fds[0].revents & POLLIN) {
    processed += process_queued_events(context);
  }
  return processed;
}

MOONBIT_FFI_EXPORT
void mbw_x11_context_wake(uint64_t raw_context) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  if (!context || context->wake_pipe[1] < 0) {
    return;
  }
  char value = 1;
  ssize_t written = write(context->wake_pipe[1], &value, sizeof(value));
  (void)written;
}

// ------------------------------------------------------------------ window

static Window ensure_request_window(mbw_x11_context_t *context) {
  if (context->request_window) {
    return context->request_window;
  }
  XSetWindowAttributes attributes;
  memset(&attributes, 0, sizeof(attributes));
  attributes.override_redirect = True;
  attributes.event_mask = PropertyChangeMask;
  context->request_window =
      XCreateWindow(context->display, context->root, -1, -1, 1, 1, 0,
                    CopyFromParent, InputOnly, CopyFromParent,
                    CWOverrideRedirect | CWEventMask, &attributes);
  return context->request_window;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_create(uint64_t raw_context, int32_t raw_id,
                               int32_t width, int32_t height,
                               const uint8_t *title, int32_t title_len,
                               const uint8_t *app_id, int32_t app_id_len,
                               int decorations, int use_shm_placeholder) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  if (!context || !context->display) {
    return 0;
  }
  (void)use_shm_placeholder; // X11 uses WM decorations; no client placeholder
  mbw_x11_window_t *window =
      (mbw_x11_window_t *)calloc(1, sizeof(mbw_x11_window_t));
  if (!window) {
    return 0;
  }
  window->backend = MBW_BACKEND_TAG_X11;
  window->context = context;
  window->raw_id = raw_id;
  window->width = width > 0 ? width : 1;
  window->height = height > 0 ? height : 1;
  // Prefer a 32-bit ARGB visual so window content can carry alpha; fall back
  // to the default visual (24-bit) when the server does not expose one.
  XVisualInfo visual_template;
  memset(&visual_template, 0, sizeof(visual_template));
  visual_template.screen = context->screen;
  visual_template.depth = 32;
  visual_template.class = TrueColor;
  int visual_count = 0;
  XVisualInfo *visual_info = XGetVisualInfo(context->display,
                                            VisualScreenMask | VisualDepthMask |
                                                VisualClassMask,
                                            &visual_template, &visual_count);
  Visual *visual = NULL;
  int32_t depth = 0;
  Colormap colormap = None;
  unsigned long attribute_mask = CWEventMask;
  XSetWindowAttributes attributes;
  memset(&attributes, 0, sizeof(attributes));
  attributes.event_mask = ExposureMask | StructureNotifyMask |
                          FocusChangeMask | PointerMotionMask |
                          ButtonPressMask | ButtonReleaseMask |
                          EnterWindowMask | LeaveWindowMask | KeyPressMask |
                          KeyReleaseMask | PropertyChangeMask;
  if (visual_info) {
    visual = visual_info[0].visual;
    depth = 32;
    colormap = XCreateColormap(context->display, context->root, visual,
                               AllocNone);
    attributes.colormap = colormap;
    attributes.background_pixel = 0;
    attributes.border_pixel = 0;
    attribute_mask |= CWColormap | CWBackPixel | CWBorderPixel;
  } else {
    visual = DefaultVisual(context->display, context->screen);
    depth = (int32_t)DefaultDepth(context->display, context->screen);
    attributes.background_pixel =
        BlackPixel(context->display, context->screen);
    attributes.border_pixel = 0;
    attribute_mask |= CWBackPixel | CWBorderPixel;
  }
  window->visual = visual;
  window->depth = depth;
  window->xwindow = XCreateWindow(
      context->display, context->root, 0, 0, (unsigned int)window->width,
      (unsigned int)window->height, 0, (unsigned int)depth, InputOutput,
      visual, attribute_mask, &attributes);
  if (visual_info) {
    XFree(visual_info);
  }
  if (!window->xwindow) {
    if (colormap != None) {
      XFreeColormap(context->display, colormap);
    }
    free(window);
    return 0;
  }
  window->gc = XCreateGC(context->display, window->xwindow, 0, NULL);
  XSetWMProtocols(context->display, window->xwindow,
                  (Atom[]){context->wm_delete_window, context->wm_take_focus},
                  2);
  char *title_c = copy_bytes(title, title_len, "MoonBit window");
  if (title_c) {
    XStoreName(context->display, window->xwindow, title_c);
    XChangeProperty(context->display, window->xwindow, context->net_wm_name,
                    context->utf8_string, 8, PropModeReplace,
                    (unsigned char *)title_c, (int)strlen(title_c));
    free(title_c);
  }
  char *app_id_c = copy_bytes(app_id, app_id_len, "Milky2018.window");
  if (app_id_c) {
    XClassHint *class_hint = XAllocClassHint();
    if (class_hint) {
      class_hint->res_name = app_id_c;
      class_hint->res_class = app_id_c;
      XSetClassHint(context->display, window->xwindow, class_hint);
      XFree(class_hint);
    }
    free(app_id_c);
  }
  // _MOTIF_WM_HINTS: flags=2 (MWM_HINTS_DECORATIONS), decorations all/none.
  {
    unsigned long hints[5];
    memset(hints, 0, sizeof(hints));
    hints[0] = 2;
    hints[2] = decorations ? 1 : 0;
    XChangeProperty(context->display, window->xwindow, context->motif_wm_hints,
                    context->motif_wm_hints, 32, PropModeReplace,
                    (unsigned char *)hints, 5);
  }
  window->next = context->windows;
  context->windows = window;
  XFlush(context->display);
  return (uint64_t)(uintptr_t)window;
}

MOONBIT_FFI_EXPORT
void mbw_x11_window_destroy(uint64_t raw_window) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window) {
    return;
  }
  mbw_x11_context_t *context = (mbw_x11_context_t *)window->context;
  // Mirror the Wayland backend: the destroyed event is emitted synchronously
  // during an explicit destroy so hosts can observe the teardown.
  emit_window(MBW_LINUX_EVENT_DESTROYED, window->raw_id, 0, 0, 0, 0.0);
  window->destroy_requested = 1;
  if (context && context->display && window->xwindow) {
    XDestroyWindow(context->display, window->xwindow);
    XFlush(context->display);
  }
  if (context && context->pointer_window == window) {
    context->pointer_window = NULL;
  }
  if (context) {
    unlink_window(context, window);
  }
  release_present_buffer(context, window, &window->buffers[0]);
  release_present_buffer(context, window, &window->buffers[1]);
  if (context && context->display && window->gc) {
    XFreeGC(context->display, window->gc);
  }
  free(window);
}

MOONBIT_FFI_EXPORT
Bool mbw_x11_window_wait_configured(uint64_t raw_window, int32_t timeout_ms) {
  (void)timeout_ms;
  mbw_x11_window_t *window = window_from_raw(raw_window);
  // X11 windows carry their geometry synchronously; there is no async
  // initial-configure handshake like Wayland's xdg_surface.
  return window && !window->destroyed;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_surface_handle(uint64_t raw_window) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  return window ? (uint64_t)window->xwindow : 0;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_xdg_surface_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_xdg_toplevel_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_display_handle(uint64_t raw_window) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window || !window->context) {
    return 0;
  }
  return (uint64_t)(uintptr_t)window->context->display;
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_window_client_decorated(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}

MOONBIT_FFI_EXPORT
void mbw_x11_window_set_title(uint64_t raw_window, const uint8_t *title,
                              int32_t title_len) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window || !window->context) {
    return;
  }
  mbw_x11_context_t *context = (mbw_x11_context_t *)window->context;
  char *title_c = copy_bytes(title, title_len, "MoonBit window");
  if (!title_c) {
    return;
  }
  XStoreName(context->display, window->xwindow, title_c);
  XChangeProperty(context->display, window->xwindow, context->net_wm_name,
                  context->utf8_string, 8, PropModeReplace,
                  (unsigned char *)title_c, (int)strlen(title_c));
  free(title_c);
  XFlush(context->display);
}

MOONBIT_FFI_EXPORT
void mbw_x11_window_set_decorations(uint64_t raw_window, int decorations) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window || !window->context) {
    return;
  }
  mbw_x11_context_t *context = (mbw_x11_context_t *)window->context;
  unsigned long hints[5];
  memset(hints, 0, sizeof(hints));
  hints[0] = 2; // MWM_HINTS_DECORATIONS
  hints[2] = decorations ? 1 : 0;
  XChangeProperty(context->display, window->xwindow, context->motif_wm_hints,
                  context->motif_wm_hints, 32, PropModeReplace,
                  (unsigned char *)hints, 5);
  XFlush(context->display);
}

MOONBIT_FFI_EXPORT
void mbw_x11_window_set_minimized(uint64_t raw_window, int minimized) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window || !window->context) {
    return;
  }
  mbw_x11_context_t *context = (mbw_x11_context_t *)window->context;
  if (minimized) {
    XIconifyWindow(context->display, window->xwindow, context->screen);
    XFlush(context->display);
  }
}

MOONBIT_FFI_EXPORT
void mbw_x11_window_set_maximized(uint64_t raw_window, int maximized) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window || !window->context) {
    return;
  }
  mbw_x11_context_t *context = (mbw_x11_context_t *)window->context;
  send_net_wm_state(context, window, context->net_wm_state_maximized_vert,
                    context->net_wm_state_maximized_horz,
                    maximized ? 1 : 0);
}

MOONBIT_FFI_EXPORT
void mbw_x11_window_set_fullscreen(uint64_t raw_window, int fullscreen) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window || !window->context) {
    return;
  }
  mbw_x11_context_t *context = (mbw_x11_context_t *)window->context;
  send_net_wm_state(context, window, context->net_wm_state_fullscreen, None,
                    fullscreen ? 1 : 0);
}

MOONBIT_FFI_EXPORT
void mbw_x11_window_set_visible(uint64_t raw_window, int visible) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window || !window->context) {
    return;
  }
  mbw_x11_context_t *context = (mbw_x11_context_t *)window->context;
  if (visible) {
    XMapWindow(context->display, window->xwindow);
  } else {
    XUnmapWindow(context->display, window->xwindow);
  }
  XFlush(context->display);
}

MOONBIT_FFI_EXPORT
void mbw_x11_window_request_surface_size(uint64_t raw_window, int32_t width,
                                         int32_t height) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window || !window->context) {
    return;
  }
  if (width <= 0 || height <= 0) {
    return;
  }
  // Do not update the stored size here: the async ConfigureNotify carries the
  // authoritative geometry and must observe a change to emit the configure
  // event (window-manager may also adjust the request).
  mbw_x11_context_t *context = (mbw_x11_context_t *)window->context;
  XResizeWindow(context->display, window->xwindow, (unsigned int)width,
                (unsigned int)height);
  // Round-trip so the server processes the resize now: without a round-trip
  // boundary the server may coalesce the pending map and resize before event
  // delivery and never emit the ConfigureNotify the host waits on.
  XSync(context->display, False);
}

MOONBIT_FFI_EXPORT
void mbw_x11_window_request_redraw(uint64_t raw_window) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (window && window->context) {
    mbw_x11_context_wake((uint64_t)(uintptr_t)window->context);
  }
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_window_present_rgba_pixels(uint64_t raw_window,
                                           int32_t width, int32_t height,
                                           int32_t row_bytes,
                                           const uint8_t *pixels,
                                           int32_t pixels_len) {
  mbw_x11_window_t *window = window_from_raw(raw_window);
  if (!window || !window->context || !window->xwindow || !window->gc) {
    return MBW_X11_PRESENT_BAD_WINDOW;
  }
  if (width <= 0 || height <= 0 || width > INT32_MAX / 4) {
    return MBW_X11_PRESENT_BAD_DIMENSIONS;
  }
  int32_t packed_row_bytes = width * 4;
  if (row_bytes < packed_row_bytes || height > INT32_MAX / packed_row_bytes) {
    return MBW_X11_PRESENT_BAD_DIMENSIONS;
  }
  int64_t required_len = (int64_t)row_bytes * (int64_t)height;
  if (!pixels || required_len <= 0 || required_len > INT32_MAX ||
      pixels_len < required_len) {
    return MBW_X11_PRESENT_BAD_PIXELS;
  }
  mbw_x11_context_t *context = (mbw_x11_context_t *)window->context;
  mbw_x11_present_buffer_t *buffer = &window->buffers[window->current_buffer];
  if (!buffer->image || buffer->image->width != width ||
      buffer->image->height != height) {
    int status = create_present_buffer(context, window, buffer, width, height);
    if (status != MBW_X11_PRESENT_OK) {
      return status;
    }
  }
  fill_present_buffer(window, buffer, width, height, row_bytes, pixels);
  if (context->shm_supported && buffer->shm && !buffer->busy) {
    XShmPutImage(context->display, window->xwindow, window->gc, buffer->image,
                 0, 0, 0, 0, (unsigned int)width, (unsigned int)height, False);
    buffer->busy = 1;
    window->current_buffer = window->current_buffer == 0 ? 1 : 0;
  } else {
    // MIT-SHM completion still in flight, or MIT-SHM unavailable: XPutImage
    // copies the image into the protocol stream synchronously, so reuse is
    // safe once the call returns.
    XPutImage(context->display, window->xwindow, window->gc, buffer->image, 0,
              0, 0, 0, (unsigned int)width, (unsigned int)height);
  }
  XFlush(context->display);
  return MBW_X11_PRESENT_OK;
}

// ---------------------------------------------------------------- clipboard

MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_clipboard_available(uint64_t raw_context) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  return context && context->display ? 1 : 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_x11_context_clipboard_read_text(uint64_t raw_context) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  if (!context || !context->display) {
    return moonbit_make_bytes(0, 0);
  }
  if (context->owns_clipboard && context->owned_text &&
      context->owned_text_len > 0) {
    return bytes_from_buffer(context->owned_text, context->owned_text_len);
  }
  Window owner = XGetSelectionOwner(context->display, context->clipboard);
  if (owner == None) {
    // Fall back to our own last copy even when ownership moved on.
    if (context->owned_text && context->owned_text_len > 0) {
      return bytes_from_buffer(context->owned_text, context->owned_text_len);
    }
    return moonbit_make_bytes(0, 0);
  }
  Window request_window = ensure_request_window(context);
  if (!request_window) {
    return moonbit_make_bytes(0, 0);
  }
  XDeleteProperty(context->display, request_window,
                  context->selection_property);
  context->selection_done = 0;
  context->selection_pending = 1;
  XConvertSelection(context->display, context->clipboard,
                    context->utf8_string, context->selection_property,
                    request_window, CurrentTime);
  XFlush(context->display);
  // Nested bounded wait for SelectionNotify. Other events keep flowing
  // through the normal handler; the MoonBit runtime queues any callbacks that
  // arrive while it is already inside a handler (app_state event_handler_in_use).
  struct timespec start;
  clock_gettime(CLOCK_MONOTONIC, &start);
  const int64_t timeout_ns = 1000LL * 1000 * 1000;
  while (!context->selection_done) {
    if (XPending(context->display) > 0) {
      XEvent event;
      XNextEvent(context->display, &event);
      x11_handle_event(context, &event);
      continue;
    }
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    int64_t elapsed = (now.tv_sec - start.tv_sec) * 1000000000LL +
                      (now.tv_nsec - start.tv_nsec);
    if (elapsed >= timeout_ns) {
      break;
    }
    struct pollfd fds;
    fds.fd = ConnectionNumber(context->display);
    fds.events = POLLIN;
    fds.revents = 0;
    int remaining_ms = (int)((timeout_ns - elapsed) / 1000000LL) + 1;
    if (poll(&fds, 1, remaining_ms) <= 0 && errno != EINTR) {
      break;
    }
  }
  context->selection_pending = 0;
  moonbit_bytes_t result;
  if (context->selection_data && context->selection_len > 0) {
    result =
        bytes_from_buffer(context->selection_data, context->selection_len);
  } else {
    result = moonbit_make_bytes(0, 0);
  }
  if (context->selection_data) {
    XFree(context->selection_data);
    context->selection_data = NULL;
  }
  context->selection_len = 0;
  return result;
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_clipboard_write_text(uint64_t raw_context,
                                             const uint8_t *text,
                                             int32_t text_len) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  if (!context || !context->display) {
    return 0;
  }
  char *copy = copy_bytes(text, text_len, "");
  if (!copy) {
    return 0;
  }
  Window request_window = ensure_request_window(context);
  if (!request_window) {
    free(copy);
    return 0;
  }
  free(context->owned_text);
  context->owned_text = copy;
  context->owned_text_len = strlen(copy);
  context->owns_clipboard = 1;
  XSetSelectionOwner(context->display, context->clipboard, request_window,
                     CurrentTime);
  XFlush(context->display);
  return XGetSelectionOwner(context->display, context->clipboard) ==
                 request_window
             ? 1
             : 0;
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_drag_drop_available(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_x11_window_take_drag_paths(uint64_t raw_window) {
  (void)raw_window;
  return moonbit_make_bytes(0, 0);
}

// -------------------------------------------------------------- trampolines

MOONBIT_FFI_EXPORT
void mbw_x11_install_window_event_callback(
    mbw_window_event_trampoline_t trampoline, void *closure) {
  g_x11_window_trampoline = trampoline;
  g_x11_window_closure = closure;
}

MOONBIT_FFI_EXPORT
void mbw_x11_install_input_event_callback(
    mbw_input_event_trampoline_t trampoline, void *closure) {
  g_x11_input_trampoline = trampoline;
  g_x11_input_closure = closure;
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_system_theme_int(uint64_t raw_context) {
  (void)raw_context;
  return -1;
}

MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_wake_fd(uint64_t raw_context) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  return context ? context->wake_pipe[0] : -1;
}

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_context_display_handle(uint64_t raw_context) {
  mbw_x11_context_t *context = context_from_raw(raw_context);
  return context && context->display
             ? (uint64_t)(uintptr_t)context->display
             : 0;
}

#else

#include <moonbit.h>
#include <stdint.h>

MOONBIT_FFI_EXPORT
uint64_t mbw_x11_context_new(void) { return 0; }
MOONBIT_FFI_EXPORT
void mbw_x11_context_destroy(uint64_t raw_context) { (void)raw_context; }
MOONBIT_FFI_EXPORT
uint64_t mbw_x11_context_display_handle(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_wake_fd(uint64_t raw_context) {
  (void)raw_context;
  return -1;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_system_theme_int(uint64_t raw_context) {
  (void)raw_context;
  return -1;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_count(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_x11_monitor_handle_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_rect_left_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_rect_top_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_rect_width_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_monitor_rect_height_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 0;
}
MOONBIT_FFI_EXPORT
double mbw_x11_monitor_scale_factor_at(uint64_t raw_context, int32_t index) {
  (void)raw_context;
  (void)index;
  return 1.0;
}
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_x11_monitor_name_bytes_at(uint64_t raw_context,
                                              int32_t index) {
  (void)raw_context;
  (void)index;
  return moonbit_make_bytes(0, 0);
}
MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_current_monitor_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_dispatch(uint64_t raw_context, int32_t timeout_ms) {
  (void)raw_context;
  (void)timeout_ms;
  return -1;
}
MOONBIT_FFI_EXPORT
void mbw_x11_context_wake(uint64_t raw_context) { (void)raw_context; }
MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_create(uint64_t raw_context, int32_t raw_id,
                               int32_t width, int32_t height,
                               const uint8_t *title, int32_t title_len,
                               const uint8_t *app_id, int32_t app_id_len,
                               int decorations, int use_shm_placeholder) {
  (void)raw_context;
  (void)raw_id;
  (void)width;
  (void)height;
  (void)title;
  (void)title_len;
  (void)app_id;
  (void)app_id_len;
  (void)decorations;
  (void)use_shm_placeholder;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_window_wait_configured(uint64_t raw_window,
                                       int32_t timeout_ms) {
  (void)raw_window;
  (void)timeout_ms;
  return 0;
}
MOONBIT_FFI_EXPORT
void mbw_x11_window_destroy(uint64_t raw_window) { (void)raw_window; }
MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_surface_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_xdg_surface_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_xdg_toplevel_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
uint64_t mbw_x11_window_display_handle(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_window_client_decorated(uint64_t raw_window) {
  (void)raw_window;
  return 0;
}
MOONBIT_FFI_EXPORT
void mbw_x11_window_set_title(uint64_t raw_window, const uint8_t *title,
                              int32_t title_len) {
  (void)raw_window;
  (void)title;
  (void)title_len;
}
MOONBIT_FFI_EXPORT
void mbw_x11_window_set_decorations(uint64_t raw_window, int decorations) {
  (void)raw_window;
  (void)decorations;
}
MOONBIT_FFI_EXPORT
void mbw_x11_window_set_minimized(uint64_t raw_window, int minimized) {
  (void)raw_window;
  (void)minimized;
}
MOONBIT_FFI_EXPORT
void mbw_x11_window_set_maximized(uint64_t raw_window, int maximized) {
  (void)raw_window;
  (void)maximized;
}
MOONBIT_FFI_EXPORT
void mbw_x11_window_set_fullscreen(uint64_t raw_window, int fullscreen) {
  (void)raw_window;
  (void)fullscreen;
}
MOONBIT_FFI_EXPORT
void mbw_x11_window_set_visible(uint64_t raw_window, int visible) {
  (void)raw_window;
  (void)visible;
}
MOONBIT_FFI_EXPORT
void mbw_x11_window_request_surface_size(uint64_t raw_window, int32_t width,
                                         int32_t height) {
  (void)raw_window;
  (void)width;
  (void)height;
}
MOONBIT_FFI_EXPORT
void mbw_x11_window_request_redraw(uint64_t raw_window) {
  (void)raw_window;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_window_present_rgba_pixels(uint64_t raw_window,
                                           int32_t width, int32_t height,
                                           int32_t row_bytes,
                                           const uint8_t *pixels,
                                           int32_t pixels_len) {
  (void)raw_window;
  (void)width;
  (void)height;
  (void)row_bytes;
  (void)pixels;
  (void)pixels_len;
  return 1;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_clipboard_available(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_x11_context_clipboard_read_text(uint64_t raw_context) {
  (void)raw_context;
  return moonbit_make_bytes(0, 0);
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_clipboard_write_text(uint64_t raw_context,
                                             const uint8_t *text,
                                             int32_t text_len) {
  (void)raw_context;
  (void)text;
  (void)text_len;
  return 0;
}
MOONBIT_FFI_EXPORT
int32_t mbw_x11_context_drag_drop_available(uint64_t raw_context) {
  (void)raw_context;
  return 0;
}
MOONBIT_FFI_EXPORT
moonbit_bytes_t mbw_x11_window_take_drag_paths(uint64_t raw_window) {
  (void)raw_window;
  return moonbit_make_bytes(0, 0);
}
MOONBIT_FFI_EXPORT
void mbw_x11_install_window_event_callback(void *trampoline, void *closure) {
  (void)trampoline;
  (void)closure;
}
MOONBIT_FFI_EXPORT
void mbw_x11_install_input_event_callback(void *trampoline, void *closure) {
  (void)trampoline;
  (void)closure;
}

#endif
