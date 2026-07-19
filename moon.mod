name = "wzzc-dev/window"

version = "0.5.1-0.1.7-2"

preferred_target = "native"

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/window.git"

license = "Apache-2.0"

keywords = [ "windowing", "winit", "macos", "appkit", "gui" ]

description = "The wzzc-dev fork of moonbit-community/window, adding MoUI-oriented Web, Windows, and Linux support while tracking upstream window 0.5.1."

import {
  "moonbitlang/x@0.4.45",
}

options(
  "--moonbit-unstable-prebuild": "build.js",
)
