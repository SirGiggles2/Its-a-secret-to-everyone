# WHAT IF Builds

## Current outputs

- `builds/whatif.md` - latest built Genesis ROM
- `builds/whatif.lst` - latest assembly listing
- `builds/archive/Px.y.*` - archived ROM/listing/metadata sets for successful phase-tagged builds

## Current Phase 3 state

The current ROM now boots into a recognizable Zelda 1 opening screen for overworld room `$77`, with the corrected overworld scenery tiles from the fixed bank-3 CHR seam, placeholder movement restored, and smooth room transitions in all four directions.

What the current scene does:

- uploads extracted Zelda overworld/background tiles
- uploads the corrected gameplay CRAM layout
- decodes the real room `$77` from extracted overworld room data
- fills Plane A from the decoded room buffer
- draws a placeholder Link sprite with corrected common-sprite bank ordering and tuned gameplay colors
- draws the placeholder Link slightly lower on the playfield to better match the NES reference
- allows placeholder movement with the D-pad
- scrolls into the adjacent overworld room when the placeholder Link crosses any screen edge

What is still intentionally not back on:

- cave entry behavior
- real HUD rendering

## Latest build

- Latest archived Phase 3 build: `builds/archive/P3.46.md`
- Latest archived listing: `builds/archive/P3.46.lst`
- Latest checksum: `$3782`

## Build pipeline

1. `build.bat` runs the extraction pipeline
2. `build.bat` assembles `src/main.asm` with vasm
3. `tools/fix_checksum.py` writes the Genesis header checksum
4. `tools/check_phase0_integrity.py` validates VDP registers and CRAM presence
5. If `PHASE_ARCHIVE` is set, `tools/archive_phase_build.py` saves the successful build as `builds/archive/Px.y.*`

## Emulator probes

Generic launcher:

- `tools/launch_bizhawk.ps1`

Current Phase 3 probes:

- Boot probe:
  - `tools/bizhawk_boot_probe.lua`
  - `tools/run_bizhawk_boot_probe.bat`
- Room probe:
  - `tools/bizhawk_phase3_room_probe.lua`
  - `tools/run_bizhawk_phase3_room_probe.bat`
- Room-fidelity probe:
  - `tools/bizhawk_phase3_room_fidelity_probe.lua`
  - `tools/check_room_fidelity.py`
  - `tools/run_bizhawk_phase3_room_fidelity_probe.bat`
- Navigation probe:
  - `tools/bizhawk_phase3_navigation_probe.lua`
  - `tools/run_bizhawk_phase3_navigation_probe.bat`
- Left navigation probe:
  - `tools/bizhawk_phase3_left_navigation_probe.lua`
  - `tools/run_bizhawk_phase3_left_navigation_probe.bat`
- Up navigation probe:
  - `tools/bizhawk_phase3_up_navigation_probe.lua`
  - `tools/run_bizhawk_phase3_up_navigation_probe.bat`
- Down navigation probe:
  - `tools/bizhawk_phase3_down_navigation_probe.lua`
  - `tools/run_bizhawk_phase3_down_navigation_probe.bat`
- NES reference capture:
  - `tools/bizhawk_nes_start_capture.lua`
  - `tools/dump_nes_start_bg.lua`
  - `tools/compare_nes_start_room.py`
- Capture/debug helpers:
  - `tools/bizhawk_list_domains.lua`
  - `tools/bizhawk_capture_frame.lua`
  - `tools/bizhawk_vdp_probe.lua`
  - `tools/bizhawk_room_dump.lua`

## Current verification state

- Build: pass
- Checksum fix: pass
- Phase 0 integrity: pass
- BizHawk boot probe: pass
- BizHawk room probe: pass
- BizHawk room-fidelity probe: pass
- BizHawk navigation probe: pass (`$77 -> $78`, smooth settle)
- BizHawk left navigation probe: pass (`$77 -> $76`, smooth settle)
- BizHawk up navigation probe: pass (`$77 -> $67`, smooth settle)
- BizHawk down navigation probe: pass (`$67 -> $77`, smooth settle)
- NES-vs-reference room compare: pass (`Mismatch count: 0`)
- Live NES CHR-RAM dump: verified against extracted common BG, overworld BG, and common misc blocks

## Archived Phase 3 builds

Current archived Phase 3 sequence:

- `archive/P3.1.*` through `archive/P3.46.*`
