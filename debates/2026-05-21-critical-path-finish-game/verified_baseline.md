# Verified Baseline — Session 2026-05-21

Live probes against HEAD `builds/Debug.md` (commit `528b1898`, 2.0M ROM).

All probes used `nesram(off) = memory.read_u8(0x8000 + off, "68K RAM")` per `platform_abi.h:14-21` (Debug.md A4 = `$FF8000`, NOT `$FF0000`).

## Verified working (live probe evidence)

| Subsystem | Evidence |
|---|---|
| Boot | a4_probe_main.c title state @ frame 0 |
| Title → gameplay | A+B+C chord transitions COMBINED_STATE_TITLE → COMBINED_STATE_ROOMROM |
| GameMode dispatch | `$FF8012` = $05 (Mode 5 Play) all 500f post-chord |
| FrameCounter | $FF8015 cycling 0..$FF (NMI sync working) |
| OW render | r$77 trees+sand+path correct; cave entrance visible top-center |
| Link movement | XY responsive (X 120→200, Y 141→181 per D-pad) |
| Room scroll | r$77 → r$67 on Up screen-edge cross |
| OW enemy spawn | r$67 = 3 Octorok type $07 (with hp/x/y populated) |
| Cave entry trigger | Walk onto entrance tile → SCENE_CAVE transition fires |
| Cave palette | PAL0 sub2/3 swapped to cave colors |
| MODE button toggle | SCENE_OW ↔ SCENE_UW (per main.c:2152) |
| UW L1 entry | scn=$01 lvl=$01 rm=$73 song=$40 SONG_UW |
| UW dungeon render | L1 entrance blue walls + 12-statue grid + doors visible |
| UW room transition | r$73 → r$63 on Up door |
| UW enemy spawn | r$63 = 6 Goriya type $2A, hp=$20 |
| Sword swing | Beam projectile fires in face direction |
| Sword damage | Enemy hp 20→10→00 in 2 hits; killed enemy removed from slot |
| Collision buffer | $6530+ all 352 tiles populated post-load_room |
| Audio dispatch | `audio_dispatch_tick` writes m_song correctly: $80 title, $01 OW, $40 UW |
| Pause toggle | bare-Start freezes input + gameplay tick |
| Regression matrix | 11/11 GREEN (title/intro/FS binary baselines) |

## Phantom blockers refuted via Rule Zero probes

| Tracker claim | Reality | Refuting evidence |
|---|---|---|
| GameMode $0C park | Title sentinel $CD; chord not pressed | Probe at correct $FF8000+$12 shows $05 post-chord |
| Mode 5 Play port required | Decomposed into roomrom_debug_tick handlers | mode_dispatch_update($05) → stub OK because tick body owns subsystems |
| T0.4 PlayAreaTiles broken | Published every load_room (main.c:605) | 352/352 non-zero tiles in $6530-$67DA at frame 500 |
| T5.0 audio FS routing RED | Wrong-cell probe (read $0608 instead of `m_song_req` at $FFE001) | m_song advances $80→$01 correctly post-chord |

## Real remaining blockers

### Blocker #1: L1 r$63 cannot exit to north
- Room $63 cleared (6 Goriya killed) but north/east/west exits don't open
- A+B+C+START shutter trigger no effect (chord may not register OR room not shutter type)
- B key-door touch no effect
- B+Z+C bomb chord no effect
- Need: extract `LevelBlock AttrsA/AttrsB` for L1 r$63 from `data/rooms/dungeons.c` to decode door types per `door_state.h:22-29`

### Blocker #2: Cave interior render partial (Task #44)
- Cave entry warp FIRES but interior shows blob sprite + no NPC + wrong palette
- Plan v6: `Z_01.asm` InitCave column override + cave-person sprite + text streamer pending

### Blocker #3: Gameplay scenarios absent from regression matrix
- Matrix covers 11 title/intro/FS binary baselines only
- Add: post-chord-gameplay, cave-warp, UW-enter, sword-swing baselines

## Probe scripts (in C:\tmp\, candidate for repo commit)

| Script | Purpose | Time |
|---|---|---|
| probe_gameplay_state.lua | post-chord state + collision dump | ~30s |
| probe_full_gameplay.lua | walk + sword + enemy slots | ~50s |
| probe_audio_diag.lua | m_song_req / m_song / xgm_owns trace | ~15s |
| probe_cave_entry_v2.lua | cave entrance warp | ~30s |
| probe_uw_v2.lua | MODE toggle UW entry | ~40s |
| probe_uw_combat.lua | per-slot MON_HP trace during sword | ~50s |
| probe_l1_advance.lua | r$63 clear + north door attempt | ~3min |
| probe_l1_shutter.lua | r$63 shutter/key/bomb door tests | ~3min |

## Next concrete action (per /primedirective)

1. Extract L1 r$63 LevelBlock AttrsA/AttrsB from `data/rooms/dungeons.c`
2. Decode door type per `door_state.h:22-29` for each direction
3. If shutter: verify `uw_door_state_trigger_shutters()` actually fires (probe sentinel)
4. If key door: verify B-button touch logic via uw_door_state_touch()
5. If wall: r$63 layout in this build differs from NES Q1 — verify rooms_dungeons offset

Or alternatively: add `roomrom_debug_ghost_mode` toggle (pass-through walls) to enable scripted L1-L9 traversal without per-room door investigation.
