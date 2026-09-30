# T-054 slice — Quest 2 overworld layout and cave pad

- **NES source:** `reference/aldonunez/Z_05.asm:LayoutRoomOW` reads installed `LevelBlockAttrsD`; `FillPlayAreaAttrs` reads installed A/B. `Z_06.asm:@PatchQ2Rooms` changes three D, two A and eight B entries after the overworld block is installed.
- **Drained implementation:** none for this renderer path; active native owner `src/game/world/render/ow_render.c`. Stance: correct the existing renderer, keeping Redux's separate blob.
- **Coverage:** data, static presentation and one naturally present Quest 2 cave pad PASS. T-054 stays ACTIVE for other secret mechanisms and UW objects/doors.

The Quest 2 `q2_ow` live NES/Genesis captures had matching installed level-block bytes, but `ow_col_dirs` and `compute_metatile_col` ignored them. They read unpatched `rooms_overworld[]` for layout D and palettes A/B. In room `$74`, the NES installed D=`$5A`, B=`$7A`; the Genesis renderer selected Q1 D=`$6F`, B=`$0F`. The pre-fix Genesis raw tiles agreed with only **568/704** NES playfield tiles and showed a wrong central structure. This was a renderer-consumer defect, not a missing Quest 2 patch (T-007's installed data remains accepted).

Original rendering now reads installed NES RAM `$687E/$68FE/$69FE` for A/B/D. Redux continues to read its own map blob. The room-layout cache also keys on map, installed layout ID and world flags, so a quest/secret change cannot reuse a stale room result.

Focused live results:

| Case | NES source capture | Genesis capture | Result |
|---|---|---|---|
| Q2 `$74`, changed layout/palette and cave selector | `t054_q2_room74_nes` | `t054-q2-room74-after` | raw tiles 704/704; VRAM tile+sub-palette 704/704; before 568/704 |
| Q2 `$0B`, changed layout; dungeon entrance consumer | `t054_q2_room0b_nes` | `t054-q2-room0b-after` | raw tiles and VRAM 704/704 |
| Q2 `$3C`, changed layout and palette; dungeon entrance consumer | `t054_q2_room3c_nes` | `t054-q2-room3c-after` | raw tiles and VRAM 704/704 |
| Q2 `$74` natural `$24` pad | `t054_q2_cave74_nes` | `t054-q2-cave74-gen` | tile `$24` already in map; Link staged at `$70,$4D` without tile edits. Both enter mode `$10`, then mode `$0B` cave `$78`. |
| Q1 bomb wall `$76`, burned tree `$78` | `t050_wall`, `t050_tree` | same lockstep runs | each 400/400 KEY, 0 new full-RAM divergences; both set room secret flag `$80` on NES and Genesis. |

NES room captures use the Quest 2 file card and stage `CaveSourceRoomId` only at Mode 3 submode 1, so the engine itself lays out the selected room. Genesis room captures use debug room navigation, then dump the untouched raw tile cache and VRAM. `tools/lockstep/verify_plane.py` reports NES NT0 → Genesis plane `$C000`, row 7/col 0, with zero tile or palette mismatches in all three rooms. This is static presentation evidence, not proof of an unassisted walking route. The cave-pad probe positions Link on a naturally present tile; it does not inject an entrance tile. The NES mode trace reaches cave `$78` at tick 219; Genesis reaches mode `$0B` and cave `$78`. The prior T-164 cave-runtime evidence owns the interior.

`Debug.bat` PASS on SHA-256 `7d6253ea482a6e7049e45a0e119ca567dde2f7abda5405d9cc6140b6f88e1810`. The current shared build includes Claude's unrelated uncommitted `RoomRom/src/main.c` edits; this task does not stage or commit them. Exact generated traces, launch identities and captures are under `builds/reports/lockstep/t054_*` and `builds/reports/recovery/t054-*`; the NES ROM and built Genesis ROM remain local.

Remaining T-054 work: check the distinct natural reveal mechanisms (rock/grave push, bomb wall, tree, Armos and other overworld secrets) at focused NES/Genesis scope, plus UW push-block/secret-door behavior. Do not infer all OW secret entries from the `$74` pad or the two Q1 flag checks.
