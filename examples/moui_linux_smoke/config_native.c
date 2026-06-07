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
