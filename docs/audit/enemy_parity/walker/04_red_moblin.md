# $04 RedMoblin

- **NES source**: reference/aldonunez/Z_04.asm:1956 UpdateMoblin
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:234 enrt_update_moblin
- **Coverage**:   PARTIAL
- **Stance**:     ADOPT

Behavior: turn rate $A0, Wanderer_TargetPlayer, arrow shot ($5B) at
qspeed=$20. Red Moblin gated by B1.1 rng check.
Verified live: WTS=$01 sometimes but SHT=$00 throughout 240-frame probe.
The short probe ended before a natural shot. A 600-frame normal-room BizHawk
run in overworld room `$4B` loaded six type `$04` Moblins; the first `$5B`
arrow appeared at frame 364, moved across consecutive frames, cleared at
frame 427, and another appeared at frame 434. Evidence:
`builds/reports/recovery/red-moblin-natural-arrow-20260923/result.json`.
NES-aligned firing probability, movement, art, collision and death/drop
parity remain open.
