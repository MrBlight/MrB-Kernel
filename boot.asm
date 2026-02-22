; boot.asm
; Stage-1 bootloader — loaded by BIOS at 0x7C00 (512 bytes, MBR).
;
; Disk layout (512-byte sectors):
;   LBA  0          : this bootloader
;   LBA  1 .. N     : kernel binary (loader.asm + kernel.cpp), N = KERNEL_SECTORS
;   LBA  N+1 ..     : image data (tomo_palette.bin + tomo_pixels.bin, 127 sectors)
;
; Physical memory after loading:
;   0x1000  ..       : kernel code (loader then kernel_main)
;   0x90000 ..       : image data  (palette 768 B then pixels 64000 B)
;
; *** SUPER DUPER IMPORTANT NOTE ON NASM DEFINES ***
; NASM -d command-line defines have LOWER precedence than %define in the source.
; A plain "%define KERNEL_SECTORS 10" would silently OVERRIDE the Makefile value,
; making KERNEL_SECTORS always 10 regardless of the actual kernel size.
; Using %ifndef ensures the Makefile-supplied -dKERNEL_SECTORS=N wins.

%ifndef KERNEL_SECTORS
  %define KERNEL_SECTORS 10   ; safe fallback only — Makefile always overrides
%endif

bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl    ; BIOS puts boot drive in DL — save it immediately

    ; -----------------------------------------------------------------------
    ; Step 1: Load kernel to physical 0x1000, one sector at a time.
    ;         Sector-by-sector is safer than a single multi-sector call because
    ;         some BIOSes refuse to cross track boundaries in one call.
    ; -----------------------------------------------------------------------
    mov si, 1               ; si = current LBA (LBA 1 = sector after boot)
    mov di, KERNEL_SECTORS  ; di = remaining sectors to read
    mov bx, 0x1000          ; buffer offset  (es = 0x0000)

.kernel_loop:
    test di, di
    jz .kernel_done

    call lba_to_chs         ; converts si → ch (cyl), cl (sec), dh (head)
    mov dl, [boot_drive]
    mov ax, 0x0201          ; INT 13h: read 1 sector
    int 0x13
    jc  disk_error

    inc si                  ; next LBA
    dec di                  ; one fewer sector to go
    add bx, 512             ; advance buffer

    ; If bx wraps, slide es up by 4 KB (avoids a 64KB-boundary DMA fault for
    ; very large kernels — unlikely here but keeps things correct).
    jnc .kernel_loop
    mov ax, es
    add ax, 0x1000
    mov es, ax
    jmp .kernel_loop

.kernel_done:
    xor ax, ax
    mov es, ax              ; reset es = 0x0000

    ; -----------------------------------------------------------------------
    ; Step 2: Enable A20 via Fast A20 (port 0x92).
    ; -----------------------------------------------------------------------
    in  al, 0x92
    or  al, 2
    and al, 0xFE            ; keep system reset bit (bit 0) clear!
    out 0x92, al

    ; -----------------------------------------------------------------------
    ; Step 3: Load image data to physical 0x90000 (segment 0x9000 × 16 = 0x90000).
    ;         palette.bin (768 B) + pixels.bin (64000 B) = 64768 B = 127 sectors.
    ;         First image LBA = KERNEL_SECTORS + 1  (right after the kernel).
    ; -----------------------------------------------------------------------
    mov ax, 0x9000
    mov es, ax
    xor bx, bx              ; es:bx = 0x9000:0x0000

    mov si, KERNEL_SECTORS
    inc si                  ; si = first LBA of image data

    mov cx, 127             ; 127 sectors × 512 B = 65024 B ≥ 64768 B needed

.image_loop:
    push cx
    push bx

    call lba_to_chs         ; si → ch/cl/dh
    pop bx
    mov dl, [boot_drive]
    mov ax, 0x0201
    int 0x13
    jc  disk_error

    add bx, 512
    inc si

    pop cx
    loop .image_loop

    ; -----------------------------------------------------------------------
    ; Step 4: Jump to loader at 0x0000:0x1000.
    ; -----------------------------------------------------------------------
    jmp 0x0000:0x1000

; -----------------------------------------------------------------------
; lba_to_chs: converts LBA in SI to CHS registers CH, CL, DH.
;   Floppy geometry: 18 sectors/track, 2 heads.
;   Clobbers: AX, DX, CX (as temp).  Returns: CH=cylinder, CL=sector(1-based), DH=head.
; -----------------------------------------------------------------------
lba_to_chs:
    mov ax, si
    xor dx, dx
    mov cx, 18
    div cx                  ; AX = track, DX = sector index (0-based)
    inc dx
    mov cl, dl              ; CL = sector (1-based, 1..18)

    xor dx, dx
    mov cx, 2
    div cx                  ; AX = cylinder, DX = head
    mov ch, al              ; CH = cylinder
    mov dh, dl              ; DH = head
    ret

; -----------------------------------------------------------------------
disk_error:
    hlt
    jmp disk_error

; -----------------------------------------------------------------------
boot_drive: db 0

times 510-($-$$) db 0
dw 0xAA55
