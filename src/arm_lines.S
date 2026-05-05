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
        stp     x25, x26, [sp, #-16]!

        mov     w19, w0
        mov     x20, x1
        mov     w21, #1
        mov     x22, #0
        mov     w23, #0

        cmp     w19, #2
        b.ge    1f
        mov     x0, #STDIN_FILENO
        bl      _count_lines_fd
        mov     x22, x0
        orr     w23, w23, w1
        mov     x0, x22
        bl      _print_u64
        mov     x0, #STDOUT_FILENO
        mov     w1, #ASCII_LF
        bl      _write_byte
        b       8f

1:
        ldr     x24, [x20, x21, lsl #3]
        mov     x0, x24
        mov     x1, #O_RDONLY
        mov     x2, #0
        SYSCALL SYS_OPEN
        b.cs    5f

        mov     x25, x0
        bl      _count_lines_fd
        mov     x26, x0
        orr     w23, w23, w1
        mov     x0, x25
        SYSCALL SYS_CLOSE

        add     x22, x22, x26
        mov     x0, x26
        bl      _print_u64
        mov     x0, #STDOUT_FILENO
        mov     w1, #ASCII_SPACE
        bl      _write_byte
        mov     x0, #STDOUT_FILENO
        mov     x1, x24
        bl      _write_cstr
        mov     x0, #STDOUT_FILENO
        mov     w1, #ASCII_LF
        bl      _write_byte
        b       6f

5:
        mov     w23, #1
        adrp    x1, msg_open@PAGE
        add     x1, x1, msg_open@PAGEOFF
        mov     x0, #STDERR_FILENO
        bl      _write_cstr
        mov     x0, #STDERR_FILENO
        mov     x1, x24
        bl      _write_cstr
        mov     x0, #STDERR_FILENO
        mov     w1, #ASCII_LF
        bl      _write_byte

6:
        add     w21, w21, #1
        cmp     w21, w19
        b.lt    1b

        cmp     w19, #3
        b.lt    8f
        mov     x0, x22
        bl      _print_u64
        adrp    x1, msg_total@PAGE
        add     x1, x1, msg_total@PAGEOFF
        mov     x0, #STDOUT_FILENO
        bl      _write_cstr

8:
        and     w0, w23, #1
        ldp     x25, x26, [sp], #16
        ldp     x23, x24, [sp], #16
        ldp     x21, x22, [sp], #16
        ldp     x19, x20, [sp], #16
        ldp     x29, x30, [sp], #16
        ret

.p2align 2
_count_lines_fd:
        stp     x29, x30, [sp, #-16]!
        mov     x29, sp
        stp     x19, x20, [sp, #-16]!
        stp     x21, x22, [sp, #-16]!
        stp     x23, x24, [sp, #-16]!

        mov     x19, x0
        mov     x20, #0
        adrp    x21, io_buf@PAGE
        add     x21, x21, io_buf@PAGEOFF

1:
        mov     x0, x19
        mov     x1, x21
        mov     x2, #BUF_SIZE
        SYSCALL SYS_READ
        b.cs    5f
        cbz     x0, 4f

        mov     x22, x0
        mov     x23, #0

2:
        ldrb    w24, [x21, x23]
        cmp     w24, #ASCII_LF
        b.ne    3f
        add     x20, x20, #1

3:
        add     x23, x23, #1
        cmp     x23, x22
        b.lt    2b
        b       1b

4:
        mov     x0, x20
        mov     x1, #0
        b       6f

5:
        adrp    x1, msg_io@PAGE
        add     x1, x1, msg_io@PAGEOFF
        mov     x0, #STDERR_FILENO
        bl      _write_cstr
        mov     x0, x20
        mov     x1, #1

6:
        ldp     x23, x24, [sp], #16
        ldp     x21, x22, [sp], #16
        ldp     x19, x20, [sp], #16
        ldp     x29, x30, [sp], #16
        ret

.data
msg_open:
        .asciz "arm-lines: cannot open: "
msg_io:
        .asciz "arm-lines: I/O error\n"
msg_total:
        .asciz " total\n"

.bss
.p2align 4
io_buf:
        .space BUF_SIZE
