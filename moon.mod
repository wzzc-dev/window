name = "wzzc-dev/window"

version = "0.5.4-0.1.0"

preferred_target = "native"

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/window.git"

license = "Apache-2.0"

keywords = [
  "windowing",
  "winit",
  "macos",
  "appkit",
  "windows",
  "linux",
  "web",
  "android",
  "ios",
  "harmonyos",
  "gui",
]

description = "The wzzc-dev fork of moonbit-community/window, tracking upstream 0.5.4 macOS while adding MoUI-oriented Web, Windows, Linux, Android, iOS, and HarmonyOS support."

import {
  "moonbitlang/x@0.4.46",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
