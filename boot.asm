; boot.asm
; Stage 1 bootloader. Loaded by BIOS at 0x7C00.
; Responsibilities:
;   1. Load the kernel (loader + kernel.cpp) to 0x1000
;   2. Enable the A20 line
;   3. Load the raw image data (palette + pixels) to 0x90000
;   4. Jump to the loader at 0x1000
;
; Disk layout (512-byte sectors):
;   Sector 1        : boot.asm  (this file)
;   Sectors 2..N+1  : kernel.bin (loader.asm + kernel.cpp), N = KERNEL_SECTORS
;   Sectors N+2..   : tomo_palette.bin + tomo_pixels.bin  (127 sectors = 65024 bytes)
;
; Image is placed at physical 0x90000 (segment 0x9000, offset 0x0000).
; kernel.cpp MUST read from 0x90000. The palette occupies the first 768 bytes,
; pixels immediately follow at 0x90000 + 768.

%define KERNEL_SECTORS 10   ; overridden by the Makefile via -dKERNEL_SECTORS=N

bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; stack grows down from 0x7C00

    mov [boot_drive], dl    ; BIOS passes boot drive in DL — save it!

    ; -----------------------------------------------------------------------
    ; Step 1: Load kernel to 0x0000:0x1000 (physical 0x1000)
    ; -----------------------------------------------------------------------
    mov bx, 0x1000          ; es:bx = 0x0000:0x1000 = physical 0x1000
    mov dl, [boot_drive]
    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0               ; cylinder 0
    mov cl, 2               ; start at sector 2 (sector 1 is this bootloader)
    mov dh, 0               ; head 0
    int 0x13
    jc  disk_error

    ; -----------------------------------------------------------------------
    ; Step 2: Enable A20 gate via Fast A20 (port 0x92)
    ; -----------------------------------------------------------------------
    in  al, 0x92
    or  al, 2
    out 0x92, al

    ; -----------------------------------------------------------------------
    ; Step 3: Load image data (palette + pixels) to physical 0x90000
    ;         segment 0x9000 × 16 = 0x90000
    ;         127 sectors × 512 bytes = 65024 bytes  (768 palette + 64000 pixels
    ;         + 256 padding to fill last sector — harmless)
    ; -----------------------------------------------------------------------
    mov ax, 0x9000
    mov es, ax              ; es = 0x9000  →  base physical address 0x90000
    xor bx, bx              ; start at offset 0 within that segment

    ; Image sectors begin right after the kernel sectors.
    ; LBA 0 = boot sector, LBA 1..KERNEL_SECTORS = kernel, LBA KERNEL_SECTORS+1 = image start
    mov di, KERNEL_SECTORS
    inc di                  ; di = first LBA of image data

    mov cx, 127             ; 127 sectors to read

load_loop:
    push cx                 ; save outer loop counter (cx is used by CHS calc)
    push bx                 ; save current buffer offset

    ; ---- LBA → CHS conversion ----
    ; Standard floppy geometry: 18 sectors/track, 2 heads
    mov ax, di
    xor dx, dx
    mov bx, 18
    div bx                  ; ax = track number,  dx = sector index (0-based)
    inc dx
    mov cl, dl              ; sector number (1-based, 1..18)

    xor dx, dx
    mov bx, 2
    div bx                  ; ax = cylinder,  dx = head
    mov ch, al              ; cylinder
    mov dh, dl              ; head

    pop bx                  ; restore buffer offset for the BIOS call
    mov dl, [boot_drive]    ; drive number
    mov ax, 0x0201          ; AH=02 read, AL=1 sector
    int 0x13
    jc  disk_error

    add bx, 512             ; advance buffer pointer by one sector
    inc di                  ; advance LBA counter

    pop cx
    loop load_loop

    ; -----------------------------------------------------------------------
    ; Step 4: Jump to loader at 0x0000:0x1000
    ; -----------------------------------------------------------------------
    jmp 0x0000:0x1000

; -----------------------------------------------------------------------
disk_error:
    ; Hang on error. In a real OS you'd print a message; here we just halt.
    hlt
    jmp disk_error

; -----------------------------------------------------------------------
boot_drive: db 0

times 510-($-$$) db 0
dw 0xAA55
