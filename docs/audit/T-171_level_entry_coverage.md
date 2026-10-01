# T-171 Q1 L3–L9 entry coverage

Build: Windows `Debug.bat` PASS, `builds/Debug.md` SHA-256
`AF6A028838AD6D50FC9AE06951D79B55247BFB281C7C4472CC8E85B960E41DBA`.
Reference: NES ROM lockstep captures and generated
`RoomRom/data/levelinfo_start_rooms.c` start-room data.

New presets: `tools/lockstep/presets/t171_warp_l3.json` through
`t171_warp_l9.json`. Each stages `CurLevel=N`, `IsUpdatingMode=0`,
`GameMode=2`, `GameSubmode=0` at tick 50 and runs 480 play ticks. This uses
the existing L2 warp method; it does not inject progress after entry.

| Level | Start room | New gate | Key frames | Baseline cells |
|---|---:|---|---:|---:|
| 3 | 0x7C | PASS | 480/480 | 67 |
| 4 | 0x71 | PASS | 480/480 | 67 |
| 5 | 0x76 | PASS | 480/480 | 67 |
| 6 | 0x79 | PASS | 480/480 | 67 |
| 7 | 0x79 | PASS | 480/480 | 67 |
| 8 | 0x7E | PASS | 480/480 | 67 |
| 9 | 0x76 | PASS | 480/480 | 67 |

Verification: `python tools/lockstep/run_suite.py t171-level-entry-gated
--jobs 4 --only t171_warp_l3 ... t171_warp_l9` returned 7/7 PASS. Each
new diff-cell set is identical and contained within the existing L2 entry
baseline; 65 cells begin at bootstrap tick 0, and sprite flicker cells
`$0341/$0342` begin at tick 1. Representative L3, L7 and L9 final NES and
Genesis frames were inspected for layout. This is entry-state coverage,
not boss, full dungeon, connected progression or pixel-perfect acceptance.

Remaining: stage real boss-room loading, inspect rendered bosses and attacks,
then trace any new mismatches to their onset and NES source. Keep T-171 ACTIVE.
