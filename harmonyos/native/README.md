# HarmonyOS native glue

Sources live **in the package directory** (MoonBit `native-stub` constraint):

- `../native_harmonyos_host.c` / `../native_harmonyos_host.h` — HostCmd queue + soft present hooks
- `../host_ffi.mbt` — MoonBit exports called from C/NAPI
- `mbw_harmonyos_app_entry.c` — optional Ability/XComponent bootstrap symbols for HAP linking

On device OH builds (`__OHOS__`), Ability/XComponent callbacks should call
`mbw_harmonyos_host_on_*` and start the MoonBit EventLoop via
`mbw_harmonyos_start_event_loop`.

Host (macOS/Linux) builds compile stubs so `moon test` works without DevEco.
