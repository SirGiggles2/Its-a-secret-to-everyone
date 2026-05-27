# Debate 057 Final Synthesis: Every cave sprite + animation byte-perfect

## Verdict

Genesis cave-scene visual sweep PASSES at 56/56. To achieve **byte-exact OAM/CHR/PAL parity vs NES** + opportunistic Genesis improvements:

### Real bugs (verified via code investigation)
- **BUG 1 — SPR subpal not uploaded for cave**: `cave_palette.c:19` uploads only BG subpals 2+3 to CRAM 8-15. SPR subpal 2 (CRAM 24-27) inherits OW state. NES bonfire ($40) uses attr=2 → SPR subpal 2 with bytes likely `$0F,$16,$27,$30` per Codex R3. May render correctly visually (orange flames visible in cave_77 PNG) but byte-diff against canonical NES PALRAM will FAIL.
- **BUG 2 — Frame cadence**: NOT A BUG. Sonnet R2 verified `sprite_runtime.c:107` matches NES Z_07.asm:5056 exactly.
- **BUG 3 — Ware visibility on purchase**: NOT A BUG. Sonnet R2 verified `cave_dispatch.c:397` sets CaveItemId=$FF → `cave_draw_items:306` masks $FF&$3F=$3F sentinel → skip draw. NES-correct.

### Design choices confirmed
- NES bonfire palette flicker = MYTH. Z_04.asm:259 sets fixed attr 2. Don't implement flicker.
- NES cave items STATIC. No bob. Don't add.
- Bonfire 2-tile cycle byte-exact $5C ↔ $9E confirmed via k_obj_anim_frame_heap[8/9].
- Cave palette: ONE BG palette for all caves (k_cave_subpal_2_3_nes correct).

### Genesis improvements (OPT-IN OVERLAYS, default off)
- **Anti-flicker**: FREE — Genesis SAT has 80 slots, no scanline limit. Already better than NES.
- **16-color sprite sub-pal for fire**: 4h — extra orange-to-white gradient. Requires new VRAM tiles.
- **60fps anim interpolation**: 3h — 3rd intermediate fire frame.

## Concrete plan (10h)

### Phase I0 (1h) — Probe NES SPR PALRAM
Write `tools/parity/probe_nes_cave_palette.lua`. Boot NES, navigate to cave $6A, dump PALRAM $3F00-$3F1F at frame +60. Save to `tools/parity/cave_golden/palette_nes.bin`. Cross-ref Codex R3 prediction $0F,$16,$27,$30.

### Phase I1 (30min) — Fix cave_palette.c
Extend `cave_palette_apply()` in `src/game/world/render/cave_palette.c`:
```c
static const unsigned char k_cave_spr_subpal_2_nes[4] = {
    0x0F, 0x16, 0x27, 0x30   /* per NES PALRAM $3F18-$3F1B */
};
// after BG upload:
unsigned short spr_cram[4];
for (i = 0; i < 4; i++) spr_cram[i] = roomrom_bg_palette_nes_to_cram(k_cave_spr_subpal_2_nes[i]);
render_cram_subrange_upload(24u, spr_cram, 4u);  // SPR subpal 2 = PAL1 slots 8-11
```

Verify CRAM target slot — PAL1 starts at CRAM 16 + sub_pal*4. Sub-pal 2 = CRAM 24.

### Phase I2 (1h) — Rebuild + re-sweep
Debug.bat. Re-run `python tools/parity/dungeon_visual_sweep/run_sweep.py`. Verify caves still 56/56 (or 20/20 caves). Diff palette PNGs vs baseline — fire color shift acceptable, NPC/etc unchanged.

### Phase I3 (3h) — Per-cave golden bundle
Per Codex R3: BOTH raw OAM + CHR hashes.
- `tools/parity/cave_golden/<cave_id>/oam_f{0,6,12,30}.json` — slot/x/y/tile_normalized/attr/flip/prio
- `tools/parity/cave_golden/<cave_id>/palram.bin` — 32 bytes NES PALRAM
- `tools/parity/cave_golden/chr_hashes.json` — fnv32 per referenced tile

Generate via `tools/parity/probe_nes_cave_golden.lua`: 20 caves × 4 frame phases.

### Phase I4 (3h) — Byte-diff comparator
`tools/parity/cave_golden_diff.py`: per cave_id, fetch Gen SAT+CRAM+ChR hash, normalize, byte-diff. Exit 1 on any mismatch.

### Phase I5 (1.5h) — CI hook + docs
- Debug.bat post-build: optional `--verify-cave-golden`
- `docs/parity/cave_strict.md` — contract.

### Deterministic seed
Savestate at `cave_init()` return. Frame offsets +0/+6/+12/+30 cover bonfire 2-tile cycle (at 6Hz = ~10 frame period) + steady state. FrameCounter $0015 captured from savestate; Gen forces same value before first capture.

## Risks
- ~~Codex R3's predicted SPR PALRAM bytes $0F,$16,$27,$30 — needs probe verification before patching.~~ **CONFIRMED** by Sonnet R3 — `LevelInfoOW.dat` bytes 19-22 = `0F 16 27 30`. Uniform across all cave_ids.
- CHR atlas: `sprites` block covers tiles $00-$E7 (232 tiles). **Gap**: $F2 (Fairy) + $F3 (Ladder) outside bounds. Unreachable per Sonnet R3 — no cave stocks these as wares.
- NPC sprite groups: **FIVE groups** (not 4) per Sonnet R3:
  - $6A → tile $C0 (heap[0xCC])
  - $6B-$73 → tile $98
  - $74-$77 → tile $9A
  - $78-$7B → tile $9C
  - $7C-$7D → tile $F8
  Genesis k_obj_animations matches NES exactly.

## R3 confirmation
Sonnet R3 verified all 5 R3 questions via code investigation:
- Q1: SPR palette source = `LevelInfoOW.dat` (loaded via `LevelInfo_PalettesTransferBuf` $6B7E). Fix at cave_palette.c:20.
- Q2: Golden = raw OAM only (CHR drift = separate build-time manifest).
- Q3: 5-group NPC structure matches NES.
- Q4: Atlas covers all reachable cave wares.
- Q5: ~9h total (30m fix + 10m build + 1h probe + 3h NES golden + 2h Gen probe + 2h differ).

## Total effort: 10 hours

Caves remain 56/56 PASS today. Byte-exact verification = 10h additional work for long-term regression infra.
