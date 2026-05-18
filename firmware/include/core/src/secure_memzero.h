#ifndef SECURE_MEMZERO_H
#define SECURE_MEMZERO_H

#include <stddef.h>
#include <stdint.h>

void secure_memzero(volatile void *ptr, size_t len) {
    if (!ptr) return;
    volatile uint8_t *p = (volatile uint8_t *)ptr;
    while (len--) *p++ = 0;
    __asm__ volatile ("" : : "r"(ptr) : "memory");
}

#endif // SECURE_MEMZERO_H