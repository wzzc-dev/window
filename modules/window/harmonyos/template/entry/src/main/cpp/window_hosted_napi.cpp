#include <cstdint>
#include <cstring>
#include <limits>

#include <ace/xcomponent/native_interface_xcomponent.h>
#include <napi/native_api.h>

#if defined(__has_include)
#if __has_include(<arkui/ui_input_event.h>)
#include <arkui/ui_input_event.h>
#define MBW_HAS_UI_INPUT_EVENT 1
#endif
#if __has_include(<multimodalinput/oh_axis_type.h>)
#include <multimodalinput/oh_axis_type.h>
#endif
#endif

#if defined(__has_include)
#if __has_include(<hilog/log.h>)
#include <hilog/log.h>
#define MBW_HAS_HILOG 1
#endif
#endif

#if defined(__has_include)
#if __has_include(<window_manager/oh_display_manager.h>)
#include <window_manager/oh_display_manager.h>
#define MBW_HAS_DISPLAY_MANAGER 1
#endif
#endif

#include "mbw_harmonyos_app_entry.h"
#include "native_harmonyos_host.h"

namespace {

OH_NativeXComponent *g_xcomponent = nullptr;
OH_NativeXComponent_Callback g_xcomponent_callbacks;

double display_scale() {
#if defined(MBW_HAS_DISPLAY_MANAGER)
  float density = 0.0F;
  if (OH_NativeDisplayManager_GetDefaultDisplayDensityPixels(&density) ==
          DISPLAY_MANAGER_OK &&
      density > 0.0F) {
    return static_cast<double>(density);
  }
#endif
  return 1.0;
}

int32_t dimension(uint64_t value) {
  if (value == 0) {
    return 1;
  }
  if (value > static_cast<uint64_t>(std::numeric_limits<int32_t>::max())) {
    return std::numeric_limits<int32_t>::max();
  }
  return static_cast<int32_t>(value);
}

// Last extent pushed to the host, used to report detach evidence after the
// native window is already gone.
int last_surface_width = 0;
int last_surface_height = 0;

void sync_surface(
    OH_NativeXComponent *component,
    void *window,
    bool initialized) {
  if (component == nullptr || window == nullptr) {
    return;
  }
  uint64_t width = 1;
  uint64_t height = 1;
  if (OH_NativeXComponent_GetXComponentSize(component, window, &width, &height) !=
      OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    return;
  }
  last_surface_width = static_cast<int>(width);
  last_surface_height = static_cast<int>(height);
  const auto handle = static_cast<uint64_t>(reinterpret_cast<uintptr_t>(window));
  if (initialized) {
    mbw_harmonyos_host_on_surface_init(
        handle,
        handle,
        dimension(width),
        dimension(height),
        display_scale());
  } else {
    mbw_harmonyos_host_on_surface_resize(
        dimension(width),
        dimension(height),
        display_scale());
  }
}

// Surface lifecycle is the detach/recreate evidence source. Each transition is
// logged so a device capture can show attach -> detach -> re-attach without
// instrumenting MoUI.
void log_surface_lifecycle(const char *phase, int width, int height) {
#if defined(MBW_HAS_HILOG)
  OH_LOG_Print(
    LOG_APP,
    LOG_INFO,
    0x4D4F,
    "MoUIHarmony",
    "surface %{public}s width=%{public}d height=%{public}d",
    phase,
    width,
    height
  );
#else
  (void)phase;
  (void)width;
  (void)height;
#endif
}

void on_surface_created(OH_NativeXComponent *component, void *window) {
  sync_surface(component, window, true);
  log_surface_lifecycle("created", last_surface_width, last_surface_height);
}

void on_surface_changed(OH_NativeXComponent *component, void *window) {
  sync_surface(component, window, false);
  log_surface_lifecycle("changed", last_surface_width, last_surface_height);
}

void on_surface_destroyed(OH_NativeXComponent *component, void *window) {
  (void)component;
  (void)window;
  // The native window is already gone here, so the last extent identifies which
  // surface was torn down.
  log_surface_lifecycle("destroyed", last_surface_width, last_surface_height);
  mbw_harmonyos_host_on_surface_term();
}

void dispatch_touch_event(OH_NativeXComponent *component, void *window) {
  if (component == nullptr || window == nullptr) {
    return;
  }
  OH_NativeXComponent_TouchEvent event;
  if (OH_NativeXComponent_GetTouchEvent(component, window, &event) !=
      OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    return;
  }
  switch (event.type) {
    case OH_NATIVEXCOMPONENT_DOWN:
      mbw_harmonyos_host_on_pointer_button(1, event.x, event.y);
      break;
    case OH_NATIVEXCOMPONENT_MOVE:
      mbw_harmonyos_host_on_pointer_moved(event.x, event.y);
      break;
    case OH_NATIVEXCOMPONENT_UP:
    case OH_NATIVEXCOMPONENT_CANCEL:
      mbw_harmonyos_host_on_pointer_button(0, event.x, event.y);
      break;
    default:
      break;
  }
}

// Map an OHOS key code to the Unicode code point it types, or 0 when the key
// does not type a character. The host entry point
// (`mbw_harmonyos_host_on_keyboard_codepoint`) was always declared but had no
// caller, so on a real device every keystroke was dropped and MoUI text fields
// never received input. XComponent key events are the only keyboard source on
// this platform (M5), so the mapping belongs here.
int32_t key_code_to_codepoint(int32_t code, bool shift) {
  // Digits 0-9 (KEYCODE_0 = 2000 .. KEYCODE_9 = 2009).
  if (code >= 2000 && code <= 2009) {
    static const char shifted[] = ")!@#$%^&*(";
    int32_t digit = code - 2000;
    return shift ? shifted[digit] : ('0' + digit);
  }
  // Letters A-Z (KEYCODE_A = 2017 .. KEYCODE_Z = 2042).
  if (code >= 2017 && code <= 2042) {
    char letter = static_cast<char>('a' + (code - 2017));
    return shift ? (letter - 'a' + 'A') : letter;
  }
  switch (code) {
    case 2050: return ' ';
    case 2043: return shift ? '<' : ',';
    case 2044: return shift ? '>' : '.';
    case 2064: return shift ? '?' : '/';
    case 2062: return shift ? ':' : ';';
    case 2063: return shift ? '"' : '\'';
    case 2059: return shift ? '{' : '[';
    case 2060: return shift ? '}' : ']';
    case 2061: return shift ? '|' : '\\';
    case 2057: return shift ? '_' : '-';
    case 2058: return shift ? '+' : '=';
    case 2056: return shift ? '~' : '`';
    case 2010: return '*';
    case 2011: return '#';
    // Editing / commit keys are not characters; the codepoint channel is
    // text-only, so Enter and Backspace are reported through the key-event
    // path instead of being typed.
    default: return 0;
  }
}

bool is_named_key(int32_t key_code);

void dispatch_key_event(OH_NativeXComponent *component, void *window) {
  if (component == nullptr) {
    return;
  }
  OH_NativeXComponent_KeyEvent *key_event = nullptr;
  if (OH_NativeXComponent_GetKeyEvent(component, &key_event) !=
          OH_NATIVEXCOMPONENT_RESULT_SUCCESS ||
      key_event == nullptr) {
    return;
  }
  OH_NativeXComponent_KeyAction action;
  if (OH_NativeXComponent_GetKeyEventAction(key_event, &action) !=
      OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    return;
  }
  OH_NativeXComponent_KeyCode code;
  if (OH_NativeXComponent_GetKeyEventCode(key_event, &code) !=
      OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    return;
  }
  uint64_t modifiers = 0;
  if (OH_NativeXComponent_GetKeyEventModifierKeyStates(key_event, &modifiers) !=
      OH_NATIVEXCOMPONENT_RESULT_SUCCESS) {
    modifiers = 0;
  }
  // OHOS modifier bitmask, measured on device (the mapping is not documented in
  // a public header): bit0 = Ctrl, bit1 = Shift, bit2 = Alt. A simulated
  // Ctrl+A reports modifiers=1 on the 'A' key, Shift reports 2, Alt reports 4.
  const bool control = (modifiers & 0x1ULL) != 0;
  const bool shift = (modifiers & 0x2ULL) != 0;
  const bool alt = (modifiers & 0x4ULL) != 0;
  const bool pressed = action == OH_NATIVEXCOMPONENT_KEY_ACTION_DOWN;
  const int32_t key_code = static_cast<int32_t>(code);
#if defined(MBW_HAS_HILOG)
  // Modifier bits are not documented in a public header; log the raw mask so a
  // device capture can confirm the ctrl/alt/shift mapping instead of guessing.
  OH_LOG_Print(LOG_APP, LOG_INFO, 0x4D4F, "MoUIHarmony",
               "key code=%{public}d modifiers=%{public}llu pressed=%{public}d",
               key_code, static_cast<unsigned long long>(modifiers),
               pressed ? 1 : 0);
#endif

  // Named keys (Delete, Backspace, arrows, Enter, Tab, Escape, Home/End) must
  // reach the runtime as key events, not as text: Backspace and Ctrl+A cannot be
  // expressed through the codepoint channel, which is why deletion and
  // select-all were dead before this.
  if (is_named_key(key_code)) {
    mbw_harmonyos_host_on_key(key_code, static_cast<int32_t>(modifiers),
                              pressed ? 1 : 0);
    (void)window;
    return;
  }

  // Character keys: emit text on press only. Modified presses (Ctrl+A and
  // friends) are shortcut input, so they are reported as key events instead of
  // inserting a character.
  if (!pressed) {
    (void)window;
    return;
  }
  if (control || alt) {
    // Shortcut chord: forward the letter as a key event carrying the modifier
    // mask so the runtime can resolve Ctrl+A / Ctrl+C instead of typing 'a'.
    mbw_harmonyos_host_on_key(key_code, static_cast<int32_t>(modifiers), 1);
    (void)window;
    return;
  }
  const int32_t codepoint = key_code_to_codepoint(key_code, shift);
  if (codepoint != 0) {
    mbw_harmonyos_host_on_keyboard_codepoint(codepoint);
  }
  (void)window;
}

// Keys the runtime decodes as named keys rather than text. Keep in sync with
// `harmonyos_named_key` in modules/window/harmonyos/host_queue.mbt.
bool is_named_key(int32_t key_code) {
  switch (key_code) {
    case 2054:  // KEYCODE_ENTER
    case 2055:  // KEYCODE_DEL (Backspace)
    case 2071:  // KEYCODE_FORWARD_DEL (Delete)
    case 2049:  // KEYCODE_TAB
    case 2070:  // KEYCODE_ESCAPE
    case 2050:  // KEYCODE_SPACE
    case 2012:  // KEYCODE_DPAD_UP
    case 2013:  // KEYCODE_DPAD_DOWN
    case 2014:  // KEYCODE_DPAD_LEFT
    case 2015:  // KEYCODE_DPAD_RIGHT
    case 2081:  // KEYCODE_MOVE_HOME
    case 2082:  // KEYCODE_MOVE_END
      return true;
    default:
      return false;
  }
}

// Mouse wheel / trackpad scroll. XComponent has no dedicated wheel callback, so
// axis events arrive through the generic UI input callback
// (`OH_NativeXComponent_RegisterUIInputEventCallback`, axis events only).
// Without this the hosted surface never received MouseWheel and scrolling was
// dead.
// Dedup state for axis events: the platform repeats the same UPDATE twice per
// wheel detent.
double g_last_axis_x = -1.0;
double g_last_axis_y = -1.0;
double g_last_axis_dx = 0.0;
double g_last_axis_dy = 0.0;

void dispatch_axis_event(
    OH_NativeXComponent *component,
    ArkUI_UIInputEvent *event,
    ArkUI_UIInputEvent_Type type) {
  (void)component;
  (void)type;
#if defined(MBW_HAS_UI_INPUT_EVENT)
  if (event == nullptr) {
    return;
  }
#if defined(MBW_HAS_HILOG)
  // The axis action decides whether this is an update or the end of a gesture;
  // both push deltas so short scrolls are not lost.
#endif
  // Only UPDATE carries a new delta. BEGIN/END repeat the previous axis value,
  // so forwarding them pushed the same scroll twice and made the motion feel
  // sticky. CANCEL means the gesture was dropped.
  const int32_t axis_action = OH_ArkUI_AxisEvent_GetAxisAction(event);
  if (axis_action == AXIS_ACTION_END || axis_action == AXIS_ACTION_CANCEL) {
    // A gesture finished: forget the last delta so the next detent with the same
    // value is not mistaken for a duplicate.
    g_last_axis_x = -1.0;
    g_last_axis_y = -1.0;
    g_last_axis_dx = 0.0;
    g_last_axis_dy = 0.0;
    return;
  }
  if (axis_action != AXIS_ACTION_UPDATE) {
    return;
  }
  const double vertical = OH_ArkUI_AxisEvent_GetVerticalAxisValue(event);
  const double horizontal = OH_ArkUI_AxisEvent_GetHorizontalAxisValue(event);
  if (vertical == 0.0 && horizontal == 0.0) {
    return;
  }
  // Axis events carry the pointer position too (`OH_ArkUI_PointerEvent_GetX/Y`
  // document axis events as valid input). Without it the scroll was routed to
  // whatever position the last pointer event left behind — on this platform that
  // is the last click, so scrolling only worked over the previously clicked
  // spot.
  // Coordinates: `OH_ArkUI_PointerEvent_GetX/Y` are documented for directional
  // input events including axis events, and report the position relative to the
  // component — the same space the touch callback uses, so the wheel lands where
  // the cursor is instead of where the last click left `last_pointer`.
  //
  // No display-relative fallback here: those are screen coordinates, and mixing
  // them with the component-relative pointer stream would offset every scroll by
  // the XComponent origin. When this call fails it returns 0, which the log below
  // makes visible.
  const double x = OH_ArkUI_PointerEvent_GetX(event);
  const double y = OH_ArkUI_PointerEvent_GetY(event);

  // One physical wheel detent arrives as BEGIN, UPDATE, UPDATE, END with the same
  // delta on both UPDATE frames (measured: action=1,2,2,3). Forwarding both
  // doubled every notch and was the stutter. Suppress an UPDATE that repeats the
  // previous one at the same position; a genuine second notch arrives after an
  // END, which clears the record below.
  if (x == g_last_axis_x && y == g_last_axis_y &&
      horizontal == g_last_axis_dx && vertical == g_last_axis_dy) {
    return;
  }
  g_last_axis_x = x;
  g_last_axis_y = y;
  g_last_axis_dx = horizontal;
  g_last_axis_dy = vertical;
#if defined(MBW_HAS_HILOG)
  OH_LOG_Print(LOG_APP, LOG_INFO, 0x4D4F, "MoUIHarmony",
               "axis x=%{public}f y=%{public}f raw_dx=%{public}f raw_dy=%{public}f src=%{public}d",
               x, y, horizontal, vertical,
               OH_ArkUI_UIInputEvent_GetSourceType(event));
#endif
  // Units differ by device, per `OH_ArkUI_AxisEvent_GetVerticalAxisValue`:
  //   * mouse wheel -> degrees of wheel rotation for one notch, where the
  //     user's scroll-step setting decides how many lines that means
  //     (`OH_ArkUI_AxisEvent_GetScrollStep`).
  //   * touchpad -> pixels of swipe.
  // The host channel carries **lines**, so a raw wheel angle must be divided by
  // the configured step. Treating the degree value as a line count multiplied
  // every notch by the line extent (40 px) and made scrolling far too fast.
  // The delta handed to the runtime is in **pixels**, so the platform unit is
  // converted here and nowhere else (the runtime would otherwise apply its own
  // line-to-pixel factor on top).
  //
  //   * mouse wheel -> degrees of rotation for this notch. A conventional wheel
  //     detent is 15 degrees; `OH_ArkUI_AxisEvent_GetScrollStep` can report the
  //     user's configured step, but this device reports 0 (unimplemented), so the
  //     fallback is used.
  //   * touchpad -> already pixels of swipe.
  //
  // Pixels per degree is deliberately small: one detent should move a few dozen
  // pixels, not a screen.
  constexpr double k_pixels_per_wheel_degree = 1.5;
  const int32_t source_type = OH_ArkUI_UIInputEvent_GetSourceType(event);
  double pixels_x = horizontal;
  double pixels_y = vertical;
  if (source_type == UI_INPUT_EVENT_SOURCE_TYPE_MOUSE) {
    pixels_x = horizontal * k_pixels_per_wheel_degree;
    pixels_y = vertical * k_pixels_per_wheel_degree;
  }
  // Sign convention: MoUI applies `offset.y -= delta.y`, so a positive delta
  // scrolls content up. OHOS reports positive as forward/down, so the host
  // bridge negates.
  mbw_harmonyos_host_on_scroll_at(x, y, -pixels_x, -pixels_y);
#else
  (void)event;
#endif
}

// Accessibility bridge owned by the MoUI HarmonyOS backend
// (moui/backend/harmonyos/harmonyos_accessibility.cpp). The NAPI module owns the
// OH_NativeXComponent pointer, so it hands that over before registration; the
// bridge then answers ArkUI's accessibility provider callbacks from the
// published semantics snapshot.
extern "C" void mbw_harmonyos_accessibility_set_xcomponent(int64_t handle);
extern "C" int32_t mbw_harmonyos_accessibility_register(void);

void register_xcomponent_callbacks() {
  if (g_xcomponent == nullptr) {
    return;
  }
  std::memset(&g_xcomponent_callbacks, 0, sizeof(g_xcomponent_callbacks));
  g_xcomponent_callbacks.OnSurfaceCreated = on_surface_created;
  g_xcomponent_callbacks.OnSurfaceChanged = on_surface_changed;
  g_xcomponent_callbacks.OnSurfaceDestroyed = on_surface_destroyed;
  g_xcomponent_callbacks.DispatchTouchEvent = dispatch_touch_event;
  OH_NativeXComponent_RegisterCallback(g_xcomponent, &g_xcomponent_callbacks);
  // Keyboard input: recorded so text fields actually receive typed characters.
  // Without this registration the host codepoint entry point is dead code and
  // every keystroke is dropped on device.
  (void)OH_NativeXComponent_RegisterKeyEventCallback(
      g_xcomponent, dispatch_key_event);
  // Scroll: axis events are the only wheel source on XComponent.
#if !defined(MBW_DISABLE_AXIS_CALLBACK)
  const int32_t axis_result = OH_NativeXComponent_RegisterUIInputEventCallback(
      g_xcomponent, dispatch_axis_event, ARKUI_UIINPUTEVENT_TYPE_AXIS);
#if defined(MBW_HAS_HILOG)
  OH_LOG_Print(LOG_APP, LOG_INFO, 0x4D4F, "MoUIHarmony",
               "axis callback register result=%{public}d", axis_result);
#endif
#endif
  // Accessibility: expose the semantics tree to ArkUI. Registration happens
  // here because this is the only place that owns the XComponent pointer.
  mbw_harmonyos_accessibility_set_xcomponent(
      static_cast<int64_t>(reinterpret_cast<intptr_t>(g_xcomponent)));
  (void)mbw_harmonyos_accessibility_register();
}

napi_value undefined(napi_env env) {
  napi_value result;
  napi_get_undefined(env, &result);
  return result;
}

napi_value boolean(napi_env env, bool value) {
  napi_value result;
  napi_get_boolean(env, value, &result);
  return result;
}

napi_value start_event_loop(napi_env env, napi_callback_info info) {
  (void)info;
  return boolean(env, mbw_harmonyos_start_event_loop() == 0);
}

napi_value host_on_start(napi_env env, napi_callback_info info) {
  (void)info;
  mbw_harmonyos_host_on_start();
  return undefined(env);
}

napi_value host_on_resume(napi_env env, napi_callback_info info) {
  (void)info;
  mbw_harmonyos_host_on_resume();
  return undefined(env);
}

napi_value host_on_pause(napi_env env, napi_callback_info info) {
  (void)info;
  mbw_harmonyos_host_on_pause();
  return undefined(env);
}

napi_value host_on_stop(napi_env env, napi_callback_info info) {
  (void)info;
  mbw_harmonyos_host_on_stop();
  return undefined(env);
}

napi_value host_on_destroy(napi_env env, napi_callback_info info) {
  (void)info;
  mbw_harmonyos_host_on_destroy();
  return undefined(env);
}

napi_value host_on_memory_warning(napi_env env, napi_callback_info info) {
  (void)info;
  mbw_harmonyos_host_on_memory_warning();
  return undefined(env);
}

// Paste security control callback: ArkTS calls this from PasteButton.onClick
// after the platform granted a one-shot paste authorization. The MoUI
// clipboard bridge reads the pasteboard here and forwards the text to the
// runtime as keyboard input, which is how a hosted text field receives a paste.
extern "C" int32_t mbw_harmonyos_clipboard_request_granted_read(void);

napi_value request_clipboard_read(napi_env env, napi_callback_info info) {
  (void)info;
  const int32_t read = mbw_harmonyos_clipboard_request_granted_read();
  return boolean(env, read != 0);
}

// Paste-affordance plumbing: ArkTS registers a callback that shows/hides the
// paste security control, and the native side toggles it when the hosted text
// field gains or loses focus.
napi_env g_affordance_env = nullptr;
napi_ref g_affordance_callback = nullptr;

void set_paste_affordance(bool visible) {
  if (g_affordance_env == nullptr || g_affordance_callback == nullptr) {
    return;
  }
  napi_value callback = nullptr;
  napi_value global = nullptr;
  napi_value argv[1];
  if (napi_get_reference_value(g_affordance_env, g_affordance_callback,
                               &callback) != napi_ok ||
      callback == nullptr) {
    return;
  }
  napi_get_global(g_affordance_env, &global);
  napi_get_boolean(g_affordance_env, visible, &argv[0]);
  (void)napi_call_function(g_affordance_env, global, callback, 1, argv,
                           nullptr);
}

napi_value set_clipboard_affordance_listener(napi_env env,
                                             napi_callback_info info) {
  size_t argc = 1;
  napi_value argv[1];
  if (napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr) != napi_ok ||
      argc < 1) {
    return undefined(env);
  }
  napi_valuetype type = napi_undefined;
  if (napi_typeof(env, argv[0], &type) != napi_ok ||
      type != napi_function) {
    return boolean(env, false);
  }
  if (g_affordance_callback != nullptr) {
    napi_delete_reference(g_affordance_env, g_affordance_callback);
  }
  g_affordance_env = env;
  napi_create_reference(env, argv[0], 1, &g_affordance_callback);
  return boolean(env, true);
}

napi_value init(napi_env env, napi_value exports) {
  napi_value xcomponent_export;
  if (napi_get_named_property(env, exports, OH_NATIVE_XCOMPONENT_OBJ,
                              &xcomponent_export) == napi_ok) {
    void *raw_xcomponent = nullptr;
    if (napi_unwrap(env, xcomponent_export, &raw_xcomponent) == napi_ok) {
      g_xcomponent = reinterpret_cast<OH_NativeXComponent *>(raw_xcomponent);
      register_xcomponent_callbacks();
    }
  }

  napi_property_descriptor descriptors[] = {
      {"startEventLoop", nullptr, start_event_loop, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"hostOnStart", nullptr, host_on_start, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"hostOnResume", nullptr, host_on_resume, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"hostOnPause", nullptr, host_on_pause, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"hostOnStop", nullptr, host_on_stop, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"hostOnDestroy", nullptr, host_on_destroy, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"hostOnMemoryWarning", nullptr, host_on_memory_warning, nullptr, nullptr,
       nullptr, napi_default, nullptr},
      {"requestClipboardRead", nullptr, request_clipboard_read, nullptr, nullptr,
       nullptr, napi_default, nullptr},
      {"setClipboardAffordanceListener", nullptr,
       set_clipboard_affordance_listener, nullptr, nullptr, nullptr,
       napi_default, nullptr},
  };
  napi_define_properties(
      env,
      exports,
      sizeof(descriptors) / sizeof(descriptors[0]),
      descriptors);
  return exports;
}

}  // namespace

#ifndef NODE_GYP_MODULE_NAME
#define NODE_GYP_MODULE_NAME window_harmonyos_hosted
#endif

NAPI_MODULE(NODE_GYP_MODULE_NAME, init)
