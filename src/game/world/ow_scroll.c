/* NES source: Z_07 CheckScreenEdge, UpdateMode4and6EnterLeave;
 * Z_05 InitMode6, InitMode7Submodes, UpdateMode7ScrollSubmode, ScrollWorld.
 * Drained C: src/oracle/room/room_mode_runtime.c (mode boundaries/sub2/6/7),
 * room_load_runtime.c (entry/reset); native room_dispatch.c counterparts.
 * Coverage: PARTIAL (native OW sequencing and camera/Link displacement).
 * Stance: EXTEND. Rendering stays behind the existing host/adapter boundary.
 * NES PPU transfers become preparation ticks; their byte addresses are not
 * Genesis VDP addresses. No new gameplay state is stored in renderer slots.
 */
#include "ow_scroll.h"
#include "platform_abi.h"

#define UPD nes_ram[0x11u]
#define MODE nes_ram[0x12u]
#define SUB nes_ram[0x13u]
#define ROW nes_ram[0xE9u]

static unsigned char direction;
static unsigned char target_room;
static unsigned char column;
static unsigned short pixels;

unsigned char ow_scroll_edge(short x, short y, unsigned char dir,
                             signed char grid, unsigned char room)
{
    if (grid != 0) return 0u;
    /* Z_07 PlayerScreenEdgeBounds. Test BEFORE a step, at equality. */
    if (dir == 1u && x == 0xF0) return (room & 15u) < 15u ? 1u : 0x80u;
    if (dir == 2u && x == 0) return (room & 15u) > 0u ? 2u : 0x80u;
    if (dir == 4u && y == 0xDD) return room < 0x70u ? 3u : 0x80u;
    if (dir == 8u && y == 0x3D) return room >= 0x10u ? 4u : 0x80u;
    return 0u;
}

void ow_scroll_begin(unsigned char dir, unsigned char target)
{
    direction = dir;
    target_room = target;
    pixels = 0u;
    column = 0xFFu;
    MODE = 6u;
    SUB = UPD = 0u;
    nes_ram[0x394u] = 0u;
    /* CheckScreenEdge publishes the chosen direction before mode 6.
     * In particular, reversing at the arrival edge must not leave the
     * previous crossing's direction in the room-entry/spawn consumers. */
    nes_ram[0x98u] = dir < 3u ? dir : (dir == 3u ? 4u : 8u);
    nes_ram[0xACu] = nes_ram[0xC0u] = nes_ram[0xD3u] = 0u;
    nes_ram[0x4F0u] = 0u;
}

unsigned char ow_scroll_column(void) { return column; }
unsigned short ow_scroll_pixels(void) { return pixels; }

unsigned char ow_scroll_tick(short *x, short *y)
{
    column = 0xFFu;
    if (MODE == 6u) {
        if (!UPD) {
            unsigned char i;
            nes_ram[0x66Cu] = 0u; /* InvClock: ResetPlayerState */
            nes_ram[0x64u] = 0u;  /* LadderSlot */
            for (i = 13u; i < 19u; ++i) nes_ram[0xACu + i] = 0u;
            UPD = 1u;
        } else {
            MODE = 7u;
            SUB = UPD = 0u;
        }
    } else if (MODE == 7u && !UPD) {
        switch (SUB) {
        case 0u: SUB = 1u; break;
        case 1u:
            nes_ram[0xECu] = target_room;
            ROW = 21u;
            SUB = 2u;
            break;
        case 2u:
            /* NES transfers all 22 rows before scrolling. Use that budget
             * to stage the native room incrementally (16 metatile columns). */
            if (ROW >= 6u) column = (unsigned char)(21u - ROW);
            if (ROW-- == 0u) SUB = 3u;
            break;
        case 3u: case 4u: ++SUB; break;
        default:
            nes_ram[0xEBu] = target_room;
            SUB = 0u;
            UPD = 1u;
            break;
        }
    } else if (MODE == 7u) {
        switch (SUB) {
        case 0u:
            SUB = direction == 4u ? 1u : 2u;
            ROW = direction == 4u ? 22u : 0xFFu;
            break;
        case 1u: SUB = 2u; break;
        case 2u:
            nes_ram[0xE6u] = (unsigned char)((nes_ram[0x15u] + 1u) & 1u);
            SUB = 3u;
            break;
        case 3u:
            if (direction < 3u) {
                pixels += 4u;
                if (direction == 1u && *x > 0) *x -= 4;
                if (direction == 2u && *x < 0xF0) *x += 4;
                if (pixels == 256u) SUB = 4u;
            } else if ((nes_ram[0x15u] & 1u) == nes_ram[0xE6u]) {
                if (direction == 4u) {
                    if (*y < 0xDD) *y += 8;
                    /* Up has a final row-underflow tick with no camera move. */
                    if (ROW-- == 0u) SUB = 4u;
                } else {
                    if (*y >= 0x3E) *y -= 8;
                    if (++ROW == 21u) SUB = 4u;
                }
                if (pixels < 176u) pixels += 8u;
            }
            if (SUB == 4u) ROW = nes_ram[0xEDu] = 0xFFu;
            break;
        case 4u: SUB = direction == 4u ? 6u : 5u; break;
        case 5u: SUB = 6u; break;
        default: MODE = 4u; SUB = 1u; UPD = 0u; break;
        }
    } else if (MODE == 4u) {
        if (SUB == 1u) SUB = 2u;
        else if (SUB == 2u) SUB = 0u;
        else if (!UPD) {
            nes_ram[0x394u] = nes_ram[0x3A8u] = 0u;
            UPD = 1u;
        } else { MODE = 5u; SUB = UPD = 0u; }
    } else if (MODE == 5u) {
        UPD = 1u;
        return 1u;
    }
    nes_ram[0x70u] = (unsigned char)*x;
    nes_ram[0x84u] = (unsigned char)*y;
    return 0u;
}
