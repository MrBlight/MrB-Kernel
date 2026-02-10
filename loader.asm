; loader.asm
bits 16
extern kernel_main

global start

start:
    cli
    mov ax, 0x0013
    int 0x10  ; set VGA mode 0x13

    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode

bits 32
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Mask all interrupts to prevent faults
    mov al, 0xFF
    out 0xA1, al
    out 0x21, al

    mov esp, 0x80000  ; stack below image at 0x90000
    call kernel_main
    jmp $

gdt_start:
    dq 0  ; null descriptor
gdt_code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 11001111b
    db 0
gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start