#include "common.S"

.text
.globl _main
.p2align 2
_main:
        stp     x29, x30, [sp, #-16]!
        mov     x29, sp
        stp     x19, x20, [sp, #-16]!
        stp     x21, x22, [sp, #-16]!

        mov     w19, w0
        mov     x20, x1
        mov     w21, #1
        mov     w22, #0

        cmp     w19, #2
        b.lt    3f

1:
        ldr     x1, [x20, x21, lsl #3]
        mov     x0, #STDOUT_FILENO
        bl      _write_cstr
        orr     w22, w22, w0

        add     w21, w21, #1
        cmp     w21, w19
        b.ge    3f

        mov     x0, #STDOUT_FILENO
        mov     w1, #ASCII_SPACE
        bl      _write_byte
        orr     w22, w22, w0
        b       1b

3:
        mov     x0, #STDOUT_FILENO
        mov     w1, #ASCII_LF
        bl      _write_byte
        orr     w22, w22, w0

        and     w0, w22, #1
        ldp     x21, x22, [sp], #16
        ldp     x19, x20, [sp], #16
        ldp     x29, x30, [sp], #16
        ret
