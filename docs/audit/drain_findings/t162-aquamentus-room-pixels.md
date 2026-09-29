# T-162 Aquamentus room wall and doorway pixels (2026-09-29)

- **NES source**: live NES L1 room `$35` nametable 0, BG CHR and PALRAM, captured from the connected controller route at ticks 8200 and 8227.
- **Drained C**: linked `src/game/dungeon/uw_render.c`/background atlas path; no code change in this task.
- **Coverage**: PARTIAL (settled boss-room background art and palette, including static wall and doorway tiles; opening/scroll animation is separate).
- **Stance**: VERIFY against current output, preserving the old user report as history.

Earlier `verify_plane.py` showed 704/704 NES tile/sub-palette cells mapped to Genesis plane A, but did not check pixels inside those tiles. `tools/lockstep/verify_aquamentus_room_pixels.py` compares each NES BG CHR pixel and its live PALRAM color to the corresponding Genesis tile pixel and CRAM word, also checking transparency. It uses the measured room mapping: NES NT0 rows 8–29 to Genesis plane A at row offset 47. This checks the full 32×22 playfield, including the wall and doorway, without mixing in sprites or the separately owned HUD/window.

On `builds/Debug.md` SHA-256 `9cf38246cf8b9c0c6ecc6da2d22d04aff3035a047df183c97e212e6d8fec1ed4`, both tick **8200** (Aquamentus alive) and **8227** (death effect) passed **704/704 cells and 45,056/45,056 background pixels exact** against live NES captures in `builds/reports/lockstep/t013_boss_visual_astra_20260929`. Commands: `python tools/lockstep/verify_aquamentus_room_pixels.py builds/reports/lockstep/t013_boss_visual_astra_20260929 8200` and the same with `8227`. The connected route at this build matched 9,065/9,065 KEY ticks; its full-RAM diagnostic has no baseline and is not claimed passing.

No current static wall/door pixel defect was reproduced. Door opening, collision and scroll animation remain governed by their own P5/T-119/T-131/T-153 evidence; this check does not accept them.
