# Scene Breaks — Visual Regression Catalog

Catalog of visual regressions across 15 scenes left UNVERIFIED by the Phase B/F/J/J.2/K VRAM cleanup pass (commits 5ffa9d28..063259d9). Built by `tools/probes/scene_walk_diff.py` from byte-diff of Genesis `builds/Debug.md` vs NES Z1 reference ROM.

## Probes

- Genesis: `build/probes/scene_walk_full.lua`
- NES:     `build/probes/scene_walk_nes_reference.lua`

## Captures

- Genesis: `C:\tmp\scene_walk_gen`
- NES:     `C:\tmp\scene_walk_nes`

## Class legend

- **A** — sparse LUT miss (`bg_sparse_tile_lut` 0xFFFF sentinel)
- **B** — extracted CHR from wrong NES bank (`item_chr_manifest.json` provenance bad)
- **C** — item dispatch placeholder (`sprite_render.c:611-684` missing case → boomerang fallback tile 826)
- **D** — stale SCENE_OBJ contract (`gen_atlas.py` SCENE_CONTRACTS tile_count drift)
- **E** — sub-pal 3 sprite clamped to sub-pal 2 (transient CRAM swap missing)
- **F** — CRAM conflict (4-PAL collapse forces palette overlap)

## v1 catalog limitations (read before acting on tickets)

1. **Scene-state misalignment.** Genesis port's boot-chord enters gameplay directly while NES sequences through FILE SELECT first. Scenes labeled the same on both sides may capture different game states (e.g. `02_post_chord` is OW on Genesis, FILE SELECT on NES). Byte-diff at those scenes is informational only — surface as scene-state-mismatch tickets, not visual regressions.
2. **Window plane not captured.** Z1 HUD on Genesis renders via Window plane; v1 probe captures only Plane A + Plane B + SAT. HUD-region byte-diff is masked: classifier excludes top 4 nametable rows to compensate. v2 probe should add Window dump at $B000.
3. **CRAM/PALRAM routing is heuristic.** Without consulting `subpal_routing.h` at runtime, palette comparison uses a placeholder mapping. Class F detection is gated to >=70% mismatch to avoid noise; real palette-level regressions need v2 with proper sub-pal route table.
4. **Genesis port Start-button does not open inventory.** Pressed Start mid-gameplay on Genesis kept Link walking; on NES it opened inventory. Likely a genuine missing wire-up — `09_inventory_open` should be a P0 ticket investigated separately.
5. **Room locked at $77 across all gameplay scenes.** Genesis port's OW navigation worked (Link XY changed) but room boundaries did not trigger reload to neighbors. Either intentional dev-loop confinement (memory `project_roomrom_debug_teleport`) or a transition regression.

## Manual visual findings (from screenshot inspection)

These breaks are visible to the eye comparing PNG captures side-by-side; they may or may not show up in the automated byte-diff below.

### M1 — OW path color: Genesis BLUE, NES TAN/DIRT

- **NES `08_walk_north_far`:** Z1 OW dirt path renders as TAN/SAND.
- **Genesis any OW scene 02-13:** path renders as BLUE diagonal stripe.
- **Diff:** BG sub-palette assignment for path tile differs. Path tile (NES tile $C6 / $C7 region per Z1 OW BG bank) routes to a different Genesis CRAM slot than NES PALRAM expects.
- **Class:** likely F (4-PAL collapse) or A (sparse LUT hit but wrong sub-pal route).
- **Fix site:** verify path tile entry in `bg_sparse_tile_lut[$C6][sub_pal]` and the BG sub-pal route at `src/game/world/render/subpal_routing.h`.
- **Priority:** P1 — visible across entire OW, not gameplay-blocking.

### M2 — Genesis Start button does not open inventory

- **NES `09_inventory_open`:** Start press shows INVENTORY screen with TRIFORCE.
- **Genesis `09_inventory_open`:** Start press kept Link walking; no inventory.
- **Diff:** Start-button → inventory transition not wired on Genesis port.
- **Class:** out-of-scope for visual-only sweep (gameplay logic), but should be tracked as a follow-up — affects all inventory-dependent regression tests.
- **Fix site:** `src/game/world/` input handler — find where Z1 Start press is normally translated to inventory open and add Genesis hook.
- **Priority:** P0 (blocks inventory subsystem verification).

### M3 — Genesis port skips FILE SELECT screen

- **NES `02_post_chord`:** post-Start lands at FILE SELECT (NAME/LIFE columns).
- **Genesis `02_post_chord`:** ABC+Start chord goes direct to gameplay.
- **Class:** intentional per memory `project_title_screen_goal` ("title + FS customized, NOT NES parity"). Document divergence; not a regression.
- **Priority:** P2 — informational.

### M4 — Stress harness HUD overlay glitch

- **Genesis `14_stress_harness` / `15_...settle`:** ABC chord during gameplay triggers debug stress harness (memory `project_debug_enter_stress_harness`); top-of-screen HUD region shows scattered enemy sprite overflow.
- **NES:** no equivalent; Link died from enemy contact → GAME OVER screen.
- **Class:** debug-mode artifact; not a release-path regression.
- **Priority:** P2 — confirms stress harness path still fires; no fix needed.

---

## Summary — 14 breaks across 15 scenes

| Scene | Breaks | Classes |
|---|---|---|
| 01_title | 0 | (clean) |
| 02_post_chord | 1 | A |
| 03_post_chord_settle | 1 | A |
| 04_walk_down | 1 | A |
| 05_walk_left | 1 | A |
| 06_walk_up | 1 | A |
| 07_walk_right | 1 | A |
| 08_walk_north_far | 1 | A |
| 09_inventory_open | 1 | A |
| 10_inventory_cycle | 1 | A |
| 11_inventory_close | 1 | A |
| 12_sword_swing | 1 | A |
| 13_extended_walk | 1 | A |
| 14_stress_harness | 1 | A |
| 15_stress_harness_settle | 1 | A |

---

## 01_title

**Captures:** [gen](C:\tmp\scene_walk_gen\01_title/) [nes](C:\tmp\scene_walk_nes\01_title/)

_No breaks detected._

## 02_post_chord

**Captures:** [gen](C:\tmp\scene_walk_gen\02_post_chord/) [nes](C:\tmp\scene_walk_nes\02_post_chord/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 03_post_chord_settle

**Captures:** [gen](C:\tmp\scene_walk_gen\03_post_chord_settle/) [nes](C:\tmp\scene_walk_nes\03_post_chord_settle/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 04_walk_down

**Captures:** [gen](C:\tmp\scene_walk_gen\04_walk_down/) [nes](C:\tmp\scene_walk_nes\04_walk_down/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 05_walk_left

**Captures:** [gen](C:\tmp\scene_walk_gen\05_walk_left/) [nes](C:\tmp\scene_walk_nes\05_walk_left/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 06_walk_up

**Captures:** [gen](C:\tmp\scene_walk_gen\06_walk_up/) [nes](C:\tmp\scene_walk_nes\06_walk_up/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 07_walk_right

**Captures:** [gen](C:\tmp\scene_walk_gen\07_walk_right/) [nes](C:\tmp\scene_walk_nes\07_walk_right/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 08_walk_north_far

**Captures:** [gen](C:\tmp\scene_walk_gen\08_walk_north_far/) [nes](C:\tmp\scene_walk_nes\08_walk_north_far/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 09_inventory_open

**Captures:** [gen](C:\tmp\scene_walk_gen\09_inventory_open/) [nes](C:\tmp\scene_walk_nes\09_inventory_open/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 10_inventory_cycle

**Captures:** [gen](C:\tmp\scene_walk_gen\10_inventory_cycle/) [nes](C:\tmp\scene_walk_nes\10_inventory_cycle/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 11_inventory_close

**Captures:** [gen](C:\tmp\scene_walk_gen\11_inventory_close/) [nes](C:\tmp\scene_walk_nes\11_inventory_close/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 12_sword_swing

**Captures:** [gen](C:\tmp\scene_walk_gen\12_sword_swing/) [nes](C:\tmp\scene_walk_nes\12_sword_swing/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 13_extended_walk

**Captures:** [gen](C:\tmp\scene_walk_gen\13_extended_walk/) [nes](C:\tmp\scene_walk_nes\13_extended_walk/)

### Break 1 — Class A

- **Diff:** 46 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub2)x7, ($F2, sub0)x7
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 14_stress_harness

**Captures:** [gen](C:\tmp\scene_walk_gen\14_stress_harness/) [nes](C:\tmp\scene_walk_nes\14_stress_harness/)

### Break 1 — Class A

- **Diff:** 56 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub0)x13, ($F2, sub2)x11
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 15_stress_harness_settle

**Captures:** [gen](C:\tmp\scene_walk_gen\15_stress_harness_settle/) [nes](C:\tmp\scene_walk_nes\15_stress_harness_settle/)

### Break 1 — Class A

- **Diff:** 56 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($F2, sub3)x32, ($F2, sub0)x13, ($F2, sub2)x11
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

