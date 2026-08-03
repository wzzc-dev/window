cmake_minimum_required(VERSION 3.22)
project(window_harmonyos_hosted LANGUAGES C CXX)

foreach(variable MBW_WORKSPACE_ROOT MBW_WINDOW_ROOT MBW_MOON_HOME MBW_MOONBIT_C MBW_SKIA_CXX_RSP MBW_SKIA_LINK_RSP)
  if(NOT DEFINED ${variable} OR "${${variable}}" STREQUAL "")
    set(${variable} "$ENV{${variable}}")
  endif()
endforeach()

if(NOT DEFINED MBW_WORKSPACE_ROOT OR NOT EXISTS "${MBW_WORKSPACE_ROOT}")
  message(FATAL_ERROR "MBW_WORKSPACE_ROOT must point at the MoUI workspace")
endif()
if(NOT DEFINED MBW_WINDOW_ROOT OR NOT EXISTS "${MBW_WINDOW_ROOT}/harmonyos/native_harmonyos_host.c")
  message(FATAL_ERROR "MBW_WINDOW_ROOT must point at the window module root")
endif()
if(NOT DEFINED MBW_MOON_HOME OR NOT EXISTS "${MBW_MOON_HOME}/lib/runtime.c")
  message(FATAL_ERROR "MBW_MOON_HOME must contain the MoonBit native runtime")
endif()
if(NOT DEFINED MBW_MOONBIT_C OR NOT EXISTS "${MBW_MOONBIT_C}")
  message(FATAL_ERROR "MBW_MOONBIT_C must point at generated MoonBit C")
endif()

set(MBW_LIBRARY_NAME "window_harmonyos_hosted" CACHE STRING "shared library name")
set(MBW_MOONBIT_MAIN_ALIAS "mbw_harmonyos_moonbit_main")
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
  "${MBW_SKIA_ROOT}/native/skia_stub_gpu_worker.cpp"
)

add_library(${MBW_LIBRARY_NAME} SHARED
  "${CMAKE_CURRENT_LIST_DIR}/window_hosted_napi.cpp"
  "${MBW_WINDOW_ROOT}/harmonyos/native_harmonyos_host.c"
  "${MBW_WINDOW_ROOT}/harmonyos/native/mbw_harmonyos_app_entry.c"
  "${MBW_MOONBIT_C}"
  "${MBW_MOON_HOME}/lib/runtime.c"
  "${MBW_WORKSPACE_ROOT}/.mooncakes/moonbitlang/x/fs/fs_native.c"
  "${MBW_WORKSPACE_ROOT}/moui/backend/harmonyos/harmonyos_present.cpp"
  ${MBW_SKIA_STUB_SOURCES}
)

target_include_directories(${MBW_LIBRARY_NAME} PRIVATE
  "${MBW_MOON_HOME}/include"
  "${MBW_WINDOW_ROOT}/harmonyos"
  "${MBW_WINDOW_ROOT}/harmonyos/native"
  "${MBW_SKIA_ROOT}/native"
)

target_compile_features(${MBW_LIBRARY_NAME} PRIVATE cxx_std_17)
target_compile_definitions(${MBW_LIBRARY_NAME} PRIVATE
  __OHOS__=1
  MOUI_HARMONYOS_USE_NATIVE_WINDOW=1
  "MBW_HARMONYOS_MOONBIT_MAIN=${MBW_MOONBIT_MAIN_ALIAS}"
  "NODE_GYP_MODULE_NAME=${MBW_LIBRARY_NAME}"
)
set_target_properties(${MBW_LIBRARY_NAME} PROPERTIES
  OUTPUT_NAME "${MBW_LIBRARY_NAME}"
  SUFFIX ".so"
)
set_source_files_properties("${MBW_MOONBIT_C}" PROPERTIES
  LANGUAGE C
  COMPILE_DEFINITIONS "main=${MBW_MOONBIT_MAIN_ALIAS}"
)

# Keyword signature only — same plain/PRIVATE mix bug black-screened Android.
target_link_libraries(${MBW_LIBRARY_NAME} PRIVATE
  ace_napi.z
  ace_ndk.z
  hilog_ndk.z
  native_window
  native_buffer
  native_display_manager
  m
  dl
)

# Real Skia flags from moui_cli resolve_skia (rsp one flag per line). Empty/missing
# rsp keeps stub-only path (skia_available=0 → black surface).
if(DEFINED MBW_SKIA_CXX_RSP AND NOT "${MBW_SKIA_CXX_RSP}" STREQUAL "" AND EXISTS "${MBW_SKIA_CXX_RSP}")
  file(READ "${MBW_SKIA_CXX_RSP}" _skia_cxx_flags_str)
  separate_arguments(_skia_cxx_flags_list UNIX_COMMAND "${_skia_cxx_flags_str}")
  # CXX only: rsp carries -std=c++17 which must not reach C sources.
  target_compile_options(${MBW_LIBRARY_NAME} PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:${_skia_cxx_flags_list}>
  )
  message(STATUS "HarmonyOS CMake applied Skia cxx flags from ${MBW_SKIA_CXX_RSP}")
endif()

if(DEFINED MBW_SKIA_LINK_RSP AND NOT "${MBW_SKIA_LINK_RSP}" STREQUAL "" AND EXISTS "${MBW_SKIA_LINK_RSP}")
  file(READ "${MBW_SKIA_LINK_RSP}" _skia_link_flags_str)
  separate_arguments(_skia_link_flags_list UNIX_COMMAND "${_skia_link_flags_str}")
  target_link_libraries(${MBW_LIBRARY_NAME} PRIVATE ${_skia_link_flags_list})
  message(STATUS "HarmonyOS CMake applied Skia link flags from ${MBW_SKIA_LINK_RSP}")
endif()
