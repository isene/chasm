# Handover: glass leaves the bottom pixels of a block behind

For the CHasm session. Written from the Fe₂O₃ side, where the symptom
showed up in `isotopes`. The app has a workaround now; the terminal bug
is still there and will bite anything else that paints solid cells.

## The symptom

An app fills cells with `█` (U+2588) in a truecolour foreground. When
those cells are later blanked — either overwritten with a space or
erased with `CSI K` — a **thin horizontal dash survives at the bottom of
each cell, in the colour the block had**.

The dashes accumulate as a chart scrolls, so the empty part of the
screen fills with a dotted lattice tracing where blocks used to be.

- **Reproduces**: geir's own glass session, DejaVu Sans Mono via
  `font_path`, `font_size = 18`, `font_weight = bold`, 1920×1200,
  24-pixel cells.
- **Does not reproduce**: wezterm, same app, same escape sequences.
- **Did not reproduce** in glass under Xvfb from this session, at both
  21-pixel and 24-pixel cells. Which is the interesting part: it is
  probably the TTF path through **glyph** rather than the XLFD path,
  since Xvfb here likely fell back to a core font.

Screenshots of the symptom are in geir's `~/2026-07-29-23*.png`.

## What the app was emitting

Nothing exotic, and nothing wrong. Verified byte-for-byte with a pty
harness plus pyte: zero stray cells in the model, every row ending in
`\x1b[0m\x1b[K`.

```
\x1b[<row>;1H            move
\x1b[38;2;R;G;Bm█…       a run of blocks, colour set once per run
\x1b[0m                  reset
\x1b[K                   erase to end of line
```

So the terminal is being told to clear those cells, and clears all of
them except their bottom pixel row.

## Prime suspect

**The clear rectangle is a pixel shorter than the glyph.** Either

1. the fill used when a cell is blanked (space, `CSI K`, `CSI 2J`) is
   `cell_h - 1` tall, or is positioned one pixel high, while a glyph
   blit covers the full `cell_h`; or
2. glyph hands back a bitmap for U+2588 that is one pixel taller than
   the `ascent + descent` glass computes as `char_height`
   (`glass.asm`, around the `font_ascent` / `font_descent` reads at
   ~line 2895 and `char_height = ascent + descent` at ~2901), so the
   block overhangs into a region the clear never owns.

Bold is worth a look on the way past: if bold is synthesised by
double-striking with a one-pixel offset, a glyph that already fills its
box spills by construction, and U+2588 is the one glyph where that is
guaranteed to show.

The fact that it is always the **bottom** row, always in the **old
foreground colour**, and that it **survives `CSI K`**, all point at a
clear that does not cover the same rectangle the blit does.

## Repro script

Run in glass, then screenshot and measure:

```sh
#!/bin/sh
printf '\033[2J\033[H'
# five rows of blue blocks
i=1; while [ $i -le 5 ]; do
  printf '\033[38;2;90;150;255m'
  j=1; while [ $j -le 60 ]; do printf '█'; j=$((j+1)); done
  printf '\033[0m\n'; i=$((i+1))
done
# a row of blocks left alone, one overwritten with spaces, one erased
printf '\033[10;1H\033[38;2;90;150;255m'; j=1
while [ $j -le 60 ]; do printf '█'; j=$((j+1)); done; printf '\033[0m'
printf '\033[12;1H\033[38;2;90;150;255m'; j=1
while [ $j -le 60 ]; do printf '█'; j=$((j+1)); done; printf '\033[0m'
sleep 2
printf '\033[12;1H'; j=1
while [ $j -le 60 ]; do printf ' '; j=$((j+1)); done      # spaces
printf '\033[14;1H\033[38;2;90;150;255m'; j=1
while [ $j -le 60 ]; do printf '█'; j=$((j+1)); done; printf '\033[0m'
sleep 1
printf '\033[14;1H\033[K'                                  # CSI K
# for comparison: a row painted as background, no glyph involved
printf '\033[18;1H\033[48;2;90;150;255m'; j=1
while [ $j -le 60 ]; do printf ' '; j=$((j+1)); done; printf '\033[0m'
sleep 60
```

Rows 12 and 14 must come out completely black. If either keeps a dash,
that is the bug in front of you.

Measuring it exactly, from a screenshot:

```python
import subprocess, re
out = subprocess.run(["convert", "shot.png", "-crop", "200x600+0+0", "+repage", "txt:-"],
                     capture_output=True, text=True).stdout
rows = {}
for line in out.splitlines()[1:]:
    m = re.match(r"(\d+),(\d+): \((\d+),(\d+),(\d+)", line)
    if not m: continue
    x, y, r, g, b = map(int, m.groups())
    if abs(r-90) < 30 and abs(g-150) < 30 and abs(b-255) < 30:
        rows[y] = rows.get(y, 0) + 1
runs, cur = [], None
for y in sorted(rows):
    if cur and y == cur[1] + 1: cur[1] = y
    else: cur = [y, y]; runs.append(cur)
print([(a, b, b - a + 1) for a, b in runs])
```

On a healthy render you get one run per drawn row, each exactly
`cell_h` pixels tall, and nothing at all for the cleared rows. That is
what glass under Xvfb produced here: `0..104 (105 = 5 × 21)`,
`189..209 (21)`, `357..377 (21)`, and silence where the clears were.

## Why it matters beyond one app

Any Fe₂O₃ app that paints solid cells hits this: `isotopes` (the chart
of the nuclides), and anything else that ends up drawing heat maps or
filled bars. Braille-drawing apps (`astro`, `starmap`, `particles`) are
less exposed because their glyphs do not fill the cell, but the same
short clear would clip the bottom dot row of `⣿`.

## What the app did instead, for now

`isotopes` v0.1.4 paints its cells as **background colour on a space**
rather than a foreground `█`. No glyph, no overhang, and it looks
better: the cells are flush with no seam between rows. That is a fine
end state for the app regardless, so there is no rush on the terminal
fix, but the bug is real and the next app to draw a block will find it.
