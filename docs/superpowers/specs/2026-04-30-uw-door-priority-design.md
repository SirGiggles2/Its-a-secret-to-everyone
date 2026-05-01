# UW Door Priority — Native Genesis (NES Feel)
2026-04-30

## Problem
In dungeon (UW) rooms, Link's sprite renders on top of door arch tiles in all
four cardinal door positions. Should render behind the arch (lintel/jambs hide
Link's head and torso) while still appearing to walk *on* the floor tile of the
doorway.

## NES Reference (canonical behavior)
- Routine: `ShowLinkSpritesBehindHorizontalDoors` (z_01:1594).
- Called every frame in the z_07 main Link loop (z_07:3381) and during the
  wallmaster grab cinematic (z_04:3572).
- Effect: ORs $20 (NES OAM attr bit 5 = "behind background") into a fixed pair
  of NES OAM slots — `$0240+10` and `$0240+14` (= sprites 18 and 19 in the
  64-slot NES OAM at `$0200`).
- Trigger: only when Link X ≥ $E9 OR Link X < $10 (i.e., Link straddles the
  left or right screen edge during a horizontal door transition).
- **Top/bottom doors are NOT covered.** NES does not flip Link's priority for
  vertical traversal; he stays sprite-front during the vertical scroll. This
  spec matches that. (User picked NES parity.)

## Genesis Pipeline (already wired)
1. `_compose_bg_tile_word` (nes_io.asm:1527) sets bit 15 on every BG tile word
   it composes. Plane A cells are globally high priority.
2. `_oam_dma` (nes_io.asm:2046) translates NES OAM → Genesis SAT once per frame.
   When NES OAM byte 2 has bit 5 set, it leaves Genesis SAT word 2 bit 15 clear
   (sprite low priority); otherwise it sets bit 15 (sprite high priority).
3. VDP layer compare: Plane A high-priority opaque pixel beats sprite low-prio.
   Plane A high-priority pixel that is color-0 (transparent) lets the sprite
   show through. Result: Link's head disappears behind the opaque arch pixels
   while his feet remain visible over the color-0 floor — the canonical NES
   look.

The pipeline therefore exists end-to-end. The bug is somewhere along its path.

## Failure Modes (one of)
- **F1** — JSR z_07:3381 not firing in UW state (mode-gate or call-graph break).
- **F2** — function fires, but the hardcoded OAM offsets (10, 14) do not match
  the slots Link actually occupies in our build's sprite scheduler.
- **F3** — bit 5 set in NES OAM, but `_oam_dma` does not honor it on the active
  branch (e.g., a CHR_EXPANSION-conditional break).
- **F4** — BG door tiles in UW are written through a path that doesn't go
  through `_compose_bg_tile_word`, so they lack bit 15.
- **F5** — UW arch CHR pixels are color-0 in the area covering Link's head
  (CHR extraction shape error). Even with priority correct, transparent pixel
  ⇒ sprite shows through.

## Approach — NES feel, Genesis-native
Two-step: (1) probe to localise the break, (2) native rewrite + targeted fix.

### Step 1 — Single-shot diagnostic probe
A BizHawk Lua probe drives the ROM into a left-doorway repro and dumps every
relevant signal in one frame:

- Boot, Start through title, advance from FS into a dungeon room with left/right
  doors. Reuse `RoomRom/probe_nes_uw_walk_diag.lua` as the launch template for
  the boot+input sequence; extend it with the threshold-frame capture below.
- Walk Link to the left doorway threshold (NES X around $08).
- At the threshold frame:
  - Read NES RAM `$0010` (game mode), `$0070` (Link X), `$0084` (Link Y).
  - Dump full NES OAM `$0200..$02FF` and locate slots whose tile bytes match
    Link's CHR IDs (from `CommonSpritePatterns`); record their attr bytes.
  - Dump Genesis VDP SAT (`$F800..$FBFF`); record word-2 priority bit for the
    slots that correspond to Link's NES OAM entries.
  - Dump the Plane A nametable word at the tile cell containing the door arch
    above Link (bit 15 = priority).
  - Save a PNG screenshot.
- Output: `tools/out/uw_door_probe.json` plus `uw_door_probe.png`.
- Single BizHawk launch, single probe — per `feedback_one_big_probe`.

### Step 2 — Native C rewrite of the routine
Replace the body of `sprrt_show_link_sprites_behind_horizontal_doors`
(sprite_runtime.c:37) with a clean, magic-number-free version:

- Determine Link's current OAM slots dynamically by scanning the 64-entry NES
  OAM (`$0200..$02FF`) for tile bytes belonging to Link's CHR ID set
  (`CommonSpritePatterns` Link tile range — see `project_chr_extractor_seam_bug`
  memory; concrete IDs to be enumerated from `tiles_sprites.inc` during
  implementation). This is more robust than reading the sprite scheduler state,
  which is itself frame-transient.
- For each Link OAM entry whose X coordinate satisfies the NES original gate
  (X ≥ $E9 OR X < $10), OR `$20` into that entry's attr byte.
- Preserve the NES OAM intermediate so the wallmaster call site (z_04:3572)
  continues to work without changes.
- No new VDP/SAT calls; rely on the already-wired `_oam_dma` honor path.

This eliminates F2 (slot drift) by construction and gives us a single,
canonical native source of truth for the door-priority rule.

If the probe shows the failure is F3/F4/F5 instead of F2, the rewrite still
stands as a hardening pass, and an additional targeted fix is added in the
relevant layer:
- F3 → patch the broken `_oam_dma` branch in nes_io.asm.
- F4 → audit the UW BG write path; route it through `_compose_bg_tile_word`.
- F5 → re-extract UW arch CHR via the existing CHR pipeline.

### Step 3 — Verify
- Second probe at the left-doorway threshold and at the right-doorway threshold.
- Visual confirmation: head/torso obscured by arch, feet visible on floor.
- Cross-check: top/bottom doorways still show Link on top (no regression on
  NES parity).
- Wallmaster grab cinematic still triggers the priority drop correctly.
- Build green; no vasm/SGDK errors.
- Commit per `caveman-commit` style.

## Architecture (post-fix)
- `src/game/world/sprite_runtime.c`: native door-priority logic, dynamic Link
  OAM slot lookup, no `0x0240+10/14` magic numbers.
- `src/zelda_translated/z_07.asm:3381`, `z_04.asm:3572`: untouched call sites.
- `src/c_shims.asm`: untouched trampoline.
- Pipeline layers (`_compose_bg_tile_word`, `_oam_dma`, VDP compare): untouched
  unless the probe localises the bug there.

## Out of Scope
- Top/bottom door arch priority. NES does not do it; user picked NES parity.
- Native UW room renderer. Tracked under separate milestone.
- Tile-tag BG-priority approach (rejected: diverges from NES feel and shifts
  the bug to per-tile metadata maintenance).

## Risk
- Probe may show CHR pixel transparency (F5) is the actual culprit. The native
  rewrite still ships as hardening, but the visual fix moves to a follow-on CHR
  re-extraction spec.
- Wallmaster grab uses the same routine. Spec verification step explicitly
  re-tests it.

## Acceptance
- Walking Link into a left UW doorway: head/torso clearly behind the arch.
- Walking Link into a right UW doorway: head/torso clearly behind the arch.
- Top/bottom doorways: Link stays sprite-front (NES parity).
- Wallmaster grab cinematic: unchanged visually.
- Build green; commit lands.
