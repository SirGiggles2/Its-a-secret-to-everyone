# $3D Aquamentus

- **NES source**: reference/aldonunez/Z_04.asm:5596 UpdateAquamentus
- **Drained C**:  src/oracle/enemies/enemy_boss_runtime.c:110 enrt_update_aquamentus
- **Coverage**:   FULL
- **Stance**:     PARTIAL (B6.1 fix)

Behavior: InvClock-gated Aquamentus_Move + Aquamentus_Shoot, then
Aquamentus_Draw, CheckMonsterCollisions, PlayBossHitCryIfNeeded.
**B6.1 fix added**: enrt_play_boss_death_cry_if_needed +
c_reset_shove_info at tail per NES CheckBossHitReaction (Z_04.asm:5605).
Triple-shot fireball $55 boss. INIT sets INVINCIBILITY=$E2 (arrow/fire
allowed only), SFX_BOSS_CRY=16, X=$B0, Y=$80.
