# Phase 10 Task 10.1.2 — FS Audio Routing Decision (BLOCKING for 10.3)

- **NES source**: `reference/aldonunez/Z_05.asm` `InitMode1`
                  (FileSelect mode-1 entry — does NOT write
                  `SongRequest`, so the prior song bleeds through;
                  memory `project_fs_no_song_change`).
                  `Variables.inc` `gamemode := $12`.
- **Drained C**:  None — routing is a Phase 10 wiring decision, not
                  drained C. Pre-existing memory record drives the
                  ruling.
- **Coverage**:   FULL (decision) — explicit routing table covers
                  every gameplay mode (`$00`-`$08`, OW, UW, Cave,
                  Ending).
- **Stance**:     ADOPT — gamemode-keyed routing per
                  `docs/audit/audio_routing.md`. NES Zelda 1 FS is
                  silent; mirror exactly.

## Decision

Locked in `docs/audit/audio_routing.md`. FS music keyed off
`gamemode == 0x01`, NOT off the title bitmap. Routing table covers
every mode; Redux `OPTION_ID_DUNGEON_MUSIC_VARIANT` (Task 9.4
deferral) is the only Redux option that interacts with this layer.

## Probe specification

`tools/debug/probe_fs_silent_or_explicit_song.lua` (spec written;
implementation gated by Task 10.3 audio integration into Debug.md):

1. Boot Debug.md → title → press Start.
2. Wait `gamemode == 0x01` (FS).
3. Capture `SongRequest` in NES RAM mirror.
4. Assert: matches FS song id from routing table (silence `$00` or
   explicit FS song; NOT title `$80`).

## Unblocks

Task 10.3 (Wire Music Events) — previously BLOCKING.

## Status

CLOSE — Task 10.1.2 FS routing LOCKED. Task 10.3 unblocked.
