# Audio Legal Policy (Task 10.1.1 — BLOCKING for 10.2)

**Status:** LOCKED — CHR-model rule adopted.
**Date:** 2026-05-14
**Authority:** Master plan Task 10.1.1 default ruling.

## Ruling

NES audio sequence + pattern tables (square-wave sequences, envelope
tables, length tables, pattern data) extracted from the
user-supplied NES Zelda 1 ROM follow the **same legal model as CHR
graphics data**:

1. The user owns the legitimately-acquired NES Zelda 1 ROM.
2. Therefore the user owns the audio bytes inside that ROM, exactly
   as they own the CHR / room / palette bytes.
3. Our builder produces the extraction **locally on the user's
   machine** at build time from their ROM — it is not redistributed
   as a separate artifact.
4. Public release bundles ship the *builder code*, not the *extracted
   audio data*. The extracted `data/audio/songs.c` / `sfx*.c` /
   `pcm_samples.c` artifacts are downstream of the user's ROM and
   stay on the user's disk.

This mirrors the existing precedent for CHR extraction, which is
already governed under the same model and which has shipped since
Phase 1.

## Categorization

| Category                     | Treatment                                |
|------------------------------|------------------------------------------|
| NES sequence tables          | Extracted-as-is from user ROM            |
| NES envelope / length tables | Extracted-as-is from user ROM            |
| NES DPCM / DMC samples       | Extracted-as-is; format-converted only   |
| Authored Genesis FM patches  | Project-owned (Sonic 2 EHZ-derived FM voice mapping is interpretation, not data) |
| Driver code (`audio_driver.asm`) | Project-owned (Genesis-native emulation of the APU contract) |

The DMC / DPCM samples are byte-faithful extracts from the user's ROM
at the source level; format conversion (rate / quantization to the
Genesis YM2612 + Z80 sample bus) is necessary to play them on Genesis
hardware and is mechanical translation, not creative authorship.

## Fallback path (if challenged)

If the CHR-model ruling is challenged for audio specifically:

- Replace extracted NES sequences with authored Genesis-native music
  scored to the same gameplay events.
- Replace extracted DMC samples with authored Genesis-native PCM.
- Driver code is untouched (it is a Genesis-native APU emulator and
  already project-owned).
- Manifest stays stable; the *contents* change but the song-id table
  and SFX dispatcher do not.

The fallback is a release-blocker only if the primary ruling is
formally challenged. Until then, default ruling stands.

## Builder enforcement

`tools/builder/package_check.py` is updated to:

- Refuse to ship any binary audio file in the public release bundle
  that is NOT generated from the user ROM at build time.
- Allow the builder source / manifest / driver code through.
- Allow authored Genesis FM patches through.

Implementation note: the gate lives behind the package step that
emits the release tarball. Local development builds (`Debug.bat`)
proceed normally — the gate fires only when packaging for public
release.

## Status

CLOSE — Task 10.1.1 legal policy LOCKED. Task 10.2 (Builder Audio
Extraction) no longer blocked.
