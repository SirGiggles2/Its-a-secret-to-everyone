/* nes_ram_sync.c — see nes_ram_sync.h for full task-header docs. */

#include "nes_ram_sync.h"
#include "platform_abi.h"          /* nes_ram[] */
#include "inventory.h"             /* g_inventory */
#include "player_state.h"          /* players[0] */
#include "joy.h"                   /* SGDK BUTTON_* */

/* NES Z_07 ReadInputs bit layout (Variables.inc ButtonsPressed=$FA,
 * ButtonsDown=$FB). */
#define NES_BTN_A       0x80u
#define NES_BTN_B       0x40u
#define NES_BTN_SELECT  0x20u
#define NES_BTN_START   0x10u
#define NES_BTN_UP      0x08u
#define NES_BTN_DOWN    0x04u
#define NES_BTN_LEFT    0x02u
#define NES_BTN_RIGHT   0x01u

/* Variables.inc:74-75 (NES Z1):
 *   ButtonsPressed := $F8   (edge — set on 0->1 transition this frame)
 *   ButtonsDown    := $FA   (held — 1 while button is down)
 * Plan v5 listed these as $FA/$FB which contradicts both Variables.inc
 * and the transpiled src/zelda_translated/z_07.asm:124-125 declarations.
 * Drain (asm) primary, plan secondary — use $F8/$FA. */
#define NES_RAM_BUTTONS_PRESSED   0x00F8u
#define NES_RAM_BUTTONS_DOWN      0x00FAu
#define NES_RAM_HEART_VALUES      0x066Fu
#define NES_RAM_HEART_PARTIAL     0x0670u
#define NES_RAM_OBJDIR_LINK       0x008Cu

static unsigned char sgdk_to_nes_buttons(u16 joy)
{
    unsigned char n = 0u;
    if (joy & BUTTON_A)     n |= NES_BTN_A;
    if (joy & BUTTON_B)     n |= NES_BTN_B;
    /* Genesis pad has no Select. C is the closest analogue (third
     * face button); Z1 Select only opens the pause menu, which on
     * Genesis is reachable via Start anyway. Wiring C->Select keeps
     * the NES side aware of C presses in case a future native consumer
     * binds to Select. */
    if (joy & BUTTON_C)     n |= NES_BTN_SELECT;
    if (joy & BUTTON_START) n |= NES_BTN_START;
    if (joy & BUTTON_UP)    n |= NES_BTN_UP;
    if (joy & BUTTON_DOWN)  n |= NES_BTN_DOWN;
    if (joy & BUTTON_LEFT)  n |= NES_BTN_LEFT;
    if (joy & BUTTON_RIGHT) n |= NES_BTN_RIGHT;
    return n;
}

void nes_ram_sync_input(u16 held, u16 edge_pressed)
{
    nes_ram[NES_RAM_BUTTONS_PRESSED] = sgdk_to_nes_buttons(edge_pressed);
    nes_ram[NES_RAM_BUTTONS_DOWN]    = sgdk_to_nes_buttons(held);
}

void nes_ram_sync_inventory_hearts(void)
{
    nes_ram[NES_RAM_HEART_VALUES]  = g_inventory.heart_values;
    nes_ram[NES_RAM_HEART_PARTIAL] = g_inventory.heart_partial;
}

void nes_ram_sync_link_face(void)
{
    nes_ram[NES_RAM_OBJDIR_LINK] = (unsigned char)players[0].face;
}
