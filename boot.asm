; boot.asm - CHS conversion should be fixed with preserved buffer pointer added drive number and error checks
%define KERNEL_SECTORS 10  ; overridden by the Makefile

bits 16
org 0x7c00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Load kernel to 0x1000
    mov bx, 0x1000
    mov dl, 0          ; drive 0 (floppy)
    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0
    mov cl, 2
    mov dh, 0
    int 0x13
    jc disk_error
    cmp ah, 0
    jne disk_error

    ; Enable A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Load image data to 0x90000 (127 sectors)
    mov ax, 0x9000
    mov es, ax
    xor bx, bx

    mov di, KERNEL_SECTORS
    inc di             ; 0-based starting LBA for image (after kernel)

    mov cx, 127

load_loop:
    push cx
    push bx            ; save buffer offset

    mov ax, di
    xor dx, dx
    mov bx, 18
    div bx             ; ax = LBA / 18, dx = LBA % 18

    inc dl             ; sector 1-18
    mov cl, dl

    mov bx, ax         ; save LBA / 18
    xor dx, dx
    mov ax, bx
    mov bx, 2
    div bx             ; ax = cylinder, dx = head

    mov ch, al         ; cylinder
    mov dh, dl         ; head

    pop bx             ; restore buffer offset
    mov dl, 0          ; drive
    mov ax, 0x0201
    int 0x13
    jc disk_error
    cmp ah, 0
    jne disk_error

    add bx, 512
    inc di

    pop cx
    loop load_loop

    jmp 0x0000:0x1000

disk_error:
    hlt
    jmp disk_error

times 510-($-$$) db 0
dw 0xAA55