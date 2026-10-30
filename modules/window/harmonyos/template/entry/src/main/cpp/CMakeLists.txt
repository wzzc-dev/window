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
# MoonBit >= 0.10.16 ships the native runtime as `lib/runtime/*.c`; older
# toolchains shipped one `lib/runtime.c`. Accept both layouts so a toolchain
# upgrade does not silently break mobile packaging.
set(MBW_MOON_RUNTIME_SOURCES "")
if(EXISTS "${MBW_MOON_HOME}/lib/runtime.c")
  list(APPEND MBW_MOON_RUNTIME_SOURCES "${MBW_MOON_HOME}/lib/runtime.c")
elseif(EXISTS "${MBW_MOON_HOME}/lib/runtime")
  file(GLOB MBW_MOON_RUNTIME_SPLIT "${MBW_MOON_HOME}/lib/runtime/*.c")
  if(MBW_MOON_RUNTIME_SPLIT)
    list(APPEND MBW_MOON_RUNTIME_SOURCES ${MBW_MOON_RUNTIME_SPLIT})
  endif()
endif()
if(NOT MBW_MOON_RUNTIME_SOURCES)
  message(FATAL_ERROR "MBW_MOON_HOME must contain the MoonBit native runtime (lib/runtime.c or lib/runtime/*.c)")
endif()
if(NOT DEFINED MBW_MOONBIT_C OR NOT EXISTS "${MBW_MOONBIT_C}")
  message(FATAL_ERROR "MBW_MOONBIT_C must point at generated MoonBit C")
endif()

set(MBW_LIBRARY_NAME "window_harmonyos_hosted" CACHE STRING "shared library name")
set(MBW_MOONBIT_MAIN_ALIAS "mbw_harmonyos_moonbit_main")
# Platform native stubs live next to the MoUI HarmonyOS backend package. Glob
# the directory instead of naming files one by one so adding a stub (for
# example the pasteboard bridge) does not require a matching template edit that
# is easy to forget until the shared library fails to link.
file(GLOB MBW_MOUI_HARMONYOS_STUB_SOURCES
  "${MBW_WORKSPACE_ROOT}/moui/backend/harmonyos/*.cpp"
  "${MBW_WORKSPACE_ROOT}/moui/backend/harmonyos/*.c"
)
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
  "${MBW_WINDOW_ROOT}/harmonyos/native/mbw_harmonyos_compat.c"
  "${MBW_MOONBIT_C}"
  ${MBW_MOON_RUNTIME_SOURCES}
  "${MBW_WORKSPACE_ROOT}/.mooncakes/moonbitlang/x/fs/fs_native.c"
  ${MBW_MOUI_HARMONYOS_STUB_SOURCES}
  ${MBW_SKIA_STUB_SOURCES}
)

# `lib/runtime/dir.c` uses NAME_MAX without including <limits.h>; musl (the OHOS
# sysroot) does not pull it in transitively. Scope the fix to that one file so
# the rest of the runtime keeps its own include hygiene.
foreach(runtime_source ${MBW_MOON_RUNTIME_SOURCES})
  if(runtime_source MATCHES "/dir\\.c$")
    set_source_files_properties("${runtime_source}" PROPERTIES
      COMPILE_OPTIONS "-include;limits.h")
  endif()
endforeach()

# The MoonBit runtime calls `posix_spawn_file_actions_addchdir_np` from
# `thread_pool.c`. OHOS ships that entry point only in the static `libc.a`; the
# dynamic `libc.so` a HAP links against does not export it, so the shared
# library would fail to link. Link OHOS's own object (the private
# `posix_spawn_file_actions_t` layout it encodes is not public ABI, so
# re-implementing it would be guesswork) and satisfy its single missing
# dependency, `__libc_malloc`, from mbw_harmonyos_compat.c.
set(MBW_OHOS_LIBC_A "${OHOS_SDK_NATIVE}/sysroot/usr/lib/aarch64-linux-ohos/libc.a")
if(EXISTS "${MBW_OHOS_LIBC_A}")
  execute_process(
    COMMAND "${CMAKE_AR}" x "${MBW_OHOS_LIBC_A}" posix_spawn_file_actions_addchdir.o
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    RESULT_VARIABLE _mbw_ar_result
    ERROR_QUIET)
  if(_mbw_ar_result EQUAL 0 AND EXISTS "${CMAKE_CURRENT_BINARY_DIR}/posix_spawn_file_actions_addchdir.o")
    target_sources(${MBW_LIBRARY_NAME} PRIVATE
      "${CMAKE_CURRENT_BINARY_DIR}/posix_spawn_file_actions_addchdir.o")
    message(STATUS "HarmonyOS CMake linked OHOS posix_spawn_file_actions_addchdir.o from libc.a")
  else()
    message(FATAL_ERROR "could not extract posix_spawn_file_actions_addchdir.o from ${MBW_OHOS_LIBC_A}")
  endif()
else()
  message(FATAL_ERROR "OHOS static libc.a not found at ${MBW_OHOS_LIBC_A}; cannot supply posix_spawn_file_actions_addchdir_np")
endif()

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
  # Clipboard host service (moui/backend/harmonyos/harmonyos_clipboard.cpp)
  # reads and writes plain text through OH_Pasteboard + UDMF.
  pasteboard
  udmf
  # VSync frame pacing (native/mbw_harmonyos_compat.c): the host loop waits for
  # the display refresh boundary instead of sleeping a fixed interval.
  native_vsync
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
