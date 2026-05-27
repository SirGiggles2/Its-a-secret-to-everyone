Warning: True color (24-bit) support not detected. Using a terminal with true color enabled will result in a better visual experience.
YOLO mode is enabled. All tool calls will be automatically approved.
YOLO mode is enabled. All tool calls will be automatically approved.
Ripgrep is not available. Falling back to GrepTool.
(node:15584) [DEP0190] DeprecationWarning: Passing args to a child process with shell option true can lead to security vulnerabilities, as the arguments are not escaped, only concatenated.
(Use `node --trace-deprecation ...` to show where the warning was created)
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 2s.. Retrying after 5883ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 6s.. Retrying after 6892ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 2s.. Retrying after 5286ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 3s.. Retrying after 5847ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 5s.. Retrying after 5441ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 3s.. Retrying after 5822ms...
# Debate 057: Every cave sprite + animation byte-perfect vs NES

To achieve byte-perfect cave parity, we must address the mapping between NES OAM/CHR/PAL and the Genesis VDP while identifying "Genesis High" opportunities.

### Advisor 1: The Parity Purist (Core Parity & Animation)
**Focus:** 1:1 behavioral and visual matching of the NES original.

The current implementation in `src/game/cave/cave_dispatch.c` correctly initializes the cave person (Slot 1) and bonfires (Slots 2/3), but there is a regression in animation cadence. `enrt_update_standing_fire` at `src/oracle/enemies/enemy_walker_runtime.c:146` (drained) hardcodes the draw frame to `0`:
```c
c_draw_object_not_mirrored_with_frame(0, slot); // BUG: Always frame 0
```
This prevents the "StandingFire" ($40) 2-frame animation. It must be updated to use `ENEMY_FRAME(slot)`, which is toggled by `z07_animate_object_walking`. The frame heap at `src/game/world/draw_dispatch.c:118` contains the necessary tiles: `k_obj_anim_frame_heap[0xC6]` is `0xC0` (Frame 0) and `0xC7` is `0xC8` (Frame 1).

**Tasks:**
1.  **Fix Bonfire Cadence:** Update `enrt_update_standing_fire` to use `ENEMY_FRAME(slot)`.
2.  **Verify CHR:** Ensure `data/chr/MANIFEST.json` includes the full `sprites` range up to `0xC8` for bonfires and `0xB0-0xB3` for NPCs. Current `tile_count: 232` at `MANIFEST.json:34` covers IDs `0..231`, which is sufficient for tiles `0xC0` and `0xC8`.
3.  **State Transitions:** Ensure `CAVE_PERSON_STATE` transitions (0..8) correctly trigger `core_cue_transfer_blank_person_wares` at `cave_dispatch.c:505`, clearing item sprites once taken.

**Effort:** 1.5 days.

---

### Advisor 2: The Genesis Power Advocate (Visual Enhancements)
**Focus:** Improving the experience beyond NES limits.

The Genesis allows us to exceed the 8-byte cave palette (`k_cave_subpal_2_3_nes` at `src/game/world/render/cave_palette.c:6`). While the NES is restricted to two 4-color sub-palettes for sprites, we can utilize full 16-color palettes.

**Opportunities:**
1.  **60fps Animation:** Smooth the bonfire flame animation from the NES's 15fps (8-frame toggle) to 60fps. Interpolate the tile change or use more frames in VRAM.
2.  **Smooth Flicker:** Replace the 30Hz palette strobe with a software-interpolated "glow" effect in `palette_tick_runtime.c`.
3.  **NPC Shadows:** Add a 1-pixel drop shadow or an 8x8 circular shadow sprite under the NPC (Slot 1) and Bonfires to ground them in the room, which the NES couldn't afford.
4.  **Item Bob:** Give shop items (`cave_draw_items`) a subtle 1-2 pixel vertical bob using a sine table, improving the "premium" feel of the shop.

**Effort:** 2 days.

---

### Advisor 3: The Infrastructure Lead (Verification & CI)
**Focus:** Long-term stability and regression testing.

To guarantee byte-perfection across all 20 caves ($6A..$7D), we need an automated golden-image pipeline.

**Strategy:**
1.  **Golden Bundles:** Create a `tests/goldens/caves/` directory containing OAM, Palette, and CHR snapshots for every cave_id.
2.  **Automated Probe:** Extend `RoomRom/probe_roomrom_all.lua` to iterate through all cave rooms, forcing `CAVE_PERSON_STATE` through its cycle and dumping VDP state at each frame.
3.  **Byte-Diff CI:** Add a Python script `verify_cave_parity.py` that compares the live probe dump against the goldens. Any difference in `sat_attrs` (tile ID, flip, palette) or `cram` entries results in a build failure.
4.  **OAM Audit:** Specifically verify `draw_dispatch.c:134` `Anim_WriteSpritePairNotFlashing` correctly publishes the `ITEM_ATTR_MARKER` (0x08) for cave wares, ensuring they route to the correct `ROOMROM_ITEM_TILE_BASE` (896).

**Effort:** 3 days (highest ROI for long-term maintenance).

---

### Effort Summary
| Step | Task | Effort |
| :--- | :--- | :--- |
| 1 | Parity Fixes (Bonfire, CHR Audit) | 1.5 Days |
| 2 | Genesis Enhancements (60fps, Glow) | 2 Days |
| 3 | Verification Infra (Goldens, CI) | 3 Days |
| **Total** | | **6.5 Days** |

**Final Recommendation:** Prioritize Step 1 and Step 3 immediately to lock in the "Byte-Perfect" promise, then apply Step 2 "Genesis High" improvements as a polish pass.
