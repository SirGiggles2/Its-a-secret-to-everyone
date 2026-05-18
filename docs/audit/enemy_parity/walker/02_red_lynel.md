# $02 RedLynel

- **NES source**: reference/aldonunez/Z_04.asm:1965 UpdateLynel
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:243 enrt_update_lynel
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: Goriya AI + sword shot ($57) at qspeed=$20. Red Lynel gated
by B1.1 rng check (Random+slot >= $F8 OR ShootTimer != 0).
Verified live: WTS=$01 but SHT=$00 throughout 240-frame probe.
