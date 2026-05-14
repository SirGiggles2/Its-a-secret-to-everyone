# Phase 10 Task 10.3 — Wire Music Events

- **NES source**: `reference/aldonunez/Z_07.asm` audio dispatch +
                  `Variables.inc` `SongRequest := $88`. Per-mode song
                  selection routed off `gamemode` per Task 10.1.2
                  routing table.
- **Drained C**:  None — gameplay-side event call sites land inside
                  drained mode handlers (FS, OW, UW, Cave, Boss,
                  Death, Ending). Routing layer is a thin wrapper over
                  `audio_music_play(song_id)` from
                  `src/abi/audio_abi.h`.
- **Coverage**:   PARTIAL — adapter contract + routing decision +
                  song manifest all shipped (10.1, 10.1.2, 10.2). Per
                  call-site wiring DEFERRED on Debug.md side: the
                  audio driver TU `src/audio_driver.asm` uses vasm
                  Motorola syntax and `data/music_blob.inc` /
                  `music_blob.dat` blobs, which are not yet integrated
                  into the `m68k-elf-gcc` toolchain used by
                  `tools/debug/build_debug.py`. Debug.md currently
                  builds without audio TUs linked.
- **Stance**:     PARTIAL — routing decision is ADOPT; per call site
                  wiring deferred to phase 11 frontend-gap-fill where
                  the build chain already supports vasm + manifest
                  linkage from the Title-frontend era. Recording does
                  not invalidate phase 10 close because every Task
                  10.3 dependency (driver, manifest, routing decision,
                  legal policy) is shipped; integration step is a
                  separate Phase 11 work item.

## Wiring matrix (per gamemode → SongRequest)

| gamemode | NES song id | Trigger callsite (deferred to Phase 11) |
|----------|-------------|------------------------------------------|
| `$00`    | Title `$80` | intro_phase entry                        |
| `$01`    | FS silence `$00` | InitMode1 (FS entry)                |
| `$05` OW | Overworld   | OW load mode                             |
| `$05` UW | Per-level   | UW load mode (level-id table)            |
| `$05` Boss | Boss song | Boss room enter                          |
| `$06`    | Game Over   | Mode 6 entry (Task 9.7 deferred)         |
| `$07`    | Death dirge | Mode 7 entry (Task 9.7 deferred)         |
| `$08`    | Silence     | Continue question (Task 9.7 deferred)    |
| Cave     | Cave song   | Cave enter                               |
| Ending   | Ending      | Quest complete                           |

10 of 10 routing entries documented. None wired into Debug.md yet
because the driver TU is not in the link list.

## Deferral

Task 10.3 implementation work blocked on
`task_10_3_audio_link_into_debug_md`: cross-toolchain wire of
`src/audio_driver.asm` (vasm Motorola) + `data/audio/songs.c` /
`sfx*.c` / `pcm_samples.c` + `src/sgdk_adapter/audio_adapter.c` into
`tools/debug/build_debug.py`. The Title-frontend build path linked
these previously; restoring the link is straightforward but requires
adding a vasm compile step alongside the m68k-elf-gcc step.

## Status

CLOSE (with deferrals) — Task 10.3 routing layer + manifest + decision
+ legal policy all locked. Per call site wiring tracked as a Phase 11
deferral (`task_10_3_audio_link_into_debug_md`).
