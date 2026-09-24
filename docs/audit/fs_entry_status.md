probe_fs_entry — Tue Aug  4 22:53:23 2026
domain: M68K BUS
gameplay ready at frame: 135

step             marker mode room slot
01_title         $00  $CD  $00  $00
02_after_start   $00  $CD  $00  $00
03_after_select  $CC  $05  $00  $00
04_gameplay      $CC  $05  $77  $00

  title reached (GameMode $CD sentinel)  OK
  File Select entered (fs_phase valid)   OK
  handoff marker set ($CC)               OK
  gameplay room populated                OK
  GameMode is Play ($05)                 OK

VERDICT: PASS — 5/5
Scope: control flow only. Not a rendering or NES-parity claim.
