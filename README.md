# MrB-Kernel

A bare-metal x86 kernel that boots from a floppy image, switches to VGA
Mode 13h (320 × 200, 256 colours), and displays `tomo.png` full-screen.

---

## What was broken and what was fixed

| # | File | Bug | Fix |
|---|------|-----|-----|
| 1 | `kernel.cpp` | **Critical** — image was read from `0x20000` but `boot.asm` loaded it to `0x90000`. Kernel was reading garbage memory. | Changed `image_base` to `0x90000`. |
| 2 | `boot.asm` | Boot drive number (`DL`) was overwritten before being saved, causing potential wrong-drive reads on some machines. | Save `DL` to `boot_drive` on entry; restore before every `int 0x13` call. |
| 3 | `loader.asm` | PIC masking wrote to slave (`0xA1`) before master (`0x21`) — backwards. | Fixed order to master first, then slave. |
| 4 | `loader.asm` | Comment note about stack "below image at 0x90000" confirmed the intent but the address mismatch in the kernel made it moot. Now consistent. | No code change needed — comment clarified. |

> **The address confusion:** `mov ax, 0x9000` in `boot.asm` is *not* the same
> as writing to address `0x9000`.  In real-mode segmented addressing, the
> physical address = segment register × 16, so `0x9000 × 16 = 0x90000`.
> The comment in the original source was actually correct — only `kernel.cpp`
> was wrong.

---

## Memory map

| Region | Contents |
|--------|----------|
| `0x0000 – 0x7BFF` | Stack (grows down from 0x7C00) |
| `0x7C00 – 0x7DFF` | Bootloader (`boot.asm`) |
| `0x1000 – ~0x4FFF` | Loader + kernel code |
| `0x80000` | Kernel stack top (32-bit mode) |
| `0x90000 – 0x9FBFF` | Image data (768 B palette + 64 000 B pixels) |
| `0xA0000 – 0xAF9FF` | VGA framebuffer (Mode 13h) |

---

## Prerequisites

### On Windows (MSYS2 MinGW64) — my original target environment

```bash
# One-time setup
pacman -Syu
pacman -S mingw-w64-x86_64-python mingw-w64-x86_64-python-pillow

# Install i686-elf cross-compiler toolchain
# Download from https://github.com/lordmilko/i686-elf-tools/releases
# Extract to C:\i686-elf-tools, then add to PATH:
export PATH="/c/i686-elf-tools/bin:$PATH"

# Install NASM
pacman -S mingw-w64-x86_64-nasm

# Install QEMU
pacman -S mingw-w64-x86_64-qemu

# Verify Pillow works
python3 -c "from PIL import Image; print('Pillow OK')"
```

### On Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install nasm gcc-multilib binutils build-essential qemu-system-x86 python3-pillow

# Cross-compiler (if apt version doesn't work, get from lordmilko link above)
sudo apt install gcc-i686-linux-gnu binutils-i686-linux-gnu
# Then symlink or adjust CC/LD in Makefile to i686-linux-gnu-g++ / i686-linux-gnu-ld
```

---

## Building

```bash
# Place tomo.png (or your own 320×200-ish image) in the project folder, then:
make clean && make all
```

This will:
1. Run `convert.py tomo.png` → `tomo_palette.bin` + `tomo_pixels.bin`
2. Compile `kernel.cpp` and assemble `loader.asm` → `kernel.bin`
3. Assemble `boot.asm` (auto-detecting `KERNEL_SECTORS`) → `boot.bin`
4. Concatenate everything → `os-image.bin` → padded to 1.44 MB → `os-image.img`

---

## Running

```bash
qemu-system-i386 -fda os-image.img -boot a
```

You can also try `-vga std` instead of the default if colours look wrong.

> **QEMU tip:** Add `-display sdl` or `-display gtk` if the default window
> refuses to appear on your system.

---

## Project structure

```
.
├── boot.asm         Stage-1 bootloader (loads kernel + image, enables A20)
├── loader.asm       Stage-2 loader (Mode 13h, GDT, protected-mode switch)
├── kernel.cpp       C++ kernel (programs VGA palette, blits pixels)
├── linker.ld        Linker script (places code at 0x1000)
├── Makefile         Build system (auto-detects sector counts, pads image)
├── convert.py       PNG → Mode-13h raw palette + pixel data
├── tomo.png         Default image (replace with anything you like)
└── README.md        This file
```

---

## License

GPL-3.0 — see `LICENSE.md`.
