# Makefile for MrB-Kernel
# Requires: nasm, i686-elf-g++, i686-elf-ld, python3 + Pillow, dd, truncate
#
# Quick start:
#   make clean && make all
#   qemu-system-i386 -fda os-image.img -boot a

ASM    = nasm
CC     = i686-elf-g++
LD     = i686-elf-ld

CFLAGS  = -m32 -ffreestanding -fno-exceptions -fno-rtti -O2 -Wall -Wextra
LDFLAGS = -m elf_i386 -T linker.ld

# -----------------------------------------------------------------------
# Top-level target
# -----------------------------------------------------------------------
.PHONY: all clean

all: os-image.img

# -----------------------------------------------------------------------
# Floppy image (padded to exact 1.44 MB so QEMU / real hardware accepts it)
# -----------------------------------------------------------------------
os-image.img: os-image.bin
	cp os-image.bin os-image.img
	truncate -s 1474560 os-image.img

# -----------------------------------------------------------------------
# Raw disk image: bootloader | kernel | image data
# -----------------------------------------------------------------------
os-image.bin: boot.bin kernel.bin tomo_palette.bin tomo_pixels.bin
	cat boot.bin kernel.bin tomo_palette.bin tomo_pixels.bin > os-image.bin

# -----------------------------------------------------------------------
# Bootloader — assembled AFTER kernel.bin exists so we know KERNEL_SECTORS.
# Using shell-script style (single multi-line recipe) so the variable computed
# in the first line is visible to the NASM command on the last line.
# The -dKERNEL_SECTORS=N flag sets the NASM preprocessor symbol; boot.asm uses
# %ifndef so this command-line value takes precedence over the fallback %define.
# -----------------------------------------------------------------------
boot.bin: boot.asm kernel.bin
	@KSIZE=$$(stat -c%s kernel.bin); \
	KSECTORS=$$(( ($$KSIZE + 511) / 512 )); \
	echo "  kernel.bin = $$KSIZE bytes = $$KSECTORS sectors"; \
	$(ASM) -f bin boot.asm -o boot.bin -dKERNEL_SECTORS=$$KSECTORS

# -----------------------------------------------------------------------
# Kernel binary (loader + C++ kernel), padded to a 512-byte boundary
# -----------------------------------------------------------------------
loader.o: loader.asm
	$(ASM) -f elf32 loader.asm -o loader.o

kernel.o: kernel.cpp
	$(CC) $(CFLAGS) -c kernel.cpp -o kernel.o

kernel.elf: loader.o kernel.o
	$(LD) $(LDFLAGS) -o kernel.elf loader.o kernel.o

kernel.bin: kernel.elf
	objcopy -O binary kernel.elf kernel.bin
	@# Pad to a multiple of 512 bytes so sector counts are exact
	@KSIZE=$$(stat -c%s kernel.bin); \
	PAD=$$(( (512 - ($$KSIZE % 512)) % 512 )); \
	if [ $$PAD -gt 0 ]; then \
	    dd if=/dev/zero bs=1 count=$$PAD >> kernel.bin conv=notrunc status=none; \
	fi

# -----------------------------------------------------------------------
# Image data — convert.py produces palette (768 B) and pixels (64000 B)
# -----------------------------------------------------------------------
tomo_palette.bin tomo_pixels.bin: tomo.png convert.py
	python3 convert.py tomo.png

# -----------------------------------------------------------------------
clean:
	rm -f *.o *.bin *.elf *.img tomo_palette.bin tomo_pixels.bin
