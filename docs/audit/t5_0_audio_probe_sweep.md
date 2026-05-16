# T5.0 audio probe sweep — Plan v5a step 2

**Date:** 2026-05-16
**ROM:** `builds/Debug.md` (post cave-palette swap commit)
**Source plan:** `~/.claude/plans/put-this-into-your-virtual-wall.md` v5a step 2

## Per-probe results (initial pre-fix sweep)

| # | Probe | Verdict | Notes |
|---|-------|---------|-------|
| 1 | `probe_audio_vblank_budget.lua`     | **GREEN**   | 300/300 frames @ ~59.94 fps; `music_tick` fits VBlank budget |
| 2 | `probe_audio_event_log_music.lua`   | **PARTIAL** | gamemode reported 0x0C (probe BSS-read garbage — superseded). SongRequest=0x00 the entire 1500-frame walk. |
| 3 | `probe_audio_event_log_sfx.lua`     | **PARTIAL** | 68 BSS cell changes in $E000..$E1FF sweep. Probe sweep noisy. |
| 4 | `probe_audio_low_health_option.lua` | **PARTIAL** | SRAM uninitialised (magic=0x0000 instead of 'OP'). |
| 5 | `probe_fs_silent_or_explicit_song.lua` | **RED**  | gamemode never reaches FS ($01) within 500 frames after pressing Start. |

## Addendum 2026-05-16 — ROOT CAUSE FOUND (commit 24d7be11)

The PARTIAL/RED results above were symptoms of a single ABI bug, not multiple subsystem failures.

### Root cause: `music_play` calling convention mismatch

`src/audio_driver.asm:614 music_play` was declared with NES asm convention
(`D0.b = song bitmap`) but called from C (`src/debug/a4_probe_main.c:181
music_play(0x80)`). GCC m68k compiled the constant-arg call as:

```
pea     #$80      ; push immediate to stack
jsr     music_play
```

`pea` does NOT load D0 — only pushes the immediate to the stack. The asm
`music_play` then stored whatever D0 contained (the prior C function's
return value) to `m_song_req`.

`audio_dispatch_tick`'s call worked by accident because GCC's pattern for
variable args is `moveb d2,d0; movel d0,sp@-` — D0 gets loaded
incidentally before the push.

### Evidence — pre-fix trace (`probe_audio_deep_trace_v2.lua`)

```
fr= 39 gm=CD m_song=00 m_req=00 m_phrase=00    ← probe_check sentinel hits = main loop entered
fr= 50 gm=CD m_song=00 m_req=01 m_phrase=00    ← music_play(0x80) stored D0=$01 (=intro_phase_step return) instead of $80
fr= 51 gm=CD m_song=01 m_req=00 m_phrase=09    ← change_song.first_ow → play_next_phrase.next_ow
```

m_song NEVER becomes $80. The title song never reaches the driver.

### Evidence — post-fix trace (same probe)

```
fr= 50 gm=CD m_song=00 m_req=80 m_phrase=00    ← music_play(0x80) correctly writes $80
fr= 51 gm=CD m_song=80 m_req=00 m_phrase=1A    ← change_song.first_demo (m_phrase=$19) → next_demo ($1A)
fr= 52+ gm=CD m_song=80 m_req=00 m_phrase=1A   ← driver looping title song phrases
```

### Fix

```asm
music_play:
    move.b  7(SP),D0                  ; arg byte at SP+4+3 (big-endian m68k stack)
    move.b  D0,(m_song_req).l
    rts
```

Matches the documented GCC m68k convention used by `dmc_trigger:603`
("GCC m68k ABI: arg in stack").

## Re-sweep findings (post-fix, commit 24d7be11)

| # | Probe | Verdict | Notes |
|---|-------|---------|-------|
| 1 | `probe_audio_vblank_budget.lua`         | **GREEN**   | 300/300 frames @ 59.94 fps, `music_tick` fits VBlank |
| 2 | `probe_audio_event_log_music.lua`       | **GREEN**   | 3 transitions captured; `m_song=$80` from frame 51 onwards |
| 3 | `probe_audio_event_log_sfx.lua`         | **RED-expected** | dmc_last_idx never written in 1500 frames. Boot parks at gm=$CD (probe_check sentinel); no combat → no SFX path fires. Verifies the cell isn't spuriously written. Real SFX coverage needs chord-gated debug entry + scripted combat probe. |
| 4 | `probe_audio_low_health_option.lua`     | **PARTIAL** | SRAM uninitialised in debug ROM (pre-existing structural; not music_play-related) |
| 5 | `probe_fs_silent_or_explicit_song.lua`  | **RED**     | gamemode never reaches FS ($01) — debug harness bypasses FS path (probe_check writes $CD sentinel, then debug_enter_title direct entry). Structural to debug ROM, not routing bug. Real FS routing parity test needs non-debug ROM or FS-entry chord. |

Post-fix evidence summary:
- music_play(0x80) correctly writes $80 to m_song_req.
- change_song.first_demo path activates (m_phrase=$19 → next_demo $1A).
- Driver loops title song phrases stable from frame 52+.
- VBlank budget unaffected (no perf regression).

## Diagnostic findings — SUPERSEDED

The "gamemode stuck at $0C" finding was probe BSS-read garbage. After
audit, the gm cell ($FF8012) reads $CD once `probe_check(1)` runs at fr 39
as a sentinel — A4-readback verification, not a real game-mode value. The
"audio dispatcher never fires" finding holds — `audio_dispatch_tick` is
chord-gated and probes don't press the chord — but the underlying boot
title song now works through the direct `music_play(0x80)` call.

## Coverage / Stance (D1)

- **NES source**: reference/aldonunez/Z_07.asm (multiple SongRequest writers) + audio_driver.asm calling convention
- **Drained C** : src/audio_driver.asm music_play (asm sole writer) + src/game/audio/audio_dispatch.c (gamemode dispatch)
- **Coverage**  : FULL after fix (music_play correctly stores arg byte; title song reaches driver at boot)
- **Stance**    : EXTEND — diagnostic record + ABI fix landed commit 24d7be11
