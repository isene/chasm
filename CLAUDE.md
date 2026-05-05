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

## Asm code-quality conventions

Found in HN review of glass.asm (rep_lodsb,
[item 48008299](https://news.ycombinator.com/item?id=48008299)) and
applied across the suite 2026-05-04. **New code must follow these.**

### 1. No redundant `TEST` after `SUB`

`SUB` already sets ZF/SF correctly. The only branches that need OF
to be explicitly cleared (i.e. for which a separate `TEST` would
matter) are signed comparisons (`jl`/`jle`/`jg`/`jge`). Bare
`jz`/`jnz`/`js`/`jns` after `sub r, x` reads SUB's flags directly.

```asm
; Bad
sub  rdx, rcx
test rdx, rdx       ; ← redundant
jz   .empty

; Good
sub  rdx, rcx
jz   .empty
```

For `jle` after `sub`: safe iff the operands are small non-negative
values (no signed-overflow risk). Audit each case; when in doubt,
keep the explicit `test`.

### 2. Prefer 32-bit registers for 32-bit data

Every `r64` instruction adds a REX.W prefix byte. x86-64 implicitly
zero-extends 32-bit register writes into the full 64-bit register,
so `mov eax, [field]` and `xor eax, eax` clear the upper 32 bits as
a side effect.

```asm
; Bad — wastes 1 byte each, BSS field is resd 1
mov rax, [client_count]
xor rax, rax

; Good
mov eax, [client_count]
xor eax, eax
```

Caveats:
- Memory writes: `mov [field], eax` writes 4 bytes. If the BSS field
  is `resq 1`, the upper 4 bytes are NOT zeroed. Either declare the
  field as `resd 1` (preferred — saves BSS too), or keep `rax`.
- Pointer values must stay 64-bit.
- Anything indexing into 64-bit address space must stay 64-bit.

### 3. Fixed-string compares: helper, not inline cmp chains

```asm
; Bad — opaque, repeated 41× across glass.asm at audit time
cmp dword [rax], 'XAUT'
jne .next
cmp dword [rax+4], 'HORI'
jne .next
cmp word  [rax+8], 'TY'
jne .next
cmp byte  [rax+10], '='
jne .next

; Good — single helper call
mov edi, eax
lea rsi, [str_xauthority_eq]   ; "XAUTHORITY="
mov ecx, 11
call streq_n                   ; ZF=1 iff equal (REPE CMPSB internally)
jne .next
```

`streq_n` is a 3-line helper. The cmp-chain is acceptable for a
single fixed compare; for 3+ chunks it's wasted bytes and the
helper wins.

### 4. State-machine dispatch: indirect jump, not chained `cmp`/`je`

```asm
; Bad — 7-link chain in glass.asm vt_process hot path (pre-fix)
mov rcx, [vt_state]
cmp rcx, VT_ESC
je  .vtp_esc
cmp rcx, VT_CSI
je  .vtp_csi
... (5 more)

; Good — table-driven, branch predictor handles it via BTB
mov ecx, [vt_state]
cmp ecx, MAX_STATE
ja  .vtp_default
lea rdx, [rel .vtp_jmp_tab]
jmp [rdx + rcx*8]
.vtp_jmp_tab:
    dq .vtp_normal
    dq .vtp_esc
    ...
```

Threshold: ≤3 cases → cmp/je is fine. ≥4 cases → use a jump table.

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
- There is no source code here, with the single exception of the
  experimental Darwin/arm64 port under `src/` (see `ARM.md`). New
  asm work for the Linux suite belongs in one of the project repos.
- When the suite grows (new asm project, new conf companion), update
  README's "tools" / "configurators" tables AND add/remove the
  pointer in this file.

## ARM port

An experimental AArch64 / Darwin arm64 port lives in `src/` with
its own `Makefile` and `scripts/test.sh`. It does not change the
Linux/x86_64 framing of the suite — it is an additive working
surface for Apple Silicon. Conventions and tool list are in
`ARM.md`. When the ARM port grows or changes, update `ARM.md`
(not the umbrella tool list).
