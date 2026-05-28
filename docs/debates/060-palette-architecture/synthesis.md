# Debate Synthesis — Genesis sprite+BG palette architecture (NES byte-exact)

## Participants
🔴 Codex · 🟡 Gemini · 🟠 Sonnet (code-grounded) · 🐙 Claude/Opus

## 4-WAY CONSENSUS — Long-term architecture (the answer to "what's best long term")

**Unify on WHOLE-PALETTE ROUTING. Delete the CHR_EXPANSION PAL0-tail sprite scheme.**

Mapping (NES's 7 logical sub-pals onto Genesis's 4 PALs, no per-scene hack for the common case):
- **PAL0 (16 colors) = all 4 NES BG sub-pals** at indices 0-3 / 4-7 / 8-11 / 12-15. BG tile pixel-bias (4bpp) selects the sub-pal. (Genesis 4bpp packs 4 NES 2bpp sub-pals into ONE palette — the key Genesis strength NES lacks.)
- **PAL1 / PAL2 / PAL3 = NES SPR sub-pals 0 / 1 / 2.** Sprite SAT pal-field selects; sprite tile pixels are sub-pal-AGNOSTIC (values 1-3).
- **NES SPR sub-pal 3 (rare)**: per-scene exception only — alias to an unused sprite pal, or an HBlank split in the few rooms that truly show 4 SPR pals at once. Optimize for the real game (4 BG + 3 SPR), not theoretical NES PPU symmetry.

Supporting pillars (all agreed):
- **One atomic per-scene palette load**: `scene_palette_apply(scene)` writes ALL 64 CRAM bytes from a full 32-byte NES-PALRAM manifest. NO partial CRAM uploads, ever (kills the cave_palette partial-patch + OW-residue clobber class of bugs).
- **Sprite CHR must be sub-pal-agnostic** (pixels 1-3); drop the 4× sprite bank copies → frees VRAM.
- **Verification**: per-scene CRAM-vs-manifest byte diff + rendered pixel diff (the existing cave_byte_diff.py / pixel_diff.py).

Dissent (Gemini's 4×-quadrant pack of both BG+SPR): REJECTED by all incl. Gemini in R2 — wastes 4× VRAM, renders the SAT palette field useless, hides routing in tile indices. Its one keeper: dual-playfield Plane A is free → optional later atmospheric/shadow-highlight overlay.

## CRUX RESOLVED (Sonnet R2, definitive, file:line) — why the bonfire is blue
- Bonfire SAT written ONLY by `_oam_dma` (nes_io.asm:2046); `CHR_EXPANSION_ENABLED=1` LIVE (nes_io.asm:37).
- attr $02 → sub-pal 2 → `.oam_tile_bias_tbl[2]=1024` (copy C, pixel bias +8) + `.oam_pal_bits_tbl[2]=$0000` → PAL0.
- Copy-C pixels 1/2/3 land in PAL0 slots **9/10/11** = NES SPR sub-pal 1's CRAM region = stale OW blue.
- `cave_palette.c:43` uploads fire to PAL3 (slot 48) — never read by the bonfire. (Explains why every PAL1/2/3 guess failed.)

## TWO-LEVEL PLAN

### IMMEDIATE (unblock the bonfire now, works with current scheme, verifiable)
`src/game/world/render/cave_palette.c:43` — change
`render_cram_subrange_upload(48u, spr_cram, 4u)` (PAL3)
→ upload the 3 fire colors to **PAL0 slots 9-11** (`render_cram_subrange_upload(9u, spr_cram+? , 3u)`) where copy-C sub-pal-2 pixels actually land. Rebuild → pixel_diff cave_6A bonfire cells → expect orange.
(Caveat: confirm the exact slot live — the architecture is byte-verifiable, so build+diff is the proof, not the trace.)

### LONG-TERM (the real fix, per consensus)
1. Make `subpal_routing.h` the ONLY palette contract; sprites → PAL1/2/3.
2. Rewrite `_oam_dma` (nes_io.asm) sprite path: pal-bits → PAL1/2/3 (roomrom_spr_subpal_to_pal); drop PAL0-tail bias + the 4× sprite bank copies (sprite tiles become sub-pal-agnostic 1-3). Audit title/story callers before deleting CHR_EXPANSION.
3. Add `scene_palette_apply()` + per-scene CRAM manifest; remove all partial-CRAM uploads (cave_palette, ow, uw).
4. Gate every scene on CRAM-manifest diff + pixel diff.
Biggest risk: regenerating the sprite CHR atlas sub-pal-agnostic (re-verify every sprite). Blast radius across all sprites — gated by the byte/pixel differ.
