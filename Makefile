# Makefile - Added padding for kernel.bin to ensure exact 512-byte sector multiple (prevents misalignment)
ASM = nasm
CC = i686-elf-g++
LD = i686-elf-ld

CFLAGS = -m32 -ffreestanding -fno-exceptions -fno-rtti -O2 -Wall -Wextra
LDFLAGS = -m elf_i386 -T linker.ld

all: os-image.bin
	cp os-image.bin os-image.img
	truncate -s 1474560 os-image.img

tomo_palette.bin tomo_pixels.bin: tomo.png convert.py
	python3 convert.py tomo.png

boot.bin: boot.asm kernel.bin
	KERNEL_SIZE=$$(stat -c%s kernel.bin); \
	KERNEL_SECTORS=$$(expr $$(($$KERNEL_SIZE + 511)) / 512); \
	$(ASM) -f bin boot.asm -o boot.bin -dKERNEL_SECTORS=$$KERNEL_SECTORS

loader.o: loader.asm
	$(ASM) -f elf32 loader.asm -o loader.o

kernel.o: kernel.cpp
	$(CC) $(CFLAGS) -c kernel.cpp -o kernel.o

kernel.elf: loader.o kernel.o
	$(LD) $(LDFLAGS) -o kernel.elf loader.o kernel.o

kernel.bin: kernel.elf
	objcopy -O binary kernel.elf kernel.bin
	# Pad to multiple of 512 bytes
	KERNEL_SIZE=$$(stat -c%s kernel.bin); \
	PAD_BYTES=$$(( (512 - ($$KERNEL_SIZE % 512)) % 512 )); \
	dd if=/dev/zero bs=1 count=$$PAD_BYTES >> kernel.bin conv=notrunc status=none

os-image.bin: boot.bin kernel.bin tomo_palette.bin tomo_pixels.bin
	cat boot.bin kernel.bin tomo_palette.bin tomo_pixels.bin > os-image.bin

clean:
	rm -f *.o *.bin *.elf *.img tomo_palette.bin tomo_pixels.bin