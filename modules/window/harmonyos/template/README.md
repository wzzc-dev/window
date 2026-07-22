# HarmonyOS hosted template

This is a thin Stage Ability / XComponent project for
`wzzc-dev/window/harmonyos`. It owns only OS lifecycle, native surface, and
pointer acquisition. The native module forwards those callbacks into the
package HostCmd queue; the MoonBit EventLoop remains the lifecycle authority.

## Layout

- `entry/src/main/ets/entryability/EntryAbility.ets` - process lifecycle and
  EventLoop startup.
- `entry/src/main/ets/pages/Index.ets` - a single SURFACE XComponent.
- `entry/src/main/cpp/window_hosted_napi.cpp` - registers native XComponent
  callbacks and forwards lifecycle/surface/input to HostCmd.
- `entry/src/main/cpp/CMakeLists.txt` - links the window host, MoonBit entry,
  presenter, and native NAPI module.

Native XComponent callbacks are the only surface, resize, detach, and pointer
source. ArkTS does not synthesize those events.

## Build

From the MoUI workspace root, with DevEco SDK components installed:

```sh
export HARMONYOS_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony
bash window/modules/window/harmonyos/scripts/build-hosted-hap.sh
```

The package script first runs host-sim checks. It builds a HAP when `hvigorw`,
`ohpm`, and the native SDK are available, and otherwise records the honest
tooling gap without claiming a device pass.
