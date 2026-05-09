#include "roomrom_link_damage.h"
#include "inventory.h"

/* ObjInvincibilityTimer mirror — Link is slot 0. NES Z_07.asm:5757 reads
 * `ObjInvincibilityTimer, X` with X=0; we hold a single byte. */
static unsigned char s_invincibility_timer = 0u;

#define ROOMROM_INVINCIBILITY_INITIAL 0x10u  /* NES post-harm scaffold */

void roomrom_link_damage_init(void)
{
    s_invincibility_timer = 0u;
}

unsigned char roomrom_link_damage_invincible(void)
{
    return (unsigned char)(s_invincibility_timer != 0u);
}

unsigned char roomrom_link_damage_dead(void)
{
    return (unsigned char)((g_inventory.heart_values & 0x0Fu) == 0u
                            && g_inventory.heart_partial == 0u);
}

/* NES Z_07.asm:5756 DecrementInvincibilityTimer:
 *   if timer == 0: return
 *   if (FrameCounter LSR) carry: return   ; only decrement on even frames
 *   DEC ObjInvincibilityTimer
 */
void roomrom_link_damage_tick(unsigned char frame_counter)
{
    if (s_invincibility_timer == 0u) return;
    if ((frame_counter & 1u) != 0u) return;  /* odd frame, skip */
    s_invincibility_timer--;
}

/* NES Z_01.asm:5691 Link_BeHarmed — entry receives [0D] hi / [0E] lo
 * damage; loops `LSR $0D / ROR $0E` per ring level (InvRing 0/1/2). */
static void apply_ring_divide(unsigned char *dmg_hi, unsigned char *dmg_lo)
{
    unsigned char rings = g_inventory.ring;
    while (rings != 0u) {
        unsigned char carry = (unsigned char)(*dmg_hi & 1u);
        *dmg_hi = (unsigned char)(*dmg_hi >> 1);
        *dmg_lo = (unsigned char)((*dmg_lo >> 1) | (carry ? 0x80u : 0u));
        rings--;
    }
}

unsigned char roomrom_link_damage_apply(unsigned char dmg_hi,
                                        unsigned char dmg_lo)
{
    if (s_invincibility_timer != 0u) return 0u;     /* already invincible */
    if (g_inventory.clock != 0u) return 0u;         /* clock freezes harm */

    apply_ring_divide(&dmg_hi, &dmg_lo);

    /* NES Z_01.asm:5718-5754 — subtract low byte from HeartPartial; if
     * HeartPartial < dmg_lo, borrow one full heart and recompute. */
    if (g_inventory.heart_partial >= dmg_lo) {
        g_inventory.heart_partial = (unsigned char)(g_inventory.heart_partial - dmg_lo);
    } else {
        unsigned char need = (unsigned char)(dmg_lo - g_inventory.heart_partial);
        unsigned char full = (unsigned char)(g_inventory.heart_values & 0x0Fu);
        if (full == 0u) {
            /* Can't borrow — Link dies. */
            g_inventory.heart_values =
                (unsigned char)(g_inventory.heart_values & 0xF0u);
            g_inventory.heart_partial = 0u;
            return 1u;
        }
        full--;
        g_inventory.heart_values =
            (unsigned char)((g_inventory.heart_values & 0xF0u) | full);
        /* NES quirk Z_01.asm:5742-5743: partial wraps to $FF, not $100. */
        g_inventory.heart_partial = (unsigned char)(0xFFu - need);
        dmg_hi = (unsigned char)0;  /* low-byte borrow consumed; high byte stays */
    }

    /* Now subtract dmg_hi full hearts. */
    {
        unsigned char full = (unsigned char)(g_inventory.heart_values & 0x0Fu);
        if (full < dmg_hi) {
            g_inventory.heart_values =
                (unsigned char)(g_inventory.heart_values & 0xF0u);
            g_inventory.heart_partial = 0u;
            return 1u;
        }
        full = (unsigned char)(full - dmg_hi);
        g_inventory.heart_values =
            (unsigned char)((g_inventory.heart_values & 0xF0u) | full);
    }

    s_invincibility_timer = ROOMROM_INVINCIBILITY_INITIAL;
    return 0u;
}
