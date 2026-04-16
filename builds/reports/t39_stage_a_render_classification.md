# T39 Stage A — Render Classification

**Status**: Evidence gathered, mechanism classified. Ready for Build.

## Method

Instrumented `tools/bizhawk_t36_cave_gen_capture.lua` and
`tools/bizhawk_t36_cave_nes_capture.lua` to dump:
- Screenshots at scenario `t=40` (overworld pre-cave), `t=500` (in cave),
  `t=820` (overworld post-exit).
- NT_CACHE (960 bytes at `$FF0840`, Plane A nametable cache) at the same
  three waypoints on Genesis.
- VDP VRAM (pattern table) hex dump at same waypoints on Genesis.

Raw artifacts in `builds/reports/t39_gen_*.png`, `t39_nes_*.png`,
`t39_nt_gen_*.hex`, `t39_vdp_gen_*.hex`.

## Screenshot comparison

| t    | NES (reference)            | Gen (broken)                                     |
|------|----------------------------|--------------------------------------------------|
| 40   | HUD + forest + Link — OK   | HUD + forest + Link — **MATCHES**                |
| 500  | Black HUD; cave interior   | **HUD replaced by white/red cave stalagmite tiles**; textbox fragmented |
| 820  | HUD + overworld + Link     | **Top ~half cave tiles + corrupted HUD text; bottom half overworld** |

## NT_CACHE diff — HUD rows (0-3)

```
          col: 0  1  2  3  ... 28 29 30 31
t=40  row 00: 24 24 24 24 ... 24 24 24 24   (all HUD black $24 — correct)
t=40  row 01: 24 24 24 24 ... 24 24 24 24
t=40  row 02: 24 24 24 24 ... 24 24 24 24
t=40  row 03: 24 24 F5 F5 ... 62 24 24 24   (HUD icons)

t=500 row 00: D8 DA D8 DA ... D8 DA D8 DA   (cave ceiling stomps HUD)
t=500 row 01: D9 DB D9 DB ... D9 DB D9 DB
t=500 row 02: D8 DA D8 DA CE D0 CE D0 ...   (cave interior tiles)
t=500 row 03: D9 DB D9 DB CF D1 CF D1 ...

t=820 row 00: D8 DA D8 DA 26 26 26 26 ... D8 DA D8 DA   (partial overwrite:
t=820 row 01: D9 DB D9 DB 26 26 26 26 ... D9 DB D9 DB    cols 4-27 overworld
t=820 row 02: D8 DA D8 DA CE D0 CE D0 ... D8 DA D8 DA    grass $26, cols 0-3/
t=820 row 03: D9 DB D9 DB CF D1 CF D1 ... D9 DB D9 DB    28-31 + some middle
                                                         rows 2-3 untouched
                                                         cave residue)
```

## Root cause

**Mechanism #2 (refined): NES nametable `$2400` writes stomp NT_CACHE
rows 0-3 (HUD region).**

On NES, Zelda uses 4-screen mirroring (cart has extra VRAM):
- `$2000` — HUD nametable, rows 0-3 displayed at scanlines 0-31.
- `$2400` — playfield nametable, its rows 0-25 displayed at scanlines
  32-239 via a mid-frame scroll split.

The NES PPU renders HUD and playfield from **separate** nametables,
switched at scanline 32 by rewriting `PPUSCROLL`.

Our Genesis transpile collapses this:
- `src/nes_io.asm:770` — "Fold `$2400` mirror → `$2000` (vertical
  mirroring alias for NT_A)." — treats `$2400` as aliased to `$2000`.
- `_ppu_write_0` maps both `$2000` and `$2400` PPU_VADDR writes to
  `NT_CACHE[(v - $2000)]`, i.e. playfield row 0 → Plane A row 0.

**Consequence**: Any write to `$2400 + 0..$7F` (playfield rows 0-3)
overwrites Plane A rows 0-3 (the HUD region). Overworld rooms happen
to write `$24` (blank) to those rows, which masks the bug. Cave rooms
write stalagmite tiles (`D8`/`DA`/`D9`/`DB` + `CE`/`D0`/`CF`/`D1`) to
those rows, producing the visible HUD corruption.

**Post-exit residue** (rows 0-3 cols 0-3 + 28-31 still cave tiles)
happens because overworld room-reload writes cover only cols 4-27 (the
16-metatile-wide room extent), leaving cave residue at the 4-column
borders.

## Hypotheses disproven by evidence

1. ~~Plane A not repainted on cave->overworld transition~~ — Partial:
   plane *is* repainted, but not fully; the HUD region of Plane A is
   not restored because the NES code never writes HUD back (it assumes
   `$2000` is intact).
2. ~~`_ppu_write_0` rebuild using stale NT_CACHE~~ — No: NT_CACHE is
   being *overwritten* correctly per-call, the problem is that the
   writes *should never have reached* the HUD rows in the first place.
3. ~~HUD DMA slot (DynTileBuf) asymmetric flush~~ — Not the root. HUD
   tile DMA is fine; tile indices in NT_CACHE are the culprit.
4. ~~CHR bank still holds cave pattern tiles~~ — Unrelated: VRAM CHR
   may or may not be dirty, but the immediate visible bug is the wrong
   tile indices in NT_CACHE rows 0-3. Fixing NT mapping fixes both
   symptoms (in-cave HUD corruption AND post-exit HUD residue).

## Fix strategy

**Option A (minimal)**: In `_ppu_write_0`, when PPU_VADDR is in
`$2400..$27FF`, offset the NT_CACHE index by +4 rows (i.e.,
`$2400` → NT_CACHE row 4, `$2420` → row 5, ...). Symmetrically for
`$2C00` → NT_B offset. This preserves HUD rows 0-3 as the exclusive
domain of `$2000`-range writes.

**Option B (structural)**: Keep `$2000` and `$2400` in separate cache
regions. Requires doubling NT_CACHE size.

**Chosen: Option A** — preserves existing NT_CACHE layout, narrow
patch, matches NES semantics (scroll-split moves `$2400` row 0 to
display row 4).

## Next step

Build Stage A fix: row-offset `$2400`/`$2C00` writes in `_ppu_write_0`
and the NT_CACHE write path. Re-run cave capture. Verify:
- t=40 PNG unchanged (overworld HUD still correct).
- t=500 PNG HUD row is black, cave interior intact.
- t=820 PNG HUD row is clean HUD, overworld intact.
- T36 cave parity stays 8/9 (no regression in game logic).
