# tools/nes_capture — NES Reference Capture Harness

**Master plan Phase 1.5 — Task 1.5.1 through 1.5.4**
**Debate 002 Tier-1 GREEN path**

## Purpose

Single source of NES truth for every later phase parity diff.

Every "compare against NES" task in Phases 3+ consumes artifacts produced
here.  No phase reinvents its own capture; all parity claims cite a
`build/generated/nes_reference/<rom_hash>/<scenario_id>/manifest.json`
artifact SHA-256.

## Inputs

| Input | Description |
|-------|-------------|
| User-supplied NES Zelda 1 ROM | Placed at `roms/zelda1.nes` (or passed via `--rom`). Never committed. |
| `captures.json` | Canonical scenario manifest — checked into this repo. |
| Save states / input movies | Optional per-scenario; paths stored in `captures.json`. |
| BizHawk with NES core | `EmuHawk.exe` on PATH or at `BIZHAWK_ROOT`. |

The ROM SHA-256 must match one of the hashes in the supported list below.
`run_capture.py` refuses to proceed on unknown hashes.

### Supported ROM Hashes (SHA-256)

```
# Legend of Zelda, The (U) (PRG0) [!]
b3ed9f9b3c56a7e44ad6a8abf37ea9e4ba8fe3f79d0e1a9e1b3d1726f88a6f3d

# Legend of Zelda, The (U) (PRG1)
9c2ed7c9e0c49c1ebe39bbe3f0cce28ddefd5a7da7b3e48c8a1a25de3b3f9c6f
```

> **Note:** At scaffolding time these are placeholder hashes.  Replace with
> the real SHA-256 of your legal dump before running.  The tool will tell you
> the actual hash of the ROM you supply so you can update this list.

## Outputs

```
build/generated/nes_reference/
  <rom_sha256_prefix8>/
    <scenario_id>/
      screenshot.png      BizHawk rendered frame
      ppu.bin             PPU register snapshot (8 bytes, $2000–$2007)
      oam.bin             OAM buffer (256 bytes)
      palram.bin          Palette RAM ($3F00–$3F1F, 32 bytes)
      ciram.bin           Name tables ($2000–$2FFF, 4096 bytes)
      ram.bin             CPU RAM ($0000–$07FF, 2048 bytes)
      frame.txt           Frame counter (decimal)
      input_log.txt       Per-frame joypad bitmasks up to target frame
      rng_seed.txt        Injected or observed RNG seed (hex u16)
      manifest.json       SHA-256 of every artifact + metadata
```

`build/` is gitignored; captures live on disk only.

## How to Add a New Scenario

1. Edit `captures.json` and add an entry with all required fields (see Schema
   below).
2. Set `"starting_save_state"` to a path relative to the repo root, or `null`
   if a cold-boot + input movie is sufficient.
3. Set `"input_movie"` to a BizHawk `.bk2` path, or `null` for static scenes.
4. Set `"target_frame"` to the frame number at which to capture.
5. Run `python tools/nes_capture/run_capture.py --scenario <your_id>`.
6. Commit `captures.json`; the output bundle stays gitignored.

### captures.json Field Reference

```json
{
  "id":                 "unique_snake_case_id",
  "title":              "Human-readable description",
  "source_rom_hash":    "sha256 hex string or null (null = any supported)",
  "starting_save_state":"path/to/state.State or null",
  "input_movie":        "path/to/movie.bk2 or null",
  "target_frame":       1234,
  "rng_seed":           0xABCD,
  "expected_room_id":   0x77,
  "capture_artifacts":  ["screenshot.png", "ppu.bin", "oam.bin",
                         "palram.bin", "ciram.bin", "ram.bin",
                         "frame.txt", "input_log.txt", "rng_seed.txt"]
}
```

`rng_seed` and `expected_room_id` may be `null`.
`capture_artifacts` defaults to the full list if omitted.

## Quickstart

```bat
REM 1. Place your legal Zelda 1 dump at:
REM    C:\path\to\repo\roms\zelda1.nes

REM 2. Ensure BizHawk is installed.  Set BIZHAWK_ROOT if not on PATH:
set BIZHAWK_ROOT=C:\BizHawk

REM 3. Run all scenarios:
python tools/nes_capture/run_capture.py --rom roms/zelda1.nes

REM 4. Verify a previous capture is still deterministic:
python tools/nes_capture/verify_capture.py

REM 5. Run a single scenario:
python tools/nes_capture/run_capture.py --rom roms/zelda1.nes --scenario title_idle
```

## Integration with Task 1.11 Strict Build Gate

`tools/builder/strict_build_check.py` prints a reminder when captures are
missing but does **not** call `verify_capture.py` automatically yet.

Phase 1.5.3 wires the verifier.  The integration point is the block at the
bottom of `strict_build_check.py`'s `main()`:

```python
# --- Phase 1.5 NES capture verification gate ---
# When Phase 1.5 is complete, add here:
#
#   import subprocess, sys
#   result = subprocess.run(
#       [sys.executable, "tools/nes_capture/verify_capture.py"],
#       cwd=str(REPO_ROOT)
#   )
#   if result.returncode != 0:
#       all_fails.append(("NES Capture", "verify_capture.py returned non-zero"))
#
# Until then, a reminder is printed when the harness directory exists.
```

The next phase that touches the strict gate should uncomment this block.

## Memory Rules Observed

- `feedback_one_big_probe`: all artifacts bundled in a single BizHawk launch.
- `feedback_bizhawk_lua_env`: `BIZHAWK_ROOT` must be set; the Lua script
  sources `main` relative to that root.
- `feedback_check_dont_guess`: NES ROM dump is the ground-truth source;
  nothing in this tool guesses at tile or palette values.
- `feedback_nes_feel_genesis_native`: outputs of this harness are the NES
  ground-truth that Genesis implementations must match.
