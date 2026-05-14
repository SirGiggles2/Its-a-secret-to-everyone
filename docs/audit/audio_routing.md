# Audio Routing Decision (Task 10.1.2 — BLOCKING for 10.3)

**Status:** LOCKED — gamemode-keyed routing.
**Date:** 2026-05-14
**Authority:** Master plan Task 10.1.2 default ruling + memory
`project_fs_no_song_change`.

## Ruling

File-select audio is keyed on `gamemode == 0x01` (`Mode_FileSelect`),
**NOT** off the title bitmap.

## Rationale

Memory `project_fs_no_song_change` recorded the bug: `InitMode1`
(FileSelect entry) does not write `SongRequest`, so the title song
(`$80`) bleeds through every FS scene because the audio driver keeps
playing whatever was last requested. Without an explicit routing
decision, Phase 10.3 would wire music events on bitmap transitions,
which means title song stays audible during all of file select.

NES Zelda 1 file select is silent. The routing key is the gamemode
cell, which transitions deterministically as:

```
$01 FileSelect → $02 RegisterName → $03 Elimination → $04 LoadLevel
                                                       → $05 GameMode_Play
```

The audio routing layer reads `gamemode` (NES `$12`) and dispatches
a song request per the table below. This is independent of which
tilemap or which CHR bank is loaded; it is the gameplay-mode state
machine that drives audio, not the renderer.

## Routing table

| gamemode | mode label         | SongRequest               |
|----------|--------------------|---------------------------|
| `$00`    | Demo / title       | Title song (`$80`)        |
| `$01`    | FileSelect         | Silence (`$00`)           |
| `$02`    | RegisterName       | Silence (`$00`)           |
| `$03`    | Elimination        | Silence (`$00`)           |
| `$04`    | LoadLevel          | (transient — last song)   |
| `$05`    | GameMode_Play (OW) | Overworld song            |
| `$05` UW | GameMode_Play (UW) | Per-level dungeon song    |
| `$06`    | GameOver           | Death dirge               |
| `$07`    | Dying              | (death-sequence music)    |
| `$08`    | ContinueQuestion   | Silence                   |
| Cave     | (UW caves)         | Cave song                 |
| Ending   | Ending             | Ending music              |

OW vs UW resolution under `$05` reads `CUR_LEVEL` (NES `$10`); level
0 = OW; level 1..9 = UW with per-level song id.

## Redux options interaction

`OPTION_ID_DUNGEON_MUSIC_VARIANT` (Task 9.4 deferral) routes through
this layer: when set, the UW song lookup goes through an alternate
table. This is the only Redux option that touches Phase 10.3 music
events; all other options (low-health warning, AB swap, etc.) are
gameplay-side gates and are not audio-routing concerns.

## Probe specification

`tools/debug/probe_fs_silent_or_explicit_song.lua` (Phase 10.3
implementation work):

1. Boot Debug.md; advance to title; press Start.
2. Wait for `gamemode == 0x01` (FS entry).
3. Capture `SongRequest` ($88 in NES RAM mirror; address per
   `Variables.inc`).
4. Assert: `SongRequest` equals the FS song id from the table above
   (either silence `$00` or an explicit FS song; NOT the title id
   `$80`).
5. PASS if routing matches the table; FAIL on bleed.

## Status

CLOSE — Task 10.1.2 FS audio routing LOCKED. Task 10.3 (Wire Music
Events) no longer blocked. Probe spec recorded; probe implementation
is Phase 10.3 implementation work.
