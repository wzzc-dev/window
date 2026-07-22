#include <cstdint>
#include <cstring>
#include <limits>

#include <ace/xcomponent/native_interface_xcomponent.h>
#include <napi/native_api.h>

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

void on_surface_created(OH_NativeXComponent *component, void *window) {
  sync_surface(component, window, true);
}

void on_surface_changed(OH_NativeXComponent *component, void *window) {
  sync_surface(component, window, false);
}

void on_surface_destroyed(OH_NativeXComponent *component, void *window) {
  (void)component;
  (void)window;
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
