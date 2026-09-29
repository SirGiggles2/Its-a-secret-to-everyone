# T-164 — non-dungeon overworld cave system (in progress)

- **NES source**: `reference/aldonunez/Z_05.asm:HandleWarpOW/SetTargetMode/CheckSubroom`; `Z_01.asm:InitCave/UpdateCavePerson`; `Z_00.asm:DriveTune0`.
- **Drained C**: `src/oracle/cave/cave_runtime.c:cavert_init_cave/cavert_update_cave_person` (partial; active owner is `src/game/cave/cave_dispatch.c`).
- **Coverage**: PARTIAL (all 20 Q1 interiors had historical static captures; one connected gift/exit route accepted; other cave interactions, shortcut traversal and Q2 connected entrances remain unverified).
- **Stance**: EXTEND existing native cave, world-metadata and audio paths. No new game-derived assets.

## Inventory and scope

`tools/parity/warp_routes_expected.json` and current ROM-derived `rooms_overworld[]` contain 128 overworld room entries: 36 without warp selector, 14 dungeon selectors, and **78 cave selectors** (74 regular, 4 shortcut), mapping to all 20 cave IDs `$6A–$7D`. This is Q1 source data. Quest 2 patches selected installed attributes after the blob copy. Group by distinct behavior rather than replaying all 78 doors:

| IDs | Behavior | Q1 representative rooms | Evidence now |
|---|---|---|---|
| `$6A` | one-time sword gift | `$77` | Connected entry, pickup, exit accepted in T-011; T-164 audio verified. |
| `$6B,$72` | other one-time gifts | `$06,$0E` | Static interior inherited; interaction/revisit TODO. |
| `$6C,$6D` | heart-gated sword gifts | `$0A,$09` | Reversed native heart comparison corrected; live accepted/rejected interaction TODO. |
| `$6E` | four-way shortcut cave | `$1D,$23,$49,$79` | Mode C layout and three stair destinations checked against NES from source room `$1D`; other source-room rotations/revisit TODO. |
| `$6F,$73` | text-only cave | `$1C,$75` | Static interior inherited; text/exit TODO. |
| `$70` | money game | `$10` | Static interior inherited; stake/win/loss TODO. |
| `$71` | door-repair charge | `$01` | Static interior inherited; charge/revisit/save TODO. |
| `$74` | medicine/letter shop | `$02` | Static interior inherited; letter, purchases, rejection TODO. |
| `$75,$76` | paid hints | `$1A,$70` | Static interior inherited; selection/text/payment TODO. |
| `$77–$7A` | regular shop variants | `$25,$0C,$12,$34` | Static interior inherited; stock/price/rejected purchase TODO. |
| `$7B–$7D` | one-time secret rupee awards | `$13,$0F,$2B` | Static interior inherited; amount/revisit/save TODO. |

The historical `docs/parity/cave_status.md` 20/20 claim covers static backgrounds, sprites and text stream integrity at a sampled frame. It does **not** establish shopping, payment, secret flags, shortcuts or connected Quest 2 routing. T-011/T-133/T-134/T-135/T-143 remain accepted at their recorded scopes.

## Repairs and focused checks

1. **Cave music.** Connected NES `t011_sword_cave` RAM: tick 61 enters mode `$10`, target `$0B`, `Tune0Request=$80`, song `$01`; tick 62 has song `$00`; sword lift at tick 405 plays `$08`; exit tick 710 restarts `$01`. `Z_05.asm:SetTargetMode` calls `SilenceAllSound`, and `Z_00.asm:DriveTune0` turns request bit 7 into `SilenceSong`. Genesis previously omitted request and `audio_dispatch.c` explicitly forced OW music in cave. `cave_fade_begin_enter` now writes NES target and silence request; `audio_requests` consumes it; adapter stops XGM and keys off legacy sound; dispatcher holds silence in modes B/C. Direct room-load music is deferred across cave exit until mode 5. Native BizHawk trace on `Debug.bat` SHA-256 `8c635e7dda435b4c200e6727c28079da422aa036b1cc84ab076cd91a360a011e`: video frame 342 OW song `$01`/XGM owner 1/request `$80`; 343 song 0/owner 0; sword lift 775 song `$08`; cave exit remains 0 through modes A/4; frame 1173 mode 5 restarts OW song `$01`/owner 1. `builds/reports/recovery/t164-cave-audio/trace.csv` and `launch.json` record probe execution. BizHawk's isolated probe config disables speakers; this checks driver state, not subjective audible balance.
2. **Quest 2 routes.** `level_info_install_ow` already patches installed `$68FE+room`, but `ow_meta_attr_b` read the unpatched static blob. It now reads installed SRAM, as `HandleWarpOW` does. Focused GPGX debug-Q2 probe found all five changed cave/dungeon decisions exact: `$0E:7B→$78`, `$0F:83→$7A`, `$22:84→$7B`, `$34:0F→dungeon`, `$74:7A→$78`. All five PASS in `builds/reports/recovery/t164-q2-routes/trace.txt`; this is a **data/routing probe**, not a connected cave route.
3. **Heart gate.** NES `Z_01.asm:@TryToTake` takes item when `HeartValues >= minimum` (`CPY HeartValues`, `BEQ/BCC @Take`). Native condition was reversed, accepting too-few hearts and rejecting enough hearts. Comparator corrected in `cave_dispatch.c`; build passed. A live low/high-heart acquisition scenario remains TODO before claiming behavior accepted.
4. **Shortcut cave.** NES `HandleWarpOW` selects Mode C only for selector `$50`, which maps to cave ID `$6E`; the Genesis renderer incorrectly gave the shortcut column layout to `$7B–$7D` (secret rupee caves). The Mode C layout now belongs to `$6E`. `CheckSubroom` reads four installed rooms at `$6BB2` and, before Link moves, selects stair `$50/$80/$B0` as offsets 1/2/3 modulo four. Genesis now marks the destination visited and uses its installed AttrA/F exit position through the existing Mode A/4 load. Three focused NES and GPGX runs from room `$1D` agree: `$50→$23` at `$40,$5D`; `$80→$49` at `$30,$6D`; `$B0→$79` at `$60,$6D`. Both machines show Mode C `$6E`, then Mode A `$0A`, then OW Mode 5. Evidence: `builds/reports/recovery/t164-shortcut-{nes,gen}-{50,80,B0}/` traces and launch metadata. Both probes stage the stair coordinate, so this verifies destination routing and exit positions, not an unassisted approach to each stair.

`Debug.bat` built the initial repair SHA above, then the shortcut revision SHA-256 `0ab095342bc183b48beaee41378576d1b175b7a00d2c3fe1072dd29f4202d7b3`. The connected sword cave `t011_sword_cave` still passes **1117/1117 KEY ticks** on the shortcut build, full-RAM ratchet new 0/earlier 0/improved 13. The short Q2 overworld consumer `q2_ow` passed **60/60 KEY ticks** on the earlier cave-audio/routing build, ratchet new 0/earlier 0/improved 11. This carries prior connected behavior without a broad cave re-sweep.

## Remaining work

Use the safe BizHawk runner for one representative of each unaccepted cave behavior. Compare NES and Genesis, including accepted and rejected purchase/requirement cases where applicable. Check shortcut source-room rotation, Q2 connected entrance changes, one-time flags after leave/re-enter and SRAM reopen. Fix only reproduced differences. Do not rerun the historical 20-cave static sweep unless a shared renderer change invalidates it; its legacy launchers kill all EmuHawk processes on timeout and are unsafe for the user's session.
