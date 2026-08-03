cmake_minimum_required(VERSION 3.22)
project(window_android_app LANGUAGES C CXX)

if(NOT DEFINED MBW_MOONBIT_C OR NOT EXISTS "${MBW_MOONBIT_C}")
  message(FATAL_ERROR "MBW_MOONBIT_C must point at generated MoonBit C")
endif()
if(NOT DEFINED MBW_WINDOW_ROOT OR NOT EXISTS "${MBW_WINDOW_ROOT}/android/native_android_host.c")
  message(FATAL_ERROR "MBW_WINDOW_ROOT must point at the window module root")
endif()
if(NOT DEFINED MBW_MOON_HOME)
  message(FATAL_ERROR "MBW_MOON_HOME is required")
endif()
if(NOT DEFINED MBW_WORKSPACE_ROOT)
  message(FATAL_ERROR "MBW_WORKSPACE_ROOT is required")
endif()

set(MBW_LIBRARY_NAME "window_android_app" CACHE STRING "shared library name")
set(MBW_MOONBIT_MAIN_ALIAS "mbw_android_moonbit_main")

set(MBW_SKIA_ROOT "${MBW_WORKSPACE_ROOT}/moui_skia")
set(MBW_SKIA_STUB_SOURCES
  "${MBW_SKIA_ROOT}/native/skia_stub.cpp"
  "${MBW_SKIA_ROOT}/native/skia_stub_common.cpp"
  "${MBW_SKIA_ROOT}/native/skia_stub_surface_image_data.cpp"
  "${MBW_SKIA_ROOT}/native/skia_stub_canvas.cpp"
  "${MBW_SKIA_ROOT}/native/skia_stub_path.cpp"
  "${MBW_SKIA_ROOT}/native/skia_stub_text_font.cpp"
  "${MBW_SKIA_ROOT}/native/skia_stub_paragraph.cpp"
  "${MBW_SKIA_ROOT}/native/skia_stub_shader_filter.cpp"
  "${MBW_SKIA_ROOT}/native/skia_stub_picture.cpp"
  "${MBW_SKIA_ROOT}/native/android_vulkan_loader.cpp"
  "${MBW_SKIA_ROOT}/native/skia_stub_gpu_worker.cpp"
)

set(MBW_SOURCES
  "${MBW_WINDOW_ROOT}/android/native_android_host.c"
  "${MBW_WINDOW_ROOT}/android/native/mbw_android_app_entry.c"
  "${MBW_WINDOW_ROOT}/android/native/mbw_android_compat.c"
  "${MBW_MOONBIT_C}"
  "${MBW_MOON_HOME}/lib/runtime.c"
  "${MBW_WORKSPACE_ROOT}/.mooncakes/moonbitlang/x/fs/fs_native.c"
  "${MBW_WORKSPACE_ROOT}/moui/backend/android/android_present.cpp"
  ${MBW_SKIA_STUB_SOURCES}
)

add_library(${MBW_LIBRARY_NAME} SHARED ${MBW_SOURCES})

target_include_directories(${MBW_LIBRARY_NAME} PRIVATE
  "${MBW_MOON_HOME}/include"
  "${MBW_WINDOW_ROOT}/android"
  "${MBW_SKIA_ROOT}/native"
)

target_compile_features(${MBW_LIBRARY_NAME} PRIVATE cxx_std_17)
target_compile_definitions(${MBW_LIBRARY_NAME} PRIVATE
  __ANDROID__
  "MBW_ANDROID_MOONBIT_MAIN=${MBW_MOONBIT_MAIN_ALIAS}"
)

set_source_files_properties("${MBW_MOONBIT_C}" PROPERTIES
  LANGUAGE C
  COMPILE_DEFINITIONS "main=${MBW_MOONBIT_MAIN_ALIAS}"
)

# MoonBit runtime.c calls getentropy(); declare/compat for API < 28.
set_source_files_properties("${MBW_MOON_HOME}/lib/runtime.c" PROPERTIES
  COMPILE_OPTIONS "-include;${MBW_WINDOW_ROOT}/android/native/mbw_android_compat.h"
)

# Do not link host (macOS) moonbit_simdutf/simdutf/libbacktrace — they are not Android objects.
# Match moui_shell Android link set: android, log, m, dl (+ optional jnigraphics).
# Use the keyword signature consistently: mixing plain + PRIVATE below makes CMake
# reject Skia link flags, so stubs build without MOUI_SKIA_HAS_SKIA and present black.
target_link_libraries(${MBW_LIBRARY_NAME} PRIVATE
  android
  log
  jnigraphics
  m
  dl
)

# Apply real Skia compile + link flags resolved by `moui_cli/build_android.mbt`
# via `resolve_skia`. The rsp files contain one flag per line; we read them
# back into CMake lists with `separate_arguments` so flags with embedded spaces
# (e.g. `-I/path with spaces`) survive intact. When the rsp path is empty
# (fallback Skia stub-only path) this block is a no-op and the stubs link
# without `MOUI_SKIA_HAS_SKIA`, which causes `skia_available()` to return 0
# at runtime — the documented black-screen build-evidence path.
if(DEFINED MBW_SKIA_CXX_RSP AND EXISTS "${MBW_SKIA_CXX_RSP}")
  file(READ "${MBW_SKIA_CXX_RSP}" _skia_cxx_flags_str)
  separate_arguments(_skia_cxx_flags_list UNIX_COMMAND "${_skia_cxx_flags_str}")
  # Apply only to CXX: rsp includes -std=c++17 which is invalid for C sources
  # (runtime.c, moonbit .c, host .c). Without this gate, Gradle fails compile.
  target_compile_options(${MBW_LIBRARY_NAME} PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:${_skia_cxx_flags_list}>
  )
  message(STATUS "Android CMake applied Skia cxx flags from ${MBW_SKIA_CXX_RSP}")
endif()

if(DEFINED MBW_SKIA_LINK_RSP AND EXISTS "${MBW_SKIA_LINK_RSP}")
  file(READ "${MBW_SKIA_LINK_RSP}" _skia_link_flags_str)
  separate_arguments(_skia_link_flags_list UNIX_COMMAND "${_skia_link_flags_str}")
  target_link_libraries(${MBW_LIBRARY_NAME} PRIVATE ${_skia_link_flags_list})
  message(STATUS "Android CMake applied Skia link flags from ${MBW_SKIA_LINK_RSP}")
endif()
