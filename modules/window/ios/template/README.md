# iOS hosted template

This is the thin UIKit host for `wzzc-dev/window/ios`. It is package-local and
contains the real app entry used by `../scripts/build-hosted-sim-app.sh`.

## Layout

- `Info.plist` - application metadata, iOS 15 deployment floor, and a modern
  launch-screen declaration.
- `Sources/main.m` - `UIApplicationMain` entry point.
- `Sources/MBWHostedAppDelegate.{h,m}` - creates the `UIWindow` / `UIView`,
  forwards lifecycle, surface, resize, and touch callbacks to the HostCmd
  queue, and starts the MoonBit EventLoop.

The native HostCmd queue remains in the parent package:
`../native_ios_host.{c,h}`. The template does not use an embedding ABI.

## Build

From the MoUI workspace root:

```sh
bash window/modules/window/ios/scripts/build-hosted-sim-app.sh
```

The script compiles this template directly into a Simulator `.app`; an Xcode
project is not required for the supported hosted build path.
