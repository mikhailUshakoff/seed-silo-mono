#ifndef SECURE_MEMZERO_H
#define SECURE_MEMZERO_H

#include <stddef.h>
#include <stdint.h>

/*
 * Securely zero memory, preventing the compiler from optimizing away
 * the writes as dead stores (e.g. wiping a key buffer before freeing).
 *
 * Do NOT remove noinline — it prevents LTO from inlining this function
 * at the call site, where the optimizer could gain enough context to
 * prove the writes are unobservable and eliminate them entirely.
 */
__attribute__((noinline, used))
void secure_memzero(volatile void *ptr, size_t len) {
    if (!ptr || len == 0) return;

    /*
     * Cast to volatile uint8_t* so every write goes through a volatile
     * access — the compiler cannot legally elide volatile writes.
     */
    volatile uint8_t *p = (volatile uint8_t *)ptr;

    /* Zero each byte individually through the volatile pointer. */
    while (len--) *p++ = 0;

    /*
     * Compiler barrier: reference p (not ptr) after the loop.
     * p's value encodes that the loop ran to completion — the compiler
     * cannot satisfy this constraint without executing the loop.
     * The "memory" clobber prevents reordering of surrounding accesses.
     *
     * Note: ptr would be wrong here — it was never modified, so the
     * compiler could satisfy "r"(ptr) without running the loop at all.
     */
    __asm__ volatile ("" : : "r"(p) : "memory");

    /*
     * Hardware memory barrier: flushes store buffers and ensures the
     * zeroed bytes are visible to the other core before this returns.
     * On Xtensa (ESP32) this emits memw; on RISC-V (ESP32-C3/C6) fence.
     * Safe to remove if this memory is never shared across cores.
     */
    __sync_synchronize();
}

#endif // SECURE_MEMZERO_H