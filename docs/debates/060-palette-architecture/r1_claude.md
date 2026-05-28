# Claude (Opus) — Round 1 (independent)

## Recommendation: (A) Unify on the whole-palette routing (sprites→PAL1/2/3, BG→PAL0 via 4bpp pack). Delete the PAL0-tail CHR_EXPANSION scheme.

### The clean mapping — NES's 7 sub-pals fit Genesis's 4 PALs with NO per-scene hack

The key arithmetic everyone misses: **one Genesis PAL = 16 colors = exactly four NES 4-color sub-palettes.** Genesis 4bpp BG tiles can index all 16. So:

- **PAL0 (16 colors) = ALL FOUR NES BG sub-pals.** A BG cell selects its sub-pal via the tile's pixel values (4x pixel-bias: sub-pal n → pixel indices n*4..n*4+3). This is the "BG_4x" idea, and it's a genuine Genesis *strength* — NES needs 4 separate 2bpp sub-pals; Genesis packs them into one 4bpp palette.
- **PAL1 = NES SPR sub-pal 0, PAL2 = SPR sub-pal 1, PAL3 = SPR sub-pal 2.** Sprites select via the SAT palette field; sprite tile pixels are sub-pal-agnostic (values 1-3). This is exactly `subpal_routing.h`.

That covers 4 BG + 3 SPR = all 7, in 4 PALs, byte-exact, **with zero HBlank tricks for the common case.** NES SPR sub-pal 3 (the rare 4th) is the only overflow — handle it with an HBlank split ONLY in the few rooms that use it.

### Why the bonfire is blue

The `_oam_dma` CHR_EXPANSION path (scheme 1) routes sprite sub-pals into **PAL0** (BG's palette!) with 4x CHR bank copies, then `cave_palette` overwrites PAL0[8-15] with cave BG colors — so sprite and BG fight over PAL0. Scheme 1 is the bug. Scheme 2 (PAL1/2/3) has no contention: BG owns PAL0, sprites own PAL1/2/3.

### Migration
1. `nes_io.asm _oam_dma`: replace `.oam_pal_bits_tbl` (PAL0/0/0/1) with PAL1/2/3/2 (roomrom_spr_subpal_to_pal), and **drop the per-sub-pal tile-bias bank copies** — sprites use one tile set, pixels 1-3, colored by the SAT PAL.
2. Free the $4000/$8000 sprite CHR banks (VRAM win).
3. Keep `bg_palette` PAL1/2/3 = NES SPR sub-pals (already close).
4. Wall-white bug is separate: the BG 4x tile-copy *selection* for sub-pal-3 wall cells is wrong — fix the BG sub-pal→pixel-bias, not the palette.

### Biggest risk
The sprite CHR atlas is currently pre-biased into 4 bank copies. Removing them means the sprite tiles must be sub-pal-agnostic (pixels 1-3). That's a CHR-regen + re-verify-every-sprite (enemies/items/Link) effort — real blast radius, gated by the existing pixel_diff.

### Genesis strength leveraged
4bpp 16-color BG tiles pack all 4 NES BG sub-pals into ONE palette, freeing PAL1/2/3 entirely for the 3 NES SPR sub-pals — a 1:1 of NES's 7 onto Genesis's 4 with no per-scene hack.
