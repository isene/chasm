# CHasm ARM

Native ARM64 assembly tools for this Apple Silicon machine.

This repo started as the upstream CHasm umbrella page for Linux/x86_64
desktop tools. This checkout is now the ARM/Darwin working surface: it
contains buildable AArch64 assembly programs, a Makefile, and tests that
run on macOS arm64.

The original CHasm idea still guides the style: small tools, direct
syscalls for the hot path, simple source, and no dependency stack. macOS
programs still link through libSystem for process startup, which is the
normal Darwin executable ABI; the tools themselves use ARM64 assembly and
Darwin syscalls for file I/O.

## Tools

| Tool | Purpose |
| --- | --- |
| `arm-echo` | Print arguments separated by spaces, then a newline. |
| `arm-cat` | Copy stdin or files to stdout. |
| `arm-upper` | Uppercase ASCII bytes from stdin or files. |
| `arm-lines` | Count newline bytes from stdin or files. |

The tools are intentionally small and currently focus on terminal/file
work that can be verified locally on macOS. They are the seed for a real
ARM suite rather than another pointer page.

## Build

```sh
make all
```

This writes binaries to `bin/`:

```sh
bin/arm-echo hello arm64
printf 'aBc\n' | bin/arm-upper
bin/arm-cat README.md | bin/arm-lines
```

The Makefile refuses to build on non-Darwin or non-arm64 hosts for now.

## Test

```sh
make test
```

The `make test` target builds the tools and checks argument handling,
stdin, file input, uppercase filtering, and line-count output.

## Install

```sh
make install
```

By default this copies the tools to `~/.local/bin`. Override the prefix
when needed:

```sh
make install PREFIX=/opt/chasm-arm
```

Remove installed binaries with:

```sh
make uninstall
```

## Source Layout

| Path | Contents |
| --- | --- |
| `src/common.S` | Shared Darwin syscall helpers and decimal printing. |
| `src/arm_echo.S` | `arm-echo` entry point. |
| `src/arm_cat.S` | `arm-cat` file/stdin copy loop. |
| `src/arm_upper.S` | `arm-upper` filter loop. |
| `src/arm_lines.S` | `arm-lines` newline counter. |
| `scripts/test.sh` | Local verification script. |
| `docs/` | Static landing page matching this ARM repo. |

## Original CHasm

Upstream CHasm is Geir Isene's Linux/x86_64 assembly desktop suite:

- `bare`: shell
- `glass`: X11 terminal emulator
- `tile` and `strip`: window manager and status bar
- `show`: pager
- `glyph`: font rasterizer
- `bolt`: screen locker
- `chasm-bits`: status-bar segment tools

Those projects remain Linux/x86_64 and live under
<https://github.com/isene>. This repo is the Apple Silicon ARM branch of
the idea.
