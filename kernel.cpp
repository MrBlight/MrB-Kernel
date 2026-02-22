// kernel.cpp
// Reads a Mode 13h image (raw palette + pixels) from 0x90000 and blasts it
// straight onto the VGA framebuffer at 0xA0000.
//
// Memory layout set up by boot.asm:
//   0x90000 ..+767  : palette  (256 × 3 bytes, already right-shifted to 6-bit
//                               by convert.py so we write them directly to DAC)
//   0x90000 +768 .. : pixels   (320 × 200 = 64 000 bytes, one byte per pixel)
//
// NOTE: 0x20000 in the original source was WRONG — boot.asm always loaded the
// image to physical 0x90000 (segment 0x9000 × 16).  Changed here to match.

#include <stdint.h>

static inline void outb(uint16_t port, uint8_t val)
{
    asm volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline uint8_t inb(uint16_t port)
{
    uint8_t ret;
    asm volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

// Spin until the VGA vertical-retrace signal arrives.
// This prevents palette writes from tearing and stops flicker.
static void wait_vretrace()
{
    while ( inb(0x3DA) & 0x08);   // wait for retrace to END  (in case we caught it mid-pulse)
    while (~inb(0x3DA) & 0x08);   // wait for next retrace to BEGIN
}

extern "C" void kernel_main()
{
    // -----------------------------------------------------------------------
    // Image data base — MUST match the address boot.asm loaded to.
    // boot.asm: mov ax, 0x9000 / mov es, ax  →  physical base = 0x9000 × 16 = 0x90000
    // -----------------------------------------------------------------------
    const uint8_t* const image_base = reinterpret_cast<const uint8_t*>(0x90000);
    const uint8_t* const palette    = image_base;           // 768 bytes
    const uint8_t* const pixels     = image_base + 768;     // 64 000 bytes

    wait_vretrace();

    // -----------------------------------------------------------------------
    // Program the VGA DAC palette.
    // Write index 0, then stream all 768 component bytes (R, G, B per entry).
    // convert.py already right-shifts each component by 2 so they are 6-bit.
    // -----------------------------------------------------------------------
    outb(0x3C8, 0);
    for (int i = 0; i < 768; i++) {
        outb(0x3C9, palette[i]);
    }

    // -----------------------------------------------------------------------
    // Copy all 64 000 pixels to the VGA linear framebuffer.
    // Mode 13h maps one byte → one pixel starting at 0xA0000.
    // -----------------------------------------------------------------------
    uint8_t* const vga = reinterpret_cast<uint8_t*>(0xA0000);
    for (uint32_t i = 0; i < 64000u; i++) {
        vga[i] = pixels[i];
    }

    // -----------------------------------------------------------------------
    // Spin forever — the image stays on screen.
    // -----------------------------------------------------------------------
    for (;;) {
        asm volatile ("hlt");
    }
}
