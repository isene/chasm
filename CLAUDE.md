# CHasm ARM repo guidance

This checkout is the ARM/Darwin working repo for CHasm-style tools. It
is not only an umbrella README anymore: it contains AArch64 assembly
sources, a Makefile, and local tests.

## Current target

- Host: macOS/Darwin on arm64.
- Assembler/linker: Apple Command Line Tools via `clang -arch arm64`.
- Output: small terminal/file tools in `bin/`.
- Build: `make all`.
- Verification: `make test`.

The Makefile intentionally refuses non-Darwin or non-arm64 hosts until
there is a second tested target.

## Current tools

| Tool | Source | Purpose |
| --- | --- | --- |
| `arm-echo` | `src/arm_echo.S` | Print argv, separated by spaces. |
| `arm-cat` | `src/arm_cat.S` | Copy stdin or files to stdout. |
| `arm-upper` | `src/arm_upper.S` | Uppercase ASCII bytes. |
| `arm-lines` | `src/arm_lines.S` | Count newline bytes. |

Shared helpers live in `src/common.S`.

## Assembly conventions

- Use AArch64 Darwin syntax accepted by Apple clang/as.
- Export `_main`, not `_start`, unless the repo intentionally moves to
  a fully custom Mach-O entry path.
- Keep file I/O on direct Darwin syscalls (`svc #0x80`) where practical.
- Preserve callee-saved registers (`x19`-`x28`, `x29`, `x30`) in helper
  routines.
- Keep buffers in BSS and avoid heap allocation.
- Prefer simple loops and explicit error paths over clever code.
- After changing assembly, run `make test`.

macOS executables normally link libSystem for process startup. That is
acceptable for this repo while the useful work remains in assembly and
the hot file paths use direct syscalls.

## Project direction

The upstream CHasm suite is Linux/x86_64 and X11-focused. This repo's
purpose is to make working ARM tools on this Apple Silicon machine first.
Do not reintroduce claims that this repo is only a pointer page. New
tools should be buildable locally, documented in `README.md`, added to
`TOOLS` in the Makefile, and covered by `scripts/test.sh`.

## Static docs

The `docs/` directory mirrors the current ARM repo state. When changing
the tool list or build story, update both `README.md` and
`docs/index.html`.
