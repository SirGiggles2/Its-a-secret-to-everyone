probe_levelinfo_install — Tue Aug  4 20:06:51 2026
domain: M68K BUS  bus_base: $FF0000
GameMode $0012 = $05   CurLevel $0010 = $00
LevelNumber $6BB1 = $08  -> validating against L8 row
usable_observation: true  (requires GameMode $05 AND LevelNumber in 1..9)

LevelInfo fields installed at NES SRAM:
  StartRoomId     $6BAD  got $7E          want $7E  OK
  TriforceRoomId  $6BAE  got $2C          want $2C  OK
  BossRoomId      $6BBC  got $3C          want $3C  OK
  SubmenuMapRot   $6BAB  got $0A          want $0A  OK

VERDICT: PASS — 4/4 fields match live-NES-SRAM values
