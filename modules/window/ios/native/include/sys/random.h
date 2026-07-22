#pragma once
#include <stddef.h>
/* iPhoneSimulator SDK may lack <sys/random.h>; MoonBit runtime includes it. */
int getentropy(void *buffer, size_t buffer_size);
