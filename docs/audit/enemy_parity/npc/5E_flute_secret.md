# $5E FluteSecret

- **NES source**: reference/aldonunez/Z_07.asm:5817 InitFluteSecret
- **Drained C**:  src/game/core/core_dispatch.c core_init_flute_secret
- **Coverage**:   ADOPT
- **Stance**:     ADOPT

Behavior: flute-revealed secret marker. Spawned when Link plays Recorder
in flute-secret rooms (OW). INIT-only — no UPDATE row needed (static
spawn marker). Wired commit 158c908b.
