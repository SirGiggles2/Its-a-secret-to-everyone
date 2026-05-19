# Session Intent Contract — Octorok NES Parity (2026-05-17)

**Created:** 2026-05-17 (supersedes 2026-05-10 Task 7.7 contract above)
**Source:** /octo:plan "both steps"

## Job Statement

Make Genesis port octorok rendering + spawn placement byte-for-byte
match NES Z1 at OW room $67. Two sub-tasks (user said "both"):

1. **OWSP atlas regen** from `reference/aldonunez/dat/PatternBlockOWSP.dat`
2. **Spawn algorithm diff** vs NES Z_05.asm:1885 AssignObjSpawnPositions

## Auto-filled answers (CLAUDE.md autonomy override)

- Goal: **Build something** (fix octorok visual + position)
- Knowledge: **Expert** (deep codebase + NES asm familiarity)
- Clarity: **Fully specified** (live NES OAM dump captured ground truth)
- Success: **Working solution** (probe-level diff = zero)
- Constraints: **NES accuracy + High stakes + Time pressure**

## NES Ground Truth Captured (build/probes/nes_z1_compare.lua)

NES Z1 live OW room $67:
- 4 RedSlowOctoroks (type $07)
- Positions: ($60,$5D), ($10,$95), ($60,$5D), ($80,$7D)
- Active OAM tiles: $B0/$B6/$BA family with vflip/hflip variants
- Sub-pal 2 for all (red enemies)
- qspd $20 ✓ matches ours

## Genesis Port Current State (probe earlier)

- Same 4 octoroks (type $07) ✓
- Positions: ($20,$5F), ($40,$7B), ($5E,$7D), ($80,$5D) ✗ differ
- Tiles match heap family but rendered shape wrong ✗ (atlas data)
- Sub-pal routing FIXED 2026-05-17 (octorok red+white, rocks brown) ✓
- Shot motion FIXED (qspeed init wired) ✓
- Shot despawn FIXED (boundary fall-through) ✓

## Success Criteria

- Octorok body PIXEL-IDENTICAL to NES Z1 OWSP $B0/$B6/$BA tiles
- Spawn positions BYTE-IDENTICAL to NES at room $67
- nes_z1_compare.lua vs octorok_visual.lua diff = 0 on (X, Y, dir, type)
- Visual screenshot side-by-side: octorok bodies look the same shape

## Boundaries

- NES accuracy priority 1 (per CLAUDE.md)
- WT-5: no new RoomRom files; edit existing atlas/enemy_chr.c only
- WT-1: substrate writers from main worktree (currently in main ✓)
- Drain Rule D1: NES asm wins ties on spawn algo
- Sole target Debug.md via Debug.bat
