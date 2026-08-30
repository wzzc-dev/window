#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

MOONBIT_FFI_EXPORT
int32_t mbw_moui_linux_smoke_require_input(void) {
  const char *value = getenv("WINDOW_MOUI_LINUX_REQUIRE_INPUT");
  if (!value || value[0] == '\0') {
    return 0;
  }
  return strcmp(value, "0") == 0 ? 0 : 1;
}

MOONBIT_FFI_EXPORT
int32_t mbw_moui_linux_smoke_require_data_device(void) {
  const char *value = getenv("WINDOW_MOUI_LINUX_REQUIRE_DATA_DEVICE");
  if (!value || value[0] == '\0') {
    return 0;
  }
  return strcmp(value, "0") == 0 ? 0 : 1;
}

// Requires Window::current_monitor() to resolve. Default is on. Set
// WINDOW_MOUI_LINUX_REQUIRE_CURRENT_MONITOR=0 only on compositors that never
// deliver wl_surface.enter (the WSLg Weston RDP backend; see ADR 0032).
MOONBIT_FFI_EXPORT
int32_t mbw_moui_linux_smoke_require_current_monitor(void) {
  const char *value = getenv("WINDOW_MOUI_LINUX_REQUIRE_CURRENT_MONITOR");
  if (!value || value[0] == '\0') {
    return 1;
  }
  return strcmp(value, "0") == 0 ? 0 : 1;
}
