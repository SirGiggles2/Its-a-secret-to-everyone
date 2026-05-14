# Release Guide — FINAL TRY

NES Zelda 1 (1986) ported to Sega Genesis / Mega Drive.

This doc covers user-facing instructions for building the final
ROM from your own legally-acquired NES Zelda 1 ROM file.

---

## Legal note

You must supply your own NES Zelda 1 ROM. This project ships builder
code and adapter logic only. Generated Nintendo-derived assets
(CHR, room layouts, song data, SFX) are extracted from YOUR ROM on
YOUR local machine at build time.

Legal model: same as CHR extraction. The user owns the ROM, therefore
the user owns the extracted bytes. Public release tarballs ship the
builder pipeline, NOT the extracted artifacts.

See `docs/audit/audio_legal_policy.md` for the canonical ruling.

---

## Supported ROM

| Variant | sha256 |
|---------|--------|
| PRG0 (USA) | `8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac` |

Verify your ROM's hash before building:

```bash
sha256sum your-rom.nes
```

If your ROM is not in the supported list, the builder will reject
it. Open a ticket with the hash if you have a verified dump that
should be supported.

---

## Build instructions

### Prerequisites

- Python 3.10+
- SGDK toolchain at `build/toolchain/sgdk_bin/` (gcc + objcopy for
  m68k-elf).
- Windows host (build scripts are .bat). Linux/Mac users adapt to
  the equivalent Python entrypoints.

Toolchain check:

```bash
python tools/builder/build.py --check-toolchain
```

### One-shot build

```bash
python tools/builder/build.py path/to/your/zelda1.nes
```

Pipeline:

1. Validates ROM sha256 against pinned list.
2. Runs extractors (audio + CHR + room blobs) into local cache.
3. Invokes `Debug.bat` → `builds/Debug.md`.

Final ROM lands at `builds/Debug.md`.

### Skip-extract rebuild

If the extractor cache is already populated and you only changed C
or asm source code:

```bash
python tools/builder/build.py path/to/your/zelda1.nes --skip-extract
```

Or just run `Debug.bat` directly.

---

## Run on emulator

Tested on:
- BizHawk 2.11 with Genesis Plus GX core (primary dev target).
- BlastEm (cross-emulator deferred to Phase 16.3).
- Genesis Plus GX standalone (cross-emulator deferred).

Drop `builds/Debug.md` into the emulator. Boot directly into a debug
gameplay room.

---

## Redux options

The OPTIONS file-select submenu exposes accessibility + difficulty
toggles. Defaults match NES-faithful behaviour; flip any toggle to
opt into Redux modifications.

See `src/game/options/options_state.h` for the canonical option ID
list. Live wiring status per option tracked at
`docs/audit/drain_findings/phase9_task_9_4.md`.

---

## Troubleshooting

- **ROM hash mismatch** → confirm you have a legit PRG0 dump.
- **Toolchain missing** → unpack SGDK at
  `build/toolchain/sgdk_bin/` per project README.
- **Build green but ROM silent** → audio link is currently a Phase
  11 deferral (`task_10_3_audio_link_into_debug_md`); audio plays in
  the prior Title-frontend build path but not yet linked into the
  `Debug.md` sole-target ROM.
- **Phase tracker says STALE** → run `python
  tools/audit/primedirective/prime_refresh.py`.

---

## Reproducibility verification

To prove your build is deterministic byte-for-byte against a clean
clone:

```bash
python tools/builder/from_scratch_gate.py path/to/your/zelda1.nes
```

Builds twice from a clean cache; byte-compares the two final ROMs;
fails if they differ.

---

## Contributor guide

DO NOT COMMIT generated Nintendo-derived assets. The CI hook at
`tools/builder/package_check.py` blocks any commit that adds files
under:

- `data/chr/*`, `data/rooms/*`, `data/redux/*`, `RoomRom/data/*`
- `data/audio/songs.c` / `sfx*.c` / `pcm_samples.c`
- `src/data/music_blob.*`
- Atlas data files in `RoomRom/src/atlas/`
- `.nes` / `.sfc` / `.smc` files

Run before commit:

```bash
python tools/builder/package_check.py
```

---

## Phase status (2026-05-14)

- Master plan ladder Phases 0–17 close-gate STATUS=complete.
- Critical-path deferrals open: audio link (Phase 10), dungeon
  harness population (Phase 14), death/continue modes (Phase 9.7),
  hardware verification (Phase 16.2).
- Per-deferral status tracked in
  `docs/superpowers/prime_directive_tracker.json` deferrals array.

---

## Verification

For each contributor PR, the following CI gates run:

```bash
Debug.bat                                           # builds Debug.md
python tools/run_regression_matrix.py               # 8 frontend probes
python tools/gates/check_banned_filename.py         # banned-alias gate
python tools/audit/check_incremental_promotion.py   # RoomRom promotion gate
python tools/builder/package_check.py               # release-package gate
```

All must exit zero for merge.
