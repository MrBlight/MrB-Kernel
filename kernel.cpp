// kernel.cpp - byte-by-byte copy for a perfect mode 13h rendering (hopefully)
// There is no screen clear (to avoid stupid black screen hell)
// Palette is loaded directly (convert.py already handles >>2 to 6-bit)
// Address is locked to 0x20000 (matches the boot.asm image loading thing)

#include <stdint.h>

static inline void outb(uint16_t port, uint8_t val) {
    asm volatile ("outb %0,%1" : : "a" (val), "Nd" (port));
}

static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    asm volatile ("inb %1,%0" : "=a" (ret) : "Nd" (port));
    return ret;
}

// Wait for vertical retrace to prevent flicker and palette glitches
static inline void wait_vretrace() {
    while (inb(0x3DA) & 0x08);
    while (!(inb(0x3DA) & 0x08));
}

extern "C" void kernel_main() {
    const uint8_t* image_base = (const uint8_t*)0x20000;  // Exact address from boot.asm
    const uint8_t* palette = image_base;
    const uint8_t* pixels = image_base + 768;

    wait_vretrace();

    // Load palette (768 bytes and pre-shifted to 6-bit by convert.py)
    outb(0x3C8, 0);
    for (int i = 0; i < 768; i++) {
        outb(0x3C9, palette[i]);
    }

    // Copy all the 64000 pixels byte-by-byte (fixing the stripes/distortion and it the fills entire screen)
    uint8_t* vga = (uint8_t*)0xA0000;
    for (uint32_t i = 0; i < 64000; i++) {
        vga[i] = pixels[i];
    }

    // Hang forever on the image
    while (1) {
        asm volatile ("hlt");
    }
}