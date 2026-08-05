name = "wzzc-dev/window"

version = "0.5.4-0.1.5"

import {
  "Milky2018/windowing@0.1.0",
}

preferred_target = "native"

readme = "README.mbt.md"

repository = "https://github.com/wzzc-dev/window.git"

license = "Apache-2.0"

keywords = [ "windowing", "winit", "macos", "appkit", "gui" ]

description = "The wzzc-dev fork of moonbit-community/window, tracking upstream 0.5.4 while adding MoUI-oriented desktop, Web, and mobile backends."

options(
  "--moonbit-unstable-prebuild": "build.js",
)
