/* linker.ld
 * Links loader.o and kernel.o into a flat binary starting at 0x1000.
 * boot.asm jumps to 0x1000, which is the entry point of loader.asm (start).
 */

ENTRY(start)

SECTIONS
{
    . = 0x1000;

    .text : {
        *(.text)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data)
    }

    .bss : {
        *(.bss)
        *(COMMON)
    }
}
