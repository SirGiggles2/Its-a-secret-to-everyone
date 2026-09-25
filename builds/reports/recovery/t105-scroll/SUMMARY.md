# T-105 OW room scroll (Astra's implementation) — evidence

Astra's uncommitted T-105 work (`src/game/world/ow_scroll.c/.h`, `RoomRom/src/main.c`
hunks, presets, `verify_scroll.py`) was preserved first as branch
`astra/t105-wip` (bced3fce), then committed to main by Claude on user instruction
after verification on the merged tree (main + T-110/T-050/T-115/T-114):

- `verify_scroll.py` (nine state fields, leave/scroll/enter + 24 ticks):
  t105_scroll PASS, t105_horizontal PASS, t105_return PASS (2 crossings);
  0 differing cells each.
- Lag frames per crossing: NES 2, Genesis 3 (was ~11 on Genesis before).
- Regression on the same ROM: t050 layout/tree/wall/rock_push/pond_fairy and
  t114_uw_wall plane 704/704 exact; t110_fire weapon cells PASS (0 cells —
  Link now takes the fire hit on the NES tick); t110_bomb unchanged (2 T-102 cells).
