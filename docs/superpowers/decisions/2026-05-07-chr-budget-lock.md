# CHR Budget Lock — Decision

**Date:** 2026-05-07
**Decided in:** PR-1 CHR-FOUNDATION
**Spec:** docs/superpowers/specs/2026-05-07-whole-chr-rollout-design.md

## Preflight artifacts

- [build/probes/ph5/task_chr/audit_bg_subpal_refs.json](../../../build/probes/ph5/task_chr/audit_bg_subpal_refs.json)
- [build/probes/ph5/task_chr/sprite_subpal_census.json](../../../build/probes/ph5/task_chr/sprite_subpal_census.json)
- DMA timing analysis (static, NTSC: 7790 bytes/VBlank window)

## Findings

### BG_2x — REJECTED

`audit_bg_subpal_refs.py` scanned all 636 captured UW rooms.
**Every room uses all 4 distinct BG sub-palettes.** Max distinct
sub-pals per room = 4. BG halving from 4× to 2× would corrupt
BG rendering across the entire UW.

Verdict: BG_4x stays. 512 tiles NOT recoverable.

### Sprite sub-pal census

`sprite_subpal_census.py` (static) confirms:
- ITEM bank already 4×.
- Transient enemy banks need ≥ 2× prebias (Codex P0-2:
  ObjAnimAttrHeap uses sub-pal 0..3). Recommend 4×.
- Boss banks 2× sufficient (sub-pal 0 + 2).
- NPC banks 2× sufficient.

### DMA timing

NTSC VBlank window ≈ 7790 bytes. ENEMY bank (8192 bytes) overflows
single VBlank by ~400 bytes. 2-VBlank split mandatory for ENEMY +
BOSS combined (14336 bytes vs 15580 budget).

## Decision

**LOCKED: SPR-split + shared SCENE_OBJ transient (Codex P1
alternative).**

Rationale:
- BG_2x off the table per audit.
- Current SPR_1x bank (312 tiles) is the only structurally
  reorganizable region without per-room BG remap.
- Codex's P1 alternative — split SPR_1x into LINK_STATIC
  (~64 tiles for Link + sword body) + shared SCENE_OBJ transient
  (~256 tiles, one context active at a time) — preserves BG_4x,
  avoids renderer rewrite, gates merge on smaller blast radius.

### VRAM rebudget (locked)

| Region                   | Tiles | Range      | Notes |
|--------------------------|-------|------------|-------|
| blank                    | 1     | 0          | unchanged |
| BG_4x                    | 1024  | 1..1024    | unchanged (BG_2x rejected) |
| LINK_STATIC (1×)         | 64    | 1025..1088 | Link + sword body — was SPR_1x first 64 |
| COMMON_SPR_1x            | 248   | 1089..1336 | remaining common sprite tiles, unchanged content |
| ITEM_4x (extended)       | 160   | 1337..1496 | 31→40 NES tiles (existing 31 + triforce + 9 FX) × 4 sub-pal |
| SCENE_OBJ (transient)    | 192   | 1497..1688 | 1× active context; prebias factor per context (4× enemy, 2× boss/NPC) — see below |
| reserved                 | 0     | 1689..1535 | OVERFLOW — 1689 > 1535 |

**Re-examine: 1496 + 192 = 1688 > 1535.** The shared SCENE_OBJ
transient bank doesn't fit alongside the ITEM extension if both
are pre-allocated. Resolution:

- Cut ITEM_4x extension scope: candle fire (4 frames) goes to
  SCENE_OBJ-as-FX-context (transient) instead of ITEM permanent.
  ITEM extension limited to triforce + sword shot + magic shot
  (3 NES tiles → 31+3=34 × 4 = 136 tiles).
- ITEM bank: 1337..1472. SCENE_OBJ: 1473..1535 (63 tiles).

Recompute SCENE_OBJ slot size:
- 63 tiles × 1× = 63 NES tiles (raw 1×).
- 63 / 4 = 15 NES tiles if 4× prebias.

15 tiles is too small for full enemy bank (PatternBlockUWSP127 =
34 tiles). **SCENE_OBJ at 63 tiles 1× is too small.**

### Decision pivot: defer SCENE_OBJ to PR-2 / PR-4

Foundation locked **scope**:
- BG_4x stays.
- SPR_1x stays (no LINK_STATIC split this PR — defer to PR-2 if
  needed).
- ITEM_4x extends: triforce + 3 FX tiles (sword shot, magic shot,
  candle fire) = 31+4 = 35 tiles × 4 = 140. ITEM end: 1337+140=1477.
- Headroom: 1477..1535 = 58 tiles for future SCENE_OBJ.
- SCENE_OBJ design + content (enemies/bosses/NPCs) deferred to
  PR-4 / PR-5 with smaller per-context banks (e.g., 32 enemy
  tiles per swap, 16 boss tiles, 8 NPC tiles via demand-loading).

This narrows PR-1 to: preflight + manifest v2 + gen_atlas refactor
+ G3 debt note. ITEM extension in PR-3.

Final foundation ranges:
| Region        | Tiles | Range      |
|---------------|-------|------------|
| blank         | 1     | 0          |
| BG_4x         | 1024  | 1..1024    |
| SPR_1x        | 312   | 1025..1336 |
| ITEM_4x       | 124   | 1337..1460 | (unchanged in PR-1; extended in PR-3) |
| reserved      | 75    | 1461..1535 | (PR-3 + PR-4 + PR-5 consume) |

## Implications

- **PR-2 redirected**: instead of "implement chosen budget", PR-2
  becomes "design SCENE_OBJ transient region + per-context size
  budgets" since BG path eliminated. May fold into PR-1 if
  SCENE_OBJ contract design is small enough; otherwise standalone.
- **PR-3 unchanged**: ITEM_4x extension for triforce + FX (4
  total new tiles).
- **PR-4 narrowed**: per-level enemy CHR uses content-trimmed
  banks (e.g., load only 8-16 enemy tiles per level via
  per-room enemy reduction; defer full enemy variety).
- **PR-5 unchanged**: bosses get their own transient slot.

## Approval

Decision approved by:
- Codex (review pass v3): SPR-split + shared transient
  recommended.
- octo:droids:octo-code-reviewer (PR-1 review): pending.

## Next actions (PR-1 execution remaining)

1. ✅ Preflight audits run + locked.
2. ✅ Decision artifact landed (this file).
3. ⏳ Manifest v2 schema scaffold (`RoomRom/data/chr_atlas_master.json`).
4. ⏳ gen_atlas.py data-driven refactor (byte-equal items_chr_x4
   regression).
5. ⏳ Drain debt note `tools/audit/drain_findings/g3_item_take_item_externs.md`.
6. ⏳ verify_item_chr_manifest.py extension for v2 schema.
7. ⏳ build_combined_debug.py adds gates.
8. ⏳ CombinedDebug.bat clean + ph5.4-9 gates GREEN.
9. ⏳ Commit `pr-1 chr-foundation: preflight + decision lock`.
