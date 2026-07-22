# Android native glue

Sources live **in the package directory** (MoonBit `native-stub` constraint):

- `../native_android_host.c` / `../native_android_host.h`
- `../host_ffi.mbt` — MoonBit exports called from C/JNI

On Android NDK builds (`__ANDROID__`), JNI entry points for
`../template` `HostedActivity` pushes HostCmd into the MoonBit queue.

Host (macOS/Linux) builds compile the non-JNI wrappers so `moon test` keeps
working without the NDK.
