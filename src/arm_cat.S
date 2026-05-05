#include "common.S"

.equ BUF_SIZE, 16384

.text
.globl _main
.p2align 2
_main:
        stp     x29, x30, [sp, #-16]!
        mov     x29, sp
        stp     x19, x20, [sp, #-16]!
        stp     x21, x22, [sp, #-16]!
        stp     x23, x24, [sp, #-16]!

        mov     w19, w0
        mov     x20, x1
        mov     w21, #1
        mov     w22, #0

        cmp     w19, #2
        b.ge    1f
        mov     x0, #STDIN_FILENO
        bl      _copy_fd_to_stdout
        b       5f

1:
        ldr     x23, [x20, x21, lsl #3]
        mov     x0, x23
        mov     x1, #O_RDONLY
        mov     x2, #0
        SYSCALL SYS_OPEN
        b.cs    3f

        mov     x24, x0
        bl      _copy_fd_to_stdout
        orr     w22, w22, w0
        mov     x0, x24
        SYSCALL SYS_CLOSE
        b       4f

3:
        mov     w22, #1
        adrp    x1, msg_open@PAGE
        add     x1, x1, msg_open@PAGEOFF
        mov     x0, #STDERR_FILENO
        bl      _write_cstr
        mov     x0, #STDERR_FILENO
        mov     x1, x23
        bl      _write_cstr
        mov     x0, #STDERR_FILENO
        mov     w1, #ASCII_LF
        bl      _write_byte

4:
        add     w21, w21, #1
        cmp     w21, w19
        b.lt    1b
        mov     w0, w22

5:
        ldp     x23, x24, [sp], #16
        ldp     x21, x22, [sp], #16
        ldp     x19, x20, [sp], #16
        ldp     x29, x30, [sp], #16
        ret

.p2align 2
_copy_fd_to_stdout:
        stp     x29, x30, [sp, #-16]!
        mov     x29, sp
        stp     x19, x20, [sp, #-16]!
        stp     x21, x22, [sp, #-16]!

        mov     x19, x0
        adrp    x20, io_buf@PAGE
        add     x20, x20, io_buf@PAGEOFF

1:
        mov     x0, x19
        mov     x1, x20
        mov     x2, #BUF_SIZE
        SYSCALL SYS_READ
        b.cs    3f
        cbz     x0, 2f

        mov     x2, x0
        mov     x0, #STDOUT_FILENO
        mov     x1, x20
        bl      _write_all
        cbnz    x0, 3f
        b       1b

2:
        mov     x0, #0
        b       4f

3:
        adrp    x1, msg_io@PAGE
        add     x1, x1, msg_io@PAGEOFF
        mov     x0, #STDERR_FILENO
        bl      _write_cstr
        mov     x0, #1

4:
        ldp     x21, x22, [sp], #16
        ldp     x19, x20, [sp], #16
        ldp     x29, x30, [sp], #16
        ret

.data
msg_open:
        .asciz "arm-cat: cannot open: "
msg_io:
        .asciz "arm-cat: I/O error\n"

.bss
.p2align 4
io_buf:
        .space BUF_SIZE
