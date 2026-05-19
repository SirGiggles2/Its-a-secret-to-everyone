# Session Plan — Octorok NES Parity (2026-05-17)

**Created:** 2026-05-17 (supersedes 2026-05-10 plan above)
**Intent contract:** [.claude/session-intent.md](session-intent.md)

## What You'll End Up With

Octoroks in OW room $67 render byte-identical pixel shape AND spawn at
byte-identical (X,Y) coordinates vs real NES Z1. Probe re-run shows
diff=0 on (type, X, Y, dir) and screenshot looks same as `nes_z1_octorok_room.png`.

## Phase Weights

```
DISCOVER  ██ 5%    — done (NES OAM + atlas paths already located)
DEFINE    ██ 10%   — locked: 2 sub-tasks, clear evidence
DEVELOP   ██████████████████████ 60% — atlas regen + spawn algo diff
DELIVER   ██████████ 25% — probe re-run, screenshot compare, commit
```

## Provider Availability

🔴 Codex CLI: available
🟡 Gemini CLI: available
🟣 Perplexity: available (API key set)
🟤 OpenCode: available
🟢 Copilot CLI: available
🟢 Qwen CLI: available
🔴 Ollama: not running
🟣 OpenRouter: available (API key set)
🔵 Claude: available

Mode: Claude-only. Task is byte-byte implementation, not research.
Multi-AI not needed.

## Step Ordering

### Sub-task A: OWSP Atlas Regen (~3/4 of dev budget)

A1. Read `RoomRom/tools/gen_atlas.py` to find current OWSP extraction
    path. Identify input source for `roomrom_atlas_enemy_owsp[]`.

A2. Compare current source vs `reference/aldonunez/dat/PatternBlockOWSP.dat`.
    PatternBlockOWSP.dat is 1824 bytes = 114 NES tiles × 16 bytes each
    (NES CHR tile format = 8 bytes plane 0 + 8 bytes plane 1).

A3. If source differs: re-extract NES OWSP via gen_atlas.py from
    PatternBlockOWSP.dat. Convert NES 16-byte CHR → Genesis 32-byte
    tile format (Genesis tiles use 4bpp = 4 bytes per row × 8 rows).

A4. Rebuild `RoomRom/src/atlas/enemy_chr.c` `roomrom_atlas_enemy_owsp[]`.
    Verify byte count = 114 × 32 = 3648 (matches existing).

A5. Build Debug.bat. Run `build/probes/vram_tile_v2.lua` to dump
    Genesis VRAM tile 1103 (NES $B0) + 1109 (NES $B6) + 1113 (NES $BA).

A6. Compare pixel-by-pixel with NES expected ground truth from
    PatternBlockOWSP.dat at offsets $220, $280, $2C0.

### Sub-task B: Spawn Algorithm Diff (~1/4 of dev budget)

B1. Read NES `Z_05.asm:1885-2010 AssignObjSpawnPositions` fully.

B2. Read `src/game/enemies/obj_lists.c:358 enemy_assign_spawn_positions`
    fully.

B3. Diff line-by-line: spawn list selection, dir-to-index mapping,
    IsSafeToSpawn advance, cellar/cave overrides, Y_cycle stepping.

B4. Hypothesis: either `spawn_pos_list_0..3` byte values mis-transcribed
    OR `dir_to_spawn_list_index` mis-maps dirs OR is_safe_to_spawn fails
    differently due to floor-tile differences.

B5. Compare NES `SpawnPosListAddrs` bytes (in Z_05.asm:1431-1445) against
    our `spawn_pos_list_0..3` constants in obj_lists.c:306-317.

B6. Verify NES Z_05.asm:1431-1445 byte values vs our table:
    - spawn_pos_list_0: $55 $B5 $78 $98 $7A $9A $6C $AC $8D
    - spawn_pos_list_1: $82 $63 $A3 $75 $95 $77 $97 $5A $BA
    - spawn_pos_list_2: $A3 $75 $B5 $96 $87 $99 $7A $BA $AC
    - spawn_pos_list_3: $63 $55 $95 $76 $88 $79 $5A $9A $6C

B7. Live NES expects (X=$60,$10,$60,$80, Y=$5D,$95,$5D,$7D). Decode
    these to spawn-list byte format: ($60,$5D) → col=6, row=(5D-0D)/16=5
    → byte = ($60>>4)<<4|5 = $65. Look for $65 in spawn lists.

B8. Fix table OR algorithm based on diff. Probe re-run.

### Sub-task C: Verify (Deliver phase)

C1. `python tools/debug/build_debug.py` clean.

C2. Run `build/probes/nes_z1_compare.lua` (NES) + `build/probes/octorok_visual.lua`
    (Genesis). Compare slot-by-slot for room $67.

C3. Side-by-side screenshot compare: NES vs Genesis. Octorok bodies
    should look pixel-identical.

C4. Probe diff = 0 → commit. Diff > 0 → return to Phase 1 of /chuckle.

## Success Criteria

- Debug.bat green.
- Genesis tile 1103/1109/1113 VRAM byte-identical to NES OWSP $B0/$B6/$BA
  PatternBlockOWSP.dat data.
- Octorok positions match NES live OAM: $60/$5D, $10/$95, $60/$5D, $80/$7D.
- Visual screenshot side-by-side: octorok shape identical.

## Risk

- Atlas regen may break OTHER OW enemies if extraction was right for
  some + wrong for some. Mitigation: probe screenshots before/after for
  multiple enemy types (Tektite room, Leever room).
- Spawn algo fix may shift ENEMY positions in dungeons too (UW uses
  same algorithm). Mitigation: probe UW L1 entry post-fix.

## Next Action

Sub-task A1 — read `RoomRom/tools/gen_atlas.py` extraction path now.
