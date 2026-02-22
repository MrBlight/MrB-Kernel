; loader.asm
; Stage 2 loader. Linked and placed starting at 0x1000.
; Responsibilities:
;   1. Set VGA Mode 13h (320×200, 256 colour) while still in real mode
;   2. Load a minimal GDT
;   3. Switch to 32-bit protected mode
;   4. Mask all PIC interrupts (we've got no IDT)
;   5. Set up a stack and call kernel_main()

bits 16
extern kernel_main

global start

start:
    cli

    ; Set VGA Mode 13h (320×200 @ 256 colours) — must be done in real mode
    mov ax, 0x0013
    int 0x10

    ; Load GDT and flip the PE bit in CR0
    lgdt [gdt_descriptor]
    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    ; Far jump flushes the instruction prefetch queue and reloads CS
    jmp 0x08:protected_mode

; -----------------------------------------------------------------------
bits 32
protected_mode:
    ; Reload all data-segment registers with the flat data selector (0x10)
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Mask all IRQs on both PICs so spurious interrupts don't triple-fault.
    ; We have no IDT, so any interrupt would be fatal.
    ; Correct order: master PIC (0x21) first, then slave PIC (0xA1).
    mov al, 0xFF
    out 0x21, al            ; mask all IRQs on master PIC
    out 0xA1, al            ; mask all IRQs on slave PIC

    ; Set up a stack safely below the image data at 0x90000
    mov esp, 0x80000

    call kernel_main

    ; kernel_main loops forever, but hang here just in case
.hang:
    hlt
    jmp .hang

; -----------------------------------------------------------------------
; Minimal flat GDT: null + 32-bit code (0x08) + 32-bit data (0x10)
; -----------------------------------------------------------------------
gdt_start:
    dq 0                    ; null descriptor (required)

gdt_code:                   ; selector 0x08 — ring 0 code, 32-bit, 4GB flat
    dw 0xFFFF               ; limit low
    dw 0x0000               ; base low
    db 0x00                 ; base mid
    db 10011010b            ; present | ring0 | code | readable | accessed
    db 11001111b            ; 4KB granularity | 32-bit | limit high = 0xF
    db 0x00                 ; base high

gdt_data:                   ; selector 0x10 — ring 0 data, 32-bit, 4GB flat
    dw 0xFFFF               ; limit low
    dw 0x0000               ; base low
    db 0x00                 ; base mid
    db 10010010b            ; present | ring0 | data | writable | accessed
    db 11001111b            ; 4KB granularity | 32-bit | limit high = 0xF
    db 0x00                 ; base high

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1     ; GDT size - 1
    dd gdt_start                    ; linear address of GDT (correct at link time)
