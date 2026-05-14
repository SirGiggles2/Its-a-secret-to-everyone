# Phase 10 Task 10.2 — Builder Audio Extraction

- **NES source**: NES Zelda 1 ROM `prg.bin` — song table, song
                  headers, song scripts, envelope tables, length
                  tables, SFX, DPCM/DMC samples. Authoritative offsets
                  per `reference/aldonunez/Z_07.asm` audio dispatch.
- **Drained C**:  None — extraction is a builder-tool path
                  (`tools/extract_audio.py`), not a runtime body.
                  Output is generated C blobs at `data/audio/songs.c`,
                  `data/audio/sfx*.c`, `data/audio/pcm_samples.c`, plus
                  `data/audio/MANIFEST.json` and
                  `src/data/music_blob.{inc,dat}`.
- **Coverage**:   FULL — all NES audio categories extracted:
                    - Song table (1 entry) + 22 song headers.
                    - Song scripts (`song_scripts.c`, 161 LOC).
                    - SFX table (8 SFX) + DPCM samples (1 PCM blob,
                      580 LOC C).
                    - SFX PCM table (`sfx_pcm.c`, 3730 LOC).
                    - Music blob (`music_blob.dat`, 2757 bytes;
                      `music_blob.inc` declares `MUSIC_BLOB_NES_BASE =
                      $8D60`).
- **Stance**:     ADOPT — extractor pipeline shipped per Phase 1.5
                  builder track; manifest is authoritative source of
                  truth for audio asset count + offsets.

## Manifest (`data/audio/MANIFEST.json`)

| Bucket | Count |
|--------|-------|
| Songs  | 23    |
| SFX    | 8     |
| PCM    | 1     |

NES ROM sha256 pinned at top of manifest. Builder refuses to extract
if ROM hash drifts.

## Generated artifacts

| Artifact                       | LOC / bytes | Generator entry                  |
|--------------------------------|-------------|----------------------------------|
| `data/audio/songs.c`           | 49 / 718 B  | `write_songs_file`               |
| `data/audio/song_scripts.c`    | 161         | `write_song_scripts_file`        |
| `data/audio/sfx.c`             | 10          | `write_sfx_file`                 |
| `data/audio/sfx_pcm.c`         | 3730        | `write_sfx_pcm_file`             |
| `data/audio/pcm_samples.c`     | 580         | `write_pcm_samples_file`         |
| `data/audio/MANIFEST.json`     | —           | `write_manifest`                 |
| `src/data/music_blob.dat`      | 2757 B      | `write_music_blob_files`         |
| `src/data/music_blob.inc`      | 180 B       | `write_music_blob_files`         |

## Build verification

Builder pipeline runs out-of-band (extracts once from user's ROM).
Debug.md build does not currently link the generated audio TUs — that
gap is Task 10.3 integration work, not Task 10.2 extraction. Files
above are present in tree and freshness-stable.

## Status

CLOSE — Task 10.2 extraction complete. All 6 master-plan categories
(title, OW, dungeon, cave/item/ending, SFX, manifest) extracted +
manifest committed. Package check enforced at
`tools/builder/package_check.py` per Task 10.1.1 legal policy.
