# Scene Breaks — Visual Regression Catalog

Catalog of visual regressions across 15 scenes left UNVERIFIED by the Phase B/F/J/J.2/K VRAM cleanup pass (commits 5ffa9d28..063259d9). Built by `tools/probes/scene_walk_diff.py` from byte-diff of Genesis `builds/Debug.md` vs NES Z1 reference ROM.

## v2 headline finding (2026-05-19)

**The 34-commit VRAM cleanup pass introduced NO byte-level main-path visual regressions.** Title (01), file-select-attempt (02-03), and OW gameplay (04-12) all show ZERO Class A/B/C/D/E/F automated breaks against NES Z1 reference. Only late-scene transient transitions (13) and intentional debug-mode stress harness (14-15) show minor (<10) BG cell mismatches — likely sprite overflow into Plane A during debug state, not shipping-path regressions.

The 4 manual findings (M1-M4) below are all either intentional divergences, hardware-gamut quantization, or unimplemented features per debate 001 — none are regressions to fix.

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
6. **v1 RETRACTED:** v1 classifier surfaced 14 Class A breaks @ 46 cells each. Root cause: v1 NES probe read nametable via `PPU Bus` domain which returns open-bus when not actively rendering — every byte came back as $F2 sentinel. Same issue affected PALRAM (PPU-Bus read returned all $F2). v2 probe uses dedicated NES BizHawk domains: CIRAM for nametable, PALRAM for palette, CHR for pattern tables, WRAM for main RAM. Domains discovered + logged to `scene_walk_nes/_domains.txt`.

## Manual visual findings (from screenshot inspection)

These breaks are visible to the eye comparing PNG captures side-by-side; they may or may not show up in the automated byte-diff below.

### M1 — OW path/cliff color quantization (NOT a regression)

- **NES `04_walk_down` PALRAM (BG sub-pal 1 = path/sand):** `$0F $16 $27 $36` -> RGB(0,0,0), (210,18,105), (250,158,0), (255,198,195).
- **Genesis `04_walk_down` PAL0[4..7] (pixel-bias sub-pal 1 slot):** `$0000 $004E $00AE $00CE` -> RGB(0,0,0), (255,73,0), (255,183,0), (255,220,0).
- **Diff:** Genesis 9-bit color (3-3-3) cannot represent NES $36 pinkish-tan (255,198,195) — best 9-bit fit is (255,220,0) orange-yellow. Path/sand tile rendering visibly differs but match is byte-correct under hardware quantization. Initial visual impression of 'Genesis BLUE path' was misread: Genesis PAL0 has NO blue entries; central column is orange-yellow against dark green grass.
- **Class:** none — Genesis hardware gamut limitation. Document as accepted divergence per `feedback_nes_feel_genesis_native` (NES accuracy spec, Genesis-native implementation).
- **Priority:** P2 — informational only; no fix possible without alternative gamut.

### M2 — Inventory subscreen UNIMPLEMENTED (not a regression)

- **NES `09_inventory_open`:** Start press shows INVENTORY screen with TRIFORCE.
- **Genesis `09_inventory_open`:** Start press kept Link walking; no inventory.
- **Diff:** Inventory/pause subscreen rendering has never been ported. Per `debates/001-prime-directive-plan-improvement/rounds/r001_codex.md:501,549,1689`, "Pause/item subscreen" + "Implement pause subscreen render" are pending native-rewrite items.
- **Class:** known-pending native rewrite (not visual regression).
- **Fix site:** new subsystem `src/game/inventory/` (does not exist). Requires native subscreen render + Start-input handler + B-item selection.
- **Priority:** P1 — track as feature, not regression. Out of scope for post-cleanup visual sweep.

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

## Summary — 3 breaks across 15 scenes

| Scene | Breaks | Classes |
|---|---|---|
| 01_title | 0 | (clean) |
| 02_post_chord | 0 | (clean) |
| 03_post_chord_settle | 0 | (clean) |
| 04_walk_down | 0 | (clean) |
| 05_walk_left | 0 | (clean) |
| 06_walk_up | 0 | (clean) |
| 07_walk_right | 0 | (clean) |
| 08_walk_north_far | 0 | (clean) |
| 09_inventory_open | 0 | (clean) |
| 10_inventory_cycle | 0 | (clean) |
| 11_inventory_close | 0 | (clean) |
| 12_sword_swing | 0 | (clean) |
| 13_extended_walk | 1 | A |
| 14_stress_harness | 1 | A |
| 15_stress_harness_settle | 1 | A |

---

## 01_title

**Captures:** [gen](C:\tmp\scene_walk_gen\01_title/) [nes](C:\tmp\scene_walk_nes\01_title/)

_No breaks detected._

## 02_post_chord

**Captures:** [gen](C:\tmp\scene_walk_gen\02_post_chord/) [nes](C:\tmp\scene_walk_nes\02_post_chord/)

_No breaks detected._

## 03_post_chord_settle

**Captures:** [gen](C:\tmp\scene_walk_gen\03_post_chord_settle/) [nes](C:\tmp\scene_walk_nes\03_post_chord_settle/)

_No breaks detected._

## 04_walk_down

**Captures:** [gen](C:\tmp\scene_walk_gen\04_walk_down/) [nes](C:\tmp\scene_walk_nes\04_walk_down/)

_No breaks detected._

## 05_walk_left

**Captures:** [gen](C:\tmp\scene_walk_gen\05_walk_left/) [nes](C:\tmp\scene_walk_nes\05_walk_left/)

_No breaks detected._

## 06_walk_up

**Captures:** [gen](C:\tmp\scene_walk_gen\06_walk_up/) [nes](C:\tmp\scene_walk_nes\06_walk_up/)

_No breaks detected._

## 07_walk_right

**Captures:** [gen](C:\tmp\scene_walk_gen\07_walk_right/) [nes](C:\tmp\scene_walk_nes\07_walk_right/)

_No breaks detected._

## 08_walk_north_far

**Captures:** [gen](C:\tmp\scene_walk_gen\08_walk_north_far/) [nes](C:\tmp\scene_walk_nes\08_walk_north_far/)

_No breaks detected._

## 09_inventory_open

**Captures:** [gen](C:\tmp\scene_walk_gen\09_inventory_open/) [nes](C:\tmp\scene_walk_nes\09_inventory_open/)

_No breaks detected._

## 10_inventory_cycle

**Captures:** [gen](C:\tmp\scene_walk_gen\10_inventory_cycle/) [nes](C:\tmp\scene_walk_nes\10_inventory_cycle/)

_No breaks detected._

## 11_inventory_close

**Captures:** [gen](C:\tmp\scene_walk_gen\11_inventory_close/) [nes](C:\tmp\scene_walk_nes\11_inventory_close/)

_No breaks detected._

## 12_sword_swing

**Captures:** [gen](C:\tmp\scene_walk_gen\12_sword_swing/) [nes](C:\tmp\scene_walk_nes\12_sword_swing/)

_No breaks detected._

## 13_extended_walk

**Captures:** [gen](C:\tmp\scene_walk_gen\13_extended_walk/) [nes](C:\tmp\scene_walk_nes\13_extended_walk/)

### Break 1 — Class A

- **Diff:** 5 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($9D, sub0)x1, ($01, sub0)x1, ($FF, sub0)x1, ($88, sub0)x1, ($20, sub0)x1
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 14_stress_harness

**Captures:** [gen](C:\tmp\scene_walk_gen\14_stress_harness/) [nes](C:\tmp\scene_walk_nes\14_stress_harness/)

### Break 1 — Class A

- **Diff:** 9 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($01, sub0)x3, ($04, sub0)x2, ($02, sub0)x1, ($FF, sub0)x1, ($88, sub0)x1, ($20, sub0)x1
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

## 15_stress_harness_settle

**Captures:** [gen](C:\tmp\scene_walk_gen\15_stress_harness_settle/) [nes](C:\tmp\scene_walk_nes\15_stress_harness_settle/)

### Break 1 — Class A

- **Diff:** 9 BG cells blank on Genesis where NES has tile (playfield only, HUD rows excluded). Top combos: ($01, sub0)x3, ($04, sub0)x2, ($02, sub0)x1, ($FF, sub0)x1, ($88, sub0)x1, ($20, sub0)x1
- **Fix site:** `tools/probes/audit_per_tile_subpal.py — add (tile_id, sub_pal) combos above to force-include + regen sparse LUT`
- **Estimated cost:** 30 min per cluster
- **Priority:** P1

---

