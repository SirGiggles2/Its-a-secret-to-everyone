# $53..$5A MonsterShot family

- **NES source**: reference/aldonunez/Z_04.asm:820 UpdateMonsterShot
- **Drained C**:  src/oracle/enemies/enemy_projectile_runtime.c:229 enrt_update_monster_shot
- **Coverage**:   FULL
- **Stance**:     ADOPT

Types: $53 FlyingRock (octorok), $54 Unknown54, $55/$56 Fireball
($55/$56 dispatch to enrt_update_fireball instead), $57 SwordShot,
$58 MagicShot, $59 / $5A shot variants.

Behavior: state $10 fly → tile collide (for $53/$54), bound check,
move, Link collide, draw via L_DrawShot path. Other state → enrt_bounce_shot
($30 shield bounce + dist counter saturation destroy at $20).
Init seeds WALK_SPEED=$C0 ($53/$55/$56/$57/$58/$59/$5A) or $E0 ($54).
