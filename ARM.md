# CHasm ARM port

Small experimental AArch64 / Darwin arm64 tools that follow the
CHasm style on Apple Silicon. The upstream CHasm suite remains
Linux/x86_64 (see `README.md` and the per-project repos under
[github.com/isene](https://github.com/isene)); this directory is
the working surface for an arm64 macOS port.

## Tools

| Tool | Source | Purpose |
| --- | --- | --- |
| `arm-echo`  | `src/arm_echo.S`  | Print argv, separated by spaces. |
| `arm-cat`   | `src/arm_cat.S`   | Copy stdin or files to stdout. |
| `arm-upper` | `src/arm_upper.S` | Uppercase ASCII bytes. |
| `arm-lines` | `src/arm_lines.S` | Count newline bytes. |

Shared helpers live in `src/common.S`.

## Build

```sh
make all          # writes to bin/
make test         # builds + runs scripts/test.sh
make install      # installs to ~/.local/bin (override with PREFIX=)
make uninstall
```

The Makefile refuses to build on non-Darwin or non-arm64 hosts until
a second target is tested.

## Conventions

- AArch64 Darwin syntax accepted by Apple clang/as.
- Export `_main`, not `_start`.
- Direct Darwin syscalls (`svc #0x80`) for file I/O.
- Preserve callee-saved registers (`x19`-`x28`, `x29`, `x30`) in
  helper routines.
- Buffers in BSS, no heap allocation.
- Simple loops and explicit error paths over clever code.
- Run `make test` after touching assembly.

macOS executables link libSystem for process startup; that is the
normal Darwin executable ABI. The useful work stays in assembly and
the hot file paths use direct syscalls.
