#pragma once

// HarmonyOS (OHOS musl) compatibility shims for symbols the MoonBit native
// runtime expects but the OHOS dynamic libc does not export.
//
// `posix_spawn_file_actions_addchdir_np` exists in the OHOS static `libc.a`
// but is absent from the shipped `libc.so` dynamic symbol table, so linking a
// shared library against it fails with an undefined-symbol error. The MoonBit
// runtime calls it from `thread_pool.c` whenever a spawn job carries a `cwd`.
//
// The template links OHOS's own object for the chdir entry point; this header
// declares only the allocator indirection that object needs.

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__OHOS__)
// `libc.a`'s posix_spawn_file_actions_addchdir.o calls `__libc_malloc`, which
// the dynamic `libc.so` does not export. Defined in mbw_harmonyos_compat.c.
void *__libc_malloc(size_t size);
#endif

#ifdef __cplusplus
}
#endif
