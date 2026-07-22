#include <errno.h>
#include <stddef.h>
#include <stdlib.h>

/* MoonBit runtime calls getentropy(); we remap via -Dgetentropy=mbw_ios_getentropy. */
int mbw_ios_getentropy(void *buffer, size_t buffer_size) {
  if (buffer == NULL && buffer_size != 0) {
    errno = EFAULT;
    return -1;
  }
  arc4random_buf(buffer, buffer_size);
  return 0;
}
