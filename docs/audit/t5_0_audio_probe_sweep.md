# T5.0 audio probe sweep — Plan v5a step 2

**Date:** 2026-05-16
**ROM:** `builds/Debug.md` (post cave-palette swap commit)
**Source plan:** `~/.claude/plans/put-this-into-your-virtual-wall.md` v5a step 2

## Per-probe results

| # | Probe | Verdict | Notes |
|---|-------|---------|-------|
| 1 | `probe_audio_vblank_budget.lua`     | **GREEN**   | 300/300 frames completed @ ~59.94 fps; `music_tick` fits VBlank budget |
| 2 | `probe_audio_event_log_music.lua`   | **PARTIAL** | gamemode=0x00 at frame 1 → 0x0C at frame 13 → static. SongRequest=0x00 the entire 1500-frame walk. No `music_play()` ever fires via `nes_ram[$88]` mirror. |
| 3 | `probe_audio_event_log_sfx.lua`     | **PARTIAL** | 68 BSS cell changes detected in $E000..$E1FF sweep — likely music-driver channel state (SQ1/SQ2/NOISE update bytes), NOT `dmc_last_idx`. Probe sweep noisy; need driver `.l` symbol address to disambiguate. |
| 4 | `probe_audio_low_health_option.lua` | **PARTIAL** | SRAM uninitialised (magic=0x0000 instead of 'OP'). Accessor surface healthy; needs a save write to verify bit-decode. |
| 5 | `probe_fs_silent_or_explicit_song.lua` | **RED**  | gamemode never reaches FS ($01) within 500 frames after pressing Start; stays at 0x0C. SongRequest=0x00 throughout. |

## Diagnostic findings

1. **Gamemode is stuck at $0C** across both passive (probe 2) and Start-press (probe 5) walks. NES Z1 mode $0C is in the UpdateMode5Play variant range ($09..$0C per `src/game/audio/audio_dispatch.c:37`) — the autoenter or NES-shim boot path is parking gamemode there instead of advancing the normal Demo($00) → FileSelect($01) → Play($05) chain.

2. **Audio dispatcher never fires** because:
   - `audio_dispatch_tick()` is only called from `roomrom_debug_tick` (`RoomRom/src/main.c:1840`), which runs after `roomrom_debug_enter`.
   - Probes 2/5 do not press the A+B+C+Start debug-enter chord, so `audio_dispatch_tick` never executes.
   - Even if it did, `resolve_song()` has no case for gm=$0C — it falls through `default:` returning `s_last_song` (sentinel $FF), suppressing `music_play()`.

3. **Title song trigger at boot (`a4_probe_main.c:181`) is NOT visible in the SongRequest mirror.** Either:
   - the call uses driver BSS `m_song` and never mirrors to `nes_ram[$88]`, OR
   - the call is wired but executes before BizHawk's RAM probe can read it (unlikely — probe samples per-frame).

4. **SFX probe sweep proves the driver BSS is alive** (channel-state bytes mutate every ~60 frames matching driver tick). Music infrastructure works; the dispatch path is what's silent.

## Decision per plan v5a step 2

> "Outcome decides scope: if all GREEN → audio is fine, skip T5.1-T5.4. If RED → fix only the failing call-sites."

**Not all GREEN.** Scope T5.1 + T5.2 + T5.5 (+ T5.3 + T5.4 subsets) remain valid for v5b session.

**Pre-T5.1 architectural fix needed first** (added to plan):

- **T5.0.1** — Investigate why gamemode parks at $0C instead of advancing through normal Demo/FS/Play chain. Likely the debug-enter substrate or `a4_probe_main.c` boot path forces this. Resolve before any T5.1 dispatch wiring — otherwise the dispatcher will continue to no-op.
- **T5.0.2** — Find `dmc_last_idx` `.l` absolute symbol address from linker map. Update `probe_audio_event_log_sfx.lua` to read that single cell, eliminating sweep noise.
- **T5.0.3** — Decide: mirror `m_song` writes to `nes_ram[$88]` so audio routing decisions are observable via the standard NES cell, OR update probes to read driver BSS via map-derived address.

## Coverage / Stance (D1)

- **NES source**: reference/aldonunez/Z_07.asm (multiple SongRequest writers)
- **Drained C** : src/game/audio/audio_dispatch.c (Plan v5b T5.5)
- **Coverage**  : NONE (audio dispatch logic exists; boot path doesn't reach it)
- **Stance**    : EXTEND — diagnostic record (no code change in T5.0 itself; T5.0.1-T5.0.3 fixes drop in v5b)
