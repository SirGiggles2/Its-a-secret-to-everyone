probe_save_persistence — Tue Aug  4 22:16:32 2026
work domain: M68K BUS   cart domain: SRAM
gameplay ready at frame: 281
GameMode after save poke: $05 (want $05)

Items fingerprint (first 8 of 40): FF 10 02 01 02 00 01 02 
SRAM slot0 pre-reset  (first 10): 5A A5 FF 10 02 01 02 00 01 02 
SRAM slot0 post-reset (first 10): 5A A5 FF 10 02 01 02 00 01 02 

  gameplay reached                           OK
  Mode $0D returned to Play ($05)            OK
  cart SRAM has magic BEFORE reset           OK
  cart SRAM Items match live BEFORE reset    OK
  core rebooted                              OK
  cart SRAM has magic AFTER reset            OK
  cart SRAM Items match AFTER reset          OK

VERDICT: PASS — 7/7
A save is only real if the two AFTER-reset checks pass.
