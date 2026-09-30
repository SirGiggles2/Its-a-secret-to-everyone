# T-054 slice — revealed overworld entrances

- **NES source:** `reference/aldonunez/Z_05.asm:InitMode10`, `UpdateMode10Stairs_Full`, `HandleWarpOW`, `@LoopSquareOW`.
- **Drained C:** `src/game/world/render/cave_fade.c` (active native owner); `src/game/world/render/ow_render.c` for the revealed square; no drained mode-10 sequencer.
- **Coverage / stance:** PARTIAL (tree and bomb-wall connected entry, plus existing `$24` pad regression); EXTEND active fade with the NES tile-specific branch. Other OW objects and UW secrets remain T-054 work.

The previous fade always descended Link 16 pixels over about 64 frames. A live Q1 burned-tree entry showed NES mode `$10` at tick 361 and cave mode `$0B` at tick 362; Genesis stayed in the descent. The NES code branches on the collided tile: only `$24` sets a target Y and descends; revealed stairs and other entrance tiles hand off to the target mode on the next update. NES also requests the stairs effect only for `$24`.

The active cave fade now receives the actual standing tile. For non-`$24`, its first mode-10 update starts cave loading without the walk-down; `$24` keeps its existing descent. The caller preserves NES `UndergroundEntranceTile` (`$0065`) and saves the OW room kill count before leaving, as `HandleWarpOW` does. Its stairs sound request is limited to `$24`.

Focused live NES/Genesis results using `tools/lockstep/presets/t054_tree_enter.json` and `t054_wall_enter.json`:

| Natural reveal | Entrance check | Result and limit |
|---|---|---|
| Burn tree, room `$78` | Candle reveals real stairs; fixture stages Link onto that stair after reveal, without editing tiles or room flags. | Both reach mode `$10` tick 361, cave `$74` mode `$0B` tick 362; room flag `$80`, entrance tile `$71`, Link position agree. Genesis reaches target one video frame sooner and finishes cave load 11 frames sooner. Strict KEY fails from tick 362 on FrameCounter/RNG drift; **not** a full lockstep pass. |
| Bomb wall, room `$76` | Bomb reveals real opening; fixture stages Link at that opening after reveal, without editing tiles or room flags. | Both reach mode `$10` tick 365/frame 469, then take the `$24` descent and reach cave `$70` mode `$0B` tick 366/frame 535. Room flag `$82` after kill-count save, entrance tile `$24`, and 550/550 KEY cells agree. New fixture has no full-RAM baseline, so ratchet gate remains FAIL; **not** a full gate pass. |
| Quest 2 cave pad `$74` | Existing natural `$24` pad from T-054 layout slice. | Focused `t054_q2_cave74_gen.lua` still reaches cave `$78` after the API change. |

The 11-frame load difference is faster Genesis cave loading, not the former 64-frame false descent. The user explicitly accepts faster Genesis behavior and one-frame differences. Do not use strict tick-gate failure as a claim that the revealed entrances fail; equally, do not cite these staged approaches as an unassisted route. No broad dungeon matrix was rerun for this local cave-edge change.

`Debug.bat` PASS; final SHA-256 `779E7E2BE7DF5036B46DF8EC195254284DFD42B93517DDE2F3F423785AB5A962`. The tree case was rerun on that exact build; its divergence stayed confined to the documented frame/RNG and subsequent load-state differences. Detailed local traces and per-tick diff are under `builds/reports/lockstep/t054_tree_enter/` and `t054_wall_enter/`. `tools/audit/inventory_ow_cave_doors.py` lists ROM-derived Q1/Q2 cave selectors and the OW tile-object types in their layouts; it is an inventory, not reachability or behavior evidence.

Remaining T-054 work: natural rock/grave/Armos/dock interactions and UW push-block/door cases. Keep T-164 cave-interior acceptance and T-050 previously accepted secret effects at their documented scopes.
