#ifndef CHASM_ARM_COMMON_S
#define CHASM_ARM_COMMON_S

.equ SYS_EXIT, 1
.equ SYS_READ, 3
.equ SYS_WRITE, 4
.equ SYS_OPEN, 5
.equ SYS_CLOSE, 6

.equ STDIN_FILENO, 0
.equ STDOUT_FILENO, 1
.equ STDERR_FILENO, 2

.equ O_RDONLY, 0
.equ ASCII_LF, 10
.equ ASCII_SPACE, 32

.macro SYSCALL number
        mov     x16, #\number
        svc     #0x80
.endm

.text
.p2align 2
_write_all:
        stp     x29, x30, [sp, #-16]!
        mov     x29, sp
        stp     x19, x20, [sp, #-16]!
        stp     x21, x22, [sp, #-16]!

        mov     x19, x0
        mov     x20, x1
        mov     x21, x2
        cbz     x21, 2f

1:
        mov     x0, x19
        mov     x1, x20
        mov     x2, x21
        SYSCALL SYS_WRITE
        b.cs    3f
        cbz     x0, 3f
        add     x20, x20, x0
        sub     x21, x21, x0
        cbnz    x21, 1b

2:
        mov     x0, #0
        b       4f
3:
        mov     x0, #1
4:
        ldp     x21, x22, [sp], #16
        ldp     x19, x20, [sp], #16
        ldp     x29, x30, [sp], #16
        ret

.p2align 2
_write_cstr:
        stp     x29, x30, [sp, #-16]!
        mov     x29, sp
        stp     x19, x20, [sp, #-16]!
        stp     x21, x22, [sp, #-16]!

        mov     x19, x0
        mov     x20, x1
        mov     x21, #0

1:
        ldrb    w22, [x20, x21]
        cbz     w22, 2f
        add     x21, x21, #1
        b       1b

2:
        mov     x0, x19
        mov     x1, x20
        mov     x2, x21
        bl      _write_all

        ldp     x21, x22, [sp], #16
        ldp     x19, x20, [sp], #16
        ldp     x29, x30, [sp], #16
        ret

.p2align 2
_write_byte:
        stp     x29, x30, [sp, #-16]!
        mov     x29, sp
        sub     sp, sp, #16
        strb    w1, [sp]
        mov     x1, sp
        mov     x2, #1
        bl      _write_all
        add     sp, sp, #16
        ldp     x29, x30, [sp], #16
        ret

.p2align 2
_print_u64:
        stp     x29, x30, [sp, #-16]!
        mov     x29, sp
        stp     x19, x20, [sp, #-16]!
        stp     x21, x22, [sp, #-16]!
        stp     x23, x24, [sp, #-16]!

        mov     x19, x0
        adrp    x20, _number_buf@PAGE
        add     x20, x20, _number_buf@PAGEOFF
        add     x21, x20, #32
        mov     x23, #10

        cbnz    x19, 1f
        sub     x21, x21, #1
        mov     w22, #'0'
        strb    w22, [x21]
        b       3f

1:
        udiv    x22, x19, x23
        msub    x24, x22, x23, x19
        add     w24, w24, #'0'
        sub     x21, x21, #1
        strb    w24, [x21]
        mov     x19, x22
        cbnz    x19, 1b

3:
        add     x2, x20, #32
        sub     x2, x2, x21
        mov     x0, #STDOUT_FILENO
        mov     x1, x21
        bl      _write_all

        ldp     x23, x24, [sp], #16
        ldp     x21, x22, [sp], #16
        ldp     x19, x20, [sp], #16
        ldp     x29, x30, [sp], #16
        ret

.bss
.p2align 4
_number_buf:
        .space 32

#endif
