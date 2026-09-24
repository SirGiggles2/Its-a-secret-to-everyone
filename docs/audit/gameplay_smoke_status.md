probe_gameplay_smoke — Tue Aug  4 21:44:55 2026
domain: M68K BUS  cram: CRAM  vram: VRAM
gameplay state ready at frame: 280
domains exposed: CRAM, M68K BUS, MD CART, SRAM, VRAM, VSRAM, Waterbox PageData, Z80 RAM

step            mode room    x    y face   hp
01_title        $CD  $00  $00  $00  $00  $00
02_gameplay     $05  $77  $78  $8D  $00  $FF
03_walk_right   $05  $77  $C8  $8D  $00  $FF
04_walk_up      $05  $77  $C8  $7D  $00  $FF
05_sword        $05  $77  $C8  $7D  $00  $FF
06_settle       $05  $77  $C8  $7D  $00  $FF

CRAM non-zero bytes (of 128): 52   (palette init only, NOT a render claim)
SAT render check: UNKNOWN (no VDP-register domain exposed)

  entered gameplay (GameMode $05)          OK
  Link has hearts (HeartValues != 0)       OK
  Link moved on Right                      OK
  Link moved on Up                         OK
  still in Play at end                     OK
  CRAM populated (palette init only)       OK

VERDICT: PASS — 6/6 smoke checks pass
Scope: engine runs/moves/renders. NOT a NES-correctness claim.
