# Audio Link Engineering Plan (resolves task_10_3_audio_link_into_debug_md)

**Status:** SCOPED — Phase 11 follow-up task; not active this commit.
**Date:** 2026-05-14
**Owner:** unassigned (next contributor on Phase 11 audio track).

## Problem

`src/audio_driver.asm` (1337 LOC YM2612 + PSG NES-APU emulator) +
`data/audio/songs.c` / `sfx*.c` / `pcm_samples.c` +
`src/sgdk_adapter/audio_adapter.c` are NOT linked into `Debug.md`.

`tools/debug/build_debug.py` uses `m68k-elf-gcc` invoking gas as its
assembler. `audio_driver.asm` uses **vasm Motorola syntax** which is
not directly compatible with gas — even in MRI mode (`-Wa,--mri`).

## Empirical failure modes (gas MRI on `audio_driver.asm`)

Test invocation:
```
gcc -m68000 -x assembler-with-cpp \
    -Wa,--register-prefix-optional,--bitwise-or,--mri \
    -Isrc -c src/audio_driver.asm
```

Errors observed:

1. **`include "data/music_blob.inc"`** — gas resolves relative paths
   from project root; the file lives at `src/data/music_blob.inc`.
   Adding `-Isrc` lets the include resolve, but `incbin
   "data/music_blob.dat"` (line 1332) is then path-broken because
   `incbin` does not respect `-I` paths in MRI mode.

2. **Local label re-use** — vasm scopes `.wait`, `.done`, `.read` per
   function; gas MRI uses file-global label scope. Three label
   collisions surfaced at audio_driver.asm:110 / 668 / 994.

3. **Short-branch range** — multiple `bra.s` / `beq.s` / `bcc.s`
   sites compute >127 byte offsets in gas's first-pass linker layout
   (`audio_driver.asm:656 / 663 / 666 / 1002`). vasm runs multi-pass
   over short branches and silently relaxes to long; gas MRI does
   not.

4. **`xdef` / `xref`** — pure vasm directives; gas MRI accepts them
   only with `--mri`, and even then only inside the MRI body. Already
   in MRI mode but still produce export/import metadata issues.

5. **63 `name equ value`** statements — gas MRI accepts the bare
   `equ` form; this works.

## Translation plan (estimated 4-8 hour focused task)

1. **Path fix.** Change `include "data/music_blob.inc"` →
   `include "music_blob.inc"`; pre-pend `incbin "data/music_blob.dat"`
   path resolution by either:
     - moving `music_blob.dat` into the asm sibling dir, or
     - patching to `incbin "src/data/music_blob.dat"`.

2. **Label scope.** Rename per-function `.wait` / `.done` / `.read`
   to `routine_wait_N` / `routine_done_N` / `routine_read_N` with a
   short suffix per parent function (≈30 sites).

3. **Branch sizing.** Replace `bra.s` / `beq.s` / `bcc.s` with the
   long form `bra` / `beq` / `bcc` at the 4 over-range sites; let the
   assembler pick the encoding.

4. **Build integration.** Add `compile_asm_mri` helper to
   `tools/debug/build_debug.py` that wraps the gas invocation with
   `-Wa,--mri`. Add an `AUDIO_C_SOURCES` list:
     - `src/sgdk_adapter/audio_adapter.c`
     - `data/audio/songs.c`
     - `data/audio/song_scripts.c`
     - `data/audio/sfx.c`
     - `data/audio/sfx_pcm.c`
     - `data/audio/pcm_samples.c`
   and an `AUDIO_ASM_SOURCES` list:
     - `src/audio_driver.asm` (via `compile_asm_mri`).

5. **Linker symbols.** Verify `music_play` / `music_tick` resolve in
   the link step. Add `-u music_play` if `--gc-sections` strips them.

6. **VBlank hook.** `src/genesis_shell.asm` already calls
   `music_tick`; ensure that file links into Debug.md (currently
   absent — Title-frontend era linked it).

7. **First-light test.** `Debug.bat`; if green, poke
   `SongRequest = $80` via probe Lua and screenshot title song
   playback (per memory `project_midi_substrate_works`).

8. **Phase 10.5 probe pass.** Implement 5 audio probes specced in
   `docs/audit/drain_findings/phase10_task_10_5.md`.

## Acceptance gate

- `Debug.bat` green with audio TUs linked.
- `probe_fs_silent_or_explicit_song` passes (FS routing parity per
  Task 10.1.2).
- `audio_event_log_music` + `audio_event_log_sfx` pass.
- VBlank budget probe under cycle ceiling.

## Risk

Medium. Translation is mechanical but multi-pass branch sizing +
label scope cleanup are error-prone. The driver is functional in vasm
form (memory `project_midi_substrate_works`); the risk is the
*translation step*, not the driver itself.

## Why deferred this commit

Phase 11 master-plan focus = Title.md frontend gap-fill + regression
probes (Tasks 11.1-11.4). Audio link is orthogonal engineering work
that ships better as a focused PR with its own probe pass + listening
check. Rolling it into Phase 11 close would either rush the
translation or stall the frontend probes. Recording it as a scoped
follow-up preserves both axes.
