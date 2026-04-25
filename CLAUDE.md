# CHasm — group repo guidance

This is the umbrella repo for the **CHasm** suite. The repo itself
holds no code — it's a README + screenshot index pointing at the
individual project repos. This `CLAUDE.md` exists so any new CC
session lands on the same understanding of *what CHasm is for* and
*what the suite-wide rules are* before touching anything.

## What CHasm is

A small family of Linux desktop tools written **entirely in x86_64
NASM assembly**, each one a single static ELF binary with **no libc,
no toolkits, no dynamic linking, no runtime** — just direct
syscalls and (for graphical tools) the X11 wire protocol.

The current binaries:

| Tool | Purpose |
|------|---------|
| **bare**       | Interactive shell |
| **glass**      | X11 terminal emulator |
| **tile**       | Tiling window manager |
| **strip**      | X11 status bar (lives in the tile repo) |
| **chasm-bits** | "Asmites" — tiny status-bar segment programs |
| **show**       | Pager / file viewer with syntax highlighting |
| **glyph**      | TrueType / OpenType rasterizer |

Together they make up a complete X session in **under 500 KB** of
executable code with **zero shared libraries** to update or break.

## Why

Modern stacks are deep. A normal terminal loads 30+ `.so` files
before drawing a single character. CHasm strips that away to find
out what you actually need. The answer turns out to be: very little.
The Linux kernel exposes syscalls; X11 is a documented Unix-socket
wire protocol; everything else is a choice. CHasm is the choice to
write that everything else, by hand, in the smallest reasonable
language.

## Suite-wide design rules

Every project in the suite follows the same three rules, in priority
order. These are the "heart" of CHasm — when adding a feature, ask
which rule is being served and whether the cost is justified.

### 1. No wasted CPU cycles

- Gate every feature so its code path is fully cold when not in use.
  Compare target state to last-applied state before doing X11 / file
  / syscall work. Don't fire-and-forget work whose result is
  identical to what's already on screen / disk.
- Optional features get an explicit config flag and an early-return
  fast path. A "for some users" feature that runs unconditionally
  for everyone is waste.

### 2. Lightning fast

- Microsecond startup. bare comes up in ~9 µs.
- Instantaneous user feedback. No interpreters in the hot path (no
  awk/sed/perl/python in shell helpers — bash builtins or asm only).
- Cache anything that doesn't change between invocations (PATH cache,
  thermal-zone path, atom IDs, etc.). Single-digit-ms is fine;
  double-digit-ms wants justification.

### 3. More battery life

- Goal #1 + #2 together. Anything that polls, wakes, or spawns
  subprocesses on a timer is suspect. Prefer filesystem watches /
  `select` / blocking reads on Unix sockets to forks; prefer `stat()`
  to `fork()`.
- A 1 Hz status segment that forks 3 helpers per refresh = 86,400
  forks/day for one segment. The "no shell-out" rule isn't aesthetic.

## Shared technical conventions

- **Pure x86_64 NASM**, no libc, no `int 0x80` (only `syscall`)
- **Build pattern**: `nasm -f elf64 file.asm -o file.o && ld file.o -o file`
- **Single static ELF**, no dynamic linking, no `.so` dependencies
- **All BSS, no malloc** — every buffer is statically allocated
- **Plain config files** (`~/.barerc`, `~/.glassrc`, `~/.tilerc`,
  `~/.striprc`) — line-based key=value, no JSON/TOML/YAML parser
  needed. Configurators (bareconf etc.) write these files atomically
  via `.tmp → .bak → publish` rename dance.
- **Unlicense** — public domain

## Dual repo: configurator companions

Each end-user-facing tool ships an optional Rust TUI configurator
(built on [crust](https://github.com/isene/crust)) so users can edit
the rc files visually:

| Configurator | Repo | Edits |
|--------------|------|-------|
| bareconf  | https://github.com/isene/bareconf  | `~/.barerc`  |
| glassconf | https://github.com/isene/glassconf | `~/.glassrc` |
| tileconf  | https://github.com/isene/tileconf  | `~/.tilerc`  |
| stripconf | https://github.com/isene/stripconf | `~/.striprc` |

These are the *only* CHasm-adjacent tools written in something other
than asm; writing a TUI configurator in pure asm would defeat the
whole point. They share the same atomic-save pattern so a kill
mid-write can never blank a config (`mv ~/.<tool>rc.bak
~/.<tool>rc` always restores the previous good state).

## When working in a CHasm repo

1. **Read the project's own CLAUDE.md first** — each repo
   (bare/glass/tile/show/chasm-bits/glyph) has one with
   project-specific architecture, key code sections, and gotchas.
2. **Read the global `x86_64-asm` skill** — covers 15 critical NASM
   pitfalls, syscall convention, register convention, X11 patterns,
   PTY handling, ARGB transparency, ConfigureRequest pass-through,
   etc. Most "I broke something" moments map to one of those pitfalls.
3. **Follow the three rules above** before adding anything.
4. **Build + test before claiming done**:
   ```bash
   nasm -f elf64 file.asm -o file.o && ld file.o -o file
   echo -e 'cmd\nexit' | ./binary 2>&1     # for non-X tools
   strace -f -c ./binary cmd 2>&1 | tail   # if performance is the question
   ```

## When updating this group repo

- The umbrella `README.md` is the public-facing landing page.
- The `img/` dir holds `chasm.svg` (logo) and `screenshot.png`
  (referenced by README).
- There is no source code here. Don't add any — that work belongs
  in one of the project repos.
- When the suite grows (new asm project, new conf companion), update
  README's "tools" / "configurators" tables AND add/remove the
  pointer in this file.
