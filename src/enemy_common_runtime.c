#include "enemy_runtime_private.h"

void enrt_hide_sprites_over_link(void) {
    ENEMY_OAM_HIDE_0 = 0xF8;
    ENEMY_OAM_HIDE_1 = 0xF8;
}

void enrt_play_secret_found_tune(void) {
    ENEMY_SFX_SECRET = 4;
}

void enrt_play_boss_death_cry(void) {
    ENEMY_SFX_BOSS_CRY = 2;
    ENEMY_SFX_BOSS_CRY_FLAGS = 0x80;
}

void enrt_gohma_play_parry_tune(void) {
    ENEMY_SFX_PARRY = 1;
}
