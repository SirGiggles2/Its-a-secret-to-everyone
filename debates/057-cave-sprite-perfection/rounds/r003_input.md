# Round 3 — converge on Bug 1 fix + verification architecture

R2 converged via Sonnet code investigation:
- Bug 1 (SPR subpal not uploaded for cave) = REAL. Fix: add render_cram_subrange_upload(24u, spr_cram, 4u).
- Bug 2 (cadence) = NOT A BUG (matches NES exactly).
- Bug 3 (ware visibility) = NOT A BUG ($FF sentinel skips draw correctly).

Sonnet: golden = raw OAM bytes only.
Codex: golden = both CHR hashes + raw OAM.
Both: deterministic seed via savestate at cave_init return + relative frame offsets.

## R3 question

Final convergence on:

### Q1: cave_palette_apply SPR subpal extension
- What NES PALRAM bytes for cave SPR subpal 2? Need verification — NES Z_06.asm:714 cited for BG only. SPR subpal source is...where? Maybe inferred from CHR atlas extraction or hardcoded.
- Concrete patch to cave_palette.c — show the byte values + CRAM target slot.
- Should this be one global SPR subpal (all caves same orange flame) or per-cave_id?

### Q2: Golden bundle architecture
- Path: tools/parity/cave_golden/<cave_id>/...
- Files per cave: oam.json (slot/x/y/tile/attr per frame) + palram.bin (32 bytes) + chr_hashes.txt OR not?
- Sonnet says CHR hashes redundant. Codex says use both. Resolve.
- Frame offsets: +0/+6/+12/+30 covers what bonfire/cadence phases?
- Sentinel addresses for deterministic seed (savestate snapshot of FrameCounter $0015 + force Gen)?

### Q3: NPC sprite parity per cave_id $6A..$7D
- ObjAnimations[$6B..$7E] → 20 entries. Sonnet R1 showed:
  - $6A..$6E → $C6 (5 caves same NPC sprite)
  - $6F..$70 → $C8
  - etc.
- Question: Do these correctly group on Genesis like NES, OR did the C ports break the grouping?
- How to verify per cave_id: probe NES OAM tile_id when entering cave $6A; same for Genesis; byte-diff.

### Q4: Item sprites per cave
- Cave $6B = money game (rupees), $6A = sword cave (sword item), $6C/$6D = white sword/etc.
- CaveItemIds drive item sprites at ware slots 0/1/2. Each item_id $00..$3F has its own tile.
- Are ALL 63 item tiles in Gen sprite atlas? Or only the cave-active subset?

### Q5: Execution sequence (concrete steps)
1. Write NES PALRAM probe (1h)
2. Fix cave_palette.c SPR upload (30min)
3. Rebuild Debug.md
4. Re-sweep + compare PNGs vs sweep v8 to confirm no regression
5. Build per-cave OAM golden bundle (4h)
6. Build differ + CI hook (3h)
Total: ~10h.

Each advisor: address all 5. 400 words max.
