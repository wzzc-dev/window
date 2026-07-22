# Android hosted template (window)

Minimal installable host for `wzzc-dev/window/android` hosted backends.

This template owns the Activity entry. It loads the app native library and is
expected to enter the MoonBit hosted `EventLoop` (see
`../PACKAGE.md`). It does **not** depend on `moui_shell` or the
embedding inject ABI.

## Layout

- `app/` — Gradle application module (placeholder Activity)
- Native bootstrap symbols live under `../native/` and are linked
  into the app shared library by the app build

## Status

- **M1**: host-sim coverage lives in `moon test android --target native` (no device required)
- Device/template compile requires Android SDK + NDK; full `android_main` /
  GameActivity glue lands with the native vertical slice

## Host-sim smoke (always)

From the `window` module root:

```sh
moon test android --target native
```

## Device build (when NDK is configured)

```sh
# after native package is linked into your app lib:
cd modules/window/android/template
./gradlew :app:assembleDebug
```

Signing and store packaging stay outside this repository.

## HostedActivity

`HostedActivity` owns a `SurfaceView`, forwards lifecycle/surface/touch to JNI
(`native_android_host.c`), which enqueues HostCmd for MoonBit to drain.

## Package co-location

This template lives under `modules/window/android/template` next to native glue and
packaging scripts so the platform package is self-contained.
