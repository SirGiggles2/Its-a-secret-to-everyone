/* cave_dispatch.c — native cave gamemode entry (debate 006 D2).
 *
 * Native rewrite of src/oracle/cave/cave_runtime.c init/dispatch
 * surface. Pure C, no transpile-bridge shims. Both ROMs link.
 *
 * NES reference: reference/aldonunez/Z_01.asm InitCave (line 69) +
 * InitCaveContinue (line 105) + UpdateCavePerson (line 300).
 * Verified MATCH per Gate 1 findings 3_2, 3_2b.
 *
 * NES vars (reference/aldonunez/Variables.inc):
 *   ObjType+1   = $0350  (CAVE_ROOM_TYPE)
 *   PersonState = $00AD  (CAVE_PERSON_STATE)
 *   CaveFlags   = $0413  (CAVE_FLAGS)
 *   PersonTextSelector = $0415 (CAVE_TEXT_SELECTOR)
 *
 * Scope (this commit):
 *   cave_init  — populate CaveState typed struct from cave_id; upload
 *                cave palette via render adapter. NO transpile shim
 *                calls (z01_set_up_common_cave_objects et al deferred).
 *   cave_tick  — stub (real NPC/shop logic ports per-function later).
 *   cave_exit  — clears CaveState + bumps generation.
 */

#include "cave_dispatch.h"
#include "cave_state.h"
#include "combat_state.h"               /* LINK_HEARTS = RAM(0x066F) */
#include "world/progress_dispatch.h"    /* progress_set_room_flag_uw_item_state */
#include "world/sprite_dispatch.h"      /* sprite_anim_fetch_obj_pos */
#include "world/draw_dispatch.h"        /* draw_object_mirrored,
                                         * draw_object_not_mirrored */
#include "core/core_dispatch.h"         /* core_cue_transfer_buf_and_advance_state,
                                         * core_abs, core_unhalt_link */
#include "items/item_dispatch.h"        /* item_take_item */

/* Asm-bound data tables (no banned prefix). */
extern const unsigned char PersonTextAddrs[];

/* NES Z_01.asm:559 TextboxCharTransferRecTemplate — 5-byte VRAM
 * transfer record template used by the textbox char-streamer to
 * stamp a single character tile into nametable. Per NES asm:
 *   $21       VRAM addr hi byte (nametable $2100 + offset)
 *   $A4       VRAM addr lo byte (textbox line 0 start)
 *   $01       record length (one byte)
 *   $24       default char (space = $24)
 *   $FF       terminator
 * Char byte at offset 3 is overwritten per-frame with the streamed
 * character. Offset 1 (lo addr) is overwritten per-line from
 * TextboxLineAddrsLo. */
const unsigned char TextboxCharTransferRecTemplate[5] = {
    0x21u, 0xA4u, 0x01u, 0x24u, 0xFFu
};

/* Cave-id of the currently active cave (0 = none active).
 *
 * The persistent cave state lives in NES RAM (read/written via the
 * bridge accessors in src/state/cave_state.h). Per state_contract.md
 * "two views coexist," accessor calls go through `RAM($XXX)` so that
 * drained C reading via macros + native code reading via accessors
 * see the same byte. We do NOT keep a duplicate typed struct here —
 * that would diverge silently from the RAM-backed view. */
static cave_id_t g_active_cave = 0;

/* Cave-id range gate per NES InitCave (Z_01.asm:79-86): valid cave
 * room types are 0x6A..0x7C inclusive. Outside range = invalid call. */
#define CAVE_ID_MIN 0x6Au
#define CAVE_ID_MAX 0x7Cu

/* Native port of NES InitCaveContinue (Z_01.asm:105-170). Loads text
 * selector from OverworldPersonTextSelectors[cave_idx], 3 ware items
 * + prices from LevelBlockAttrsE (NES SRAM $6A7E + cave_idx*3), and
 * derives CAVE_FLAGS top-bits from text-selector + ware bytes.
 *
 * Inlined to keep cave_init self-contained — cavert_init_cave in
 * src/oracle/cave/cave_runtime.c is not in Debug.md link set, and its
 * z01_set_up_common_cave_objects dependency cascades into the
 * unlinked src/gen/z_01.c TU.
 *
 * NES Z_01.asm:53 OverworldPersonTextSelectors (20 bytes). */
static const unsigned char k_overworld_person_text_selectors[20] = {
    0x40u, 0x60u, 0x42u, 0x42u, 0x04u, 0x06u, 0x48u, 0x0Au,
    0x4Cu, 0x0Eu, 0xD0u, 0xD2u, 0xD2u, 0xDCu, 0xDCu, 0xDEu,
    0xDEu, 0x62u, 0x62u, 0x62u
};

#define NES_SRAM_LBA_E_BASE  0x6A7Eu     /* LevelBlockAttrsE (Variables.inc:331) */
#define NES_SRAM_LBA_E_PRICE 0x6ABAu     /* LBA_E + 60 (prices region) */

int cave_init(cave_id_t cave_id)
{
    if (cave_id < CAVE_ID_MIN || cave_id > CAVE_ID_MAX) {
        return -1;
    }

    cave_room_type_set(cave_id);          /* RAM($0350) */
    CAVE_PERSON_STATE      = 0u;          /* RAM($00AD) */
    CAVE_TEXT_CHAR_INDEX   = 0u;          /* RAM($0416) */
    CAVE_DELAY_TIMER       = 0u;          /* RAM($0029) */
    CAVE_LINK_ACTION_TIMER = 0u;          /* RAM($00AC) */
    CAVE_LINK_INPUT_FLAGS  = 0u;          /* RAM($00F8) */

    /* NES InitCaveContinue (Z_01.asm:105-170) port:
     * 1) cave_idx = cave_id - $6A.
     * 2) sel = OverworldPersonTextSelectors[cave_idx].
     *    CAVE_TEXT_SELECTOR = sel & $3F; tmp_flags = sel & $C0.
     * 3) For 3 wares (i=0..2):
     *      ware = LBA_E[cave_idx*3 + i];
     *      CaveItemIds[i] = ware;        (RAM $0422+i)
     *      ware_flags[i]  = ware & $C0;  (RAM $00..$02 scratch)
     *      CavePrices[i]  = LBA_E[cave_idx*3 + i + 60];  (RAM $0430+i)
     * 4) CAVE_FLAGS = (tmp_flags>>6) | ware_flags[0] | (ware_flags[2]>>4) | (ware_flags[1]>>2). */
    {
        unsigned char cave_idx = (unsigned char)(cave_id - 0x6Au);
        unsigned char sel = k_overworld_person_text_selectors[cave_idx];
        CAVE_TEXT_SELECTOR = (unsigned char)(sel & 0x3Fu);
        unsigned char tmp_flags_top = (unsigned char)(sel & 0xC0u);

        unsigned char ware_off = (unsigned char)(cave_idx * 3u);
        unsigned char ware_flag_0 = 0u, ware_flag_1 = 0u, ware_flag_2 = 0u;
        for (unsigned char i = 0u; i < 3u; ++i) {
            unsigned char ware  = nes_ram[NES_SRAM_LBA_E_BASE + ware_off + i];
            unsigned char price = nes_ram[NES_SRAM_LBA_E_PRICE + ware_off + i];
            RAM(0x0422u + i) = ware;                   /* CaveItemIds */
            RAM(0x0430u + i) = price;                  /* CavePrices */
            if (i == 0u) ware_flag_0 = (unsigned char)(ware & 0xC0u);
            if (i == 1u) ware_flag_1 = (unsigned char)(ware & 0xC0u);
            if (i == 2u) ware_flag_2 = (unsigned char)(ware & 0xC0u);
        }
        unsigned char cave_flags = (unsigned char)((tmp_flags_top >> 6) |
                                                   ware_flag_0          |
                                                   (ware_flag_2 >> 4)   |
                                                   (ware_flag_1 >> 2));
        cave_flags_set(cave_flags);
    }

    g_active_cave = cave_id;
    return 0;
}

void cave_tick(void)
{
    /* Stub. Per Phase 3 task list: cavert_update_cave_person dispatch
     * table (9 states) ports here per-state. First port: state 0 =
     * cavert_update_transfer_prices. Subsequent commits add states
     * 1-8 + draw_cave_person + draw_cave_items.
     *
     * As of Phase 4 native cave_update_cave_person port, cave_tick
     * runs the full top-level dispatch (5/9 state arms native, 4
     * deferred to text rendering pipeline). Slot 1 is NES convention
     * for the cave person object slot. */
    cave_update_cave_person(1u);
}

void cave_exit(void)
{
    /* Clear RAM-backed cave state. NES InitCave's "destroy cave object"
     * path (Z_01.asm:98-103) writes ObjType+1=0 + ObjState=0 then RTS;
     * mirror that minimal teardown. Other RAM cells (delay timer, ware
     * inventory) are left as-is — NES code does not zero them on exit. */
    cave_room_type_set(0u);
    CAVE_PERSON_STATE = 0u;
    cave_flags_set(0u);
    g_active_cave = 0u;
}

cave_id_t cave_current_id(void)
{
    return g_active_cave;
}

/* NES Z_01.asm CaveWareXs (line 385): X coords for the 3 ware slots. */
static const unsigned char k_cave_ware_xs[CAVE_WARES_PER_ROOM] = {
    0x58u, 0x78u, 0x98u
};

/* Inline equivalent of cavert_clear_prices_cave_flag (drain trivial):
 *   CAVE_FLAGS &= 0xF7  (clear bit 0x08 = show-prices). */
static inline void cave_clear_prices_flag_inline(void)
{
    cave_flags_set((uint8_t)(cave_flags_get() & 0xF7u));
}

/* Inline 6502 abs(signed_byte). Native equivalent of z01_abs shim
 * (corert_abs trivial). */
static inline unsigned char cave_abs_inline(unsigned char x)
{
    return (unsigned char)(((signed char)x < 0) ? -(signed char)x : (signed char)x);
}

/* Inline equivalent of cavert_prepend_sign_to_price (drain trivial,
 * src/oracle/cave/cave_runtime.c:56). Sign tile = 100 (gain) when
 * amount is $14 (20) or $32 (50), else 98 (loss). Writes to the
 * transfer-buf sign byte at offset RAM(0x0306 + off). */
static inline void cave_prepend_sign_to_price_inline(unsigned char val,
                                                     unsigned char off)
{
    const unsigned char sign = (val == 0x14u || val == 0x32u) ? 100u : 98u;
    CAVE_TRANSFER_BUF_PRICE_SIGN(off) = sign;
}

/* NES Z_01.asm HintCaveTextSelectors0 (line 845: $14 $14 $16) +
 * HintCaveTextSelectors1 (line 848: $14 $18 $1A). Adjacent in ROM,
 * NES indexes past selectors0 to read selectors1 when base_off=3.
 * Bake in as a 6-byte combined table. */
static const unsigned char k_hint_cave_text_selectors[6] = {
    0x14u, 0x14u, 0x16u,   /* HintCaveTextSelectors0 (room $75) */
    0x14u, 0x18u, 0x1Au,   /* HintCaveTextSelectors1 (room != $75) */
};

/* NES Z_01.asm TextboxLineAddrsLo (line 562: $C4 $E4 $A4). */
static const unsigned char k_textbox_line_addrs_lo[3] = {
    0xC4u, 0xE4u, 0xA4u,
};

void cave_update_transfer_prices(void)
{
    /* NES UpdateCavePersonState_TransferPrices (Z_01.asm:442):
     *   AND CaveFlags, #$08
     *   BEQ skip_to_inc_state
     *   JSR WritePricesTransferBuf  ; format prices
     *   RTS
     *  skip_to_inc_state:
     *   INC CavePersonState         ; advance state machine
     *   RTS
     *
     * Drain (cave_runtime.c:220): logically equivalent — early-return
     * via inc_cave_state if no prices, else write prices buf.
     *
     * Native: inline state++ instead of z01_inc_cave_state (transpile
     * shim forbidden in src/game/). CAVE_PERSON_STATE macro = RAM($00AD)
     * via cave_state.h. */
    if (!(cave_flags_get() & 0x08u)) {
        CAVE_PERSON_STATE = (uint8_t)(CAVE_PERSON_STATE + 1u);
        return;
    }
    /* TODO Phase 4: native cave_write_prices_transfer_buf — BCD digit
     * formatter + transfer-buf writes (cavert_format_decimal_byte +
     * cavert_write_prices_to_dynamic_transfer_buf chain). Stage-1 stub. */
}

void cave_draw_items(void)
{
    /* CaveWareXs (k_cave_ware_xs at file scope): NES Z_01.asm:385. */

    /* Show-items flag. Loop wares 2 -> 0 (NES: STA $0421 ; DEC ; BPL). */
    if (cave_flags_get() & 0x04u) {
        cave_active_ware_index_set(2u);
        do {
            const unsigned char i = cave_active_ware_index_get();
            /* ObjX/ObjY for slot 19 = CAVE_WARE_DRAW_SLOT.
             * NES: STA ObjX+19 / STA ObjY+19. ObjX base = $0070 → +19 = $0083.
             * ObjY base = $0084 → +19 = $0097. */
            RAM(0x0083) = k_cave_ware_xs[i];
            RAM(0x0097) = 0x98u;
            /* CaveItemIds[i] = $0422 + i (CAVE_WARE_ITEM macro). $3F = sentinel. */
            const unsigned char item = (unsigned char)(RAM(0x0422 + i) & 0x3Fu);
            if (item != 0x3Fu) {
                draw_animate_item_object(item, 19u);
            }
            cave_active_ware_index_set(
                (unsigned char)(cave_active_ware_index_get() - 1u));
        } while ((signed char)cave_active_ware_index_get() >= 0);
    }

    /* Show-prices flag → draw rupee sprite at ($30, $AB), item id $18 (rupee). */
    if (cave_flags_get() & 0x08u) {
        RAM(0x0083) = 0x30u;
        RAM(0x0097) = 0xABu;
        draw_animate_item_object(0x18u, 19u);
    }
}

void cave_update_talk_shop_or_door_charge(void)
{
    /* NES UpdateCavePersonState_TalkOrShopOrDoorCharge (Z_01.asm:666).
     * Drain at src/oracle/cave/cave_runtime.c:228. Verdict MATCH per
     * Phase 3 summary. */

    /* Branch 1: shop is closed for the cave-flag $01 conditions.
     * Set state=8 (terminal), and if door-repair cave (room $71)
     * accumulate +20 rupees of pending door-charge. */
    if (!(cave_flags_get() & 0x01u)) {
        CAVE_PERSON_STATE = 8u;
        if (cave_room_type_get() == 0x71u) {
            CAVE_DOOR_REPAIR_RUPEE_DELTA = (int8_t)(CAVE_DOOR_REPAIR_RUPEE_DELTA + 20);
            progress_set_room_flag_uw_item_state();
        }
        return;
    }

    /* Branch 2: door-repair pending (delta != 0) — wait. */
    if (CAVE_DOOR_REPAIR_RUPEE_DELTA != 0) {
        return;
    }

    /* Branch 3: ware-purchase loop. Scan slots 2,1,0. NES: LDX #$02 / DEX / BPL. */
    for (signed int i = 2; i >= 0; --i) {
        const unsigned char item = (unsigned char)(RAM(0x0422 + i) & 0x3Fu);
        if (item == 0x3Fu) {
            continue;
        }
        /* Link X ($0070) must equal ware slot's X. */
        if (RAM(0x0070) != k_cave_ware_xs[i]) {
            continue;
        }
        /* abs(Link Y ($0084) - 0x98) < 6. */
        const unsigned char dist = cave_abs_inline((unsigned char)(RAM(0x0084) - 0x98u));
        if (dist >= 6u) {
            continue;
        }

        /* Selected ware index latches. */
        RAM(0x0438) = (unsigned char)i;  /* NES $0438 = CAVE_SELECTED_WARE_INDEX */

        const unsigned char flags30 = (unsigned char)(cave_flags_get() & 0x30u);
        if (flags30) {
            /* If $20 alone (not $10), advance to state=5 immediately. */
            if (!(flags30 & 0x10u)) {
                CAVE_PERSON_STATE = 5u;
                return;
            }
            /* Pay then advance. */
            if (LINK_RUPEES < RAM(0x0430 + i)) {
                return;  /* not enough rupees */
            }
            core_post_debit((unsigned int)RAM(0x0430 + i));
            CAVE_PERSON_STATE = 5u;
            return;
        }

        /* No $30 flags: regular ware purchase. */
        if (cave_flags_get() & 0x02u) {
            if (LINK_RUPEES < RAM(0x0430 + i)) {
                return;
            }
            core_post_debit((unsigned int)RAM(0x0430 + i));
        }
        if (cave_flags_get() & 0x40u) {
            const unsigned char min_hearts =
                (cave_room_type_get() == 0x6Cu) ? 64u : 0xB0u;
            if (min_hearts < LINK_HEARTS) {
                return;
            }
        }
        /* Take the ware. */
        progress_set_room_flag_uw_item_state();
        RAM(0x0422 + i) = 0xFFu;  /* CAVE_WARE_ITEM(i) = 0xFF */
        /* TODO Phase 4: native cave_take_item(item) (cross-subsystem). */
        (void)item;
        core_cue_transfer_buf_and_advance_state(30u);
        CAVE_DELAY_TIMER = 64u;
        cave_clear_prices_flag_inline();
        return;
    }
}

/* Inline equivalent of cavert_swap_space_and_sign (drain trivial,
 * src/oracle/cave/cave_runtime.c:61). NES SwapSpaceAndSign at
 * Z_01.asm:539 — if input == $24 (space), swap with CAVE_TMP4 (the
 * dash/sign prefix). */
static inline unsigned char cave_swap_space_and_sign_inline(unsigned char d0)
{
    if (d0 == 0x24u) {
        const unsigned char tmp = CAVE_TMP4;
        CAVE_TMP4 = d0;
        d0 = tmp;
    }
    return d0;
}

void cave_format_decimal_byte(unsigned char val)
{
    /* NES FormatDecimalByte (Z_01.asm:3129). Drain MATCH per finding
     * 3_4n_i. NES does two DivideBy10 calls to extract units / tens /
     * hundreds; native uses /10 + %10 directly (same arithmetic).
     *
     * Leading-zero suppression: hundreds 0 -> $24 (space). If both
     * hundreds and tens are zero, tens also -> $24 (the units digit
     * is always rendered, even for value 0). */
    const unsigned char units    = (unsigned char)(val % 10u);
    const unsigned char rest     = (unsigned char)(val / 10u);
    unsigned char       tens     = (unsigned char)(rest % 10u);
    unsigned char       hundreds = (unsigned char)(rest / 10u);

    CAVE_TMP3 = units;
    if (hundreds == 0u) {
        hundreds = 0x24u;
        if (tens == 0u) {
            tens = 0x24u;
        }
    }
    CAVE_TMP2 = tens;
    CAVE_TMP1 = hundreds;
}

void cave_write_prices_to_dynamic_transfer_buf(unsigned char price_char)
{
    /* NES WritePricesToDynamicTransferBuf (Z_01.asm:455). Drain at
     * src/oracle/cave/cave_runtime.c:96. Drain MATCH per finding 3_4n_i.
     *
     * For each of 3 ware slots:
     *   - If price == 0: store space ($24) in tmp1/2/3.
     *   - Else: format digits via cave_format_decimal_byte.
     *   - Determine sign char ($62 if cave-flag bit 0x80 = "negative
     *     amounts", else $24 space).
     *   - Swap space/sign across hundreds/tens slots so the dash sits
     *     directly beside the leftmost non-space digit.
     *   - Write hundreds/tens/units (and the sign byte) into the
     *     dynamic transfer buffer at offset.
     * Bumps delay timer to 10 frames + cues advance-state. */
    RAM(0x0305) = price_char;        /* DynTileBuf+3 = price char */
    CAVE_TRANSFER_PRICE_COUNT  = 0u; /* CaveCurPriceIndex  = $042E */
    CAVE_TRANSFER_PRICE_OFFSET = 0u; /* CaveCurPriceOffset = $042F */
    do {
        const unsigned char price_index = CAVE_TRANSFER_PRICE_COUNT;
        const unsigned char price = (unsigned char)RAM(0x0430 + price_index);
        unsigned char dash;
        unsigned char off;

        if (price == 0u) {
            CAVE_TMP1 = 0x24u;
            CAVE_TMP2 = 0x24u;
            CAVE_TMP3 = 0x24u;
        } else {
            cave_format_decimal_byte(price);
        }

        /* Cave flag $80 = negative-amount display → dash, else space. */
        dash = (cave_flags_get() & 0x80u) ? 98u : 0x24u;
        CAVE_TMP4 = dash;

        off = CAVE_TRANSFER_PRICE_OFFSET;
        CAVE_TRANSFER_BUF_PRICE_TENS(off) =
            cave_swap_space_and_sign_inline(CAVE_TMP2);
        CAVE_TRANSFER_BUF_PRICE_HUNDREDS(off) =
            cave_swap_space_and_sign_inline(CAVE_TMP1);
        CAVE_TRANSFER_BUF_PRICE_UNITS(off) = CAVE_TMP3;
        CAVE_TRANSFER_PRICE_OFFSET = (unsigned char)(off + 4u);
        CAVE_TRANSFER_PRICE_COUNT  = (unsigned char)(price_index + 1u);
    } while (CAVE_TRANSFER_PRICE_COUNT < CAVE_WARES_PER_ROOM);

    CAVE_DELAY_TIMER = 10u;
    core_cue_transfer_buf_and_advance_state(10u);
}

void cave_write_prices_transfer_buf(void)
{
    /* NES WritePricesTransferBuf (Z_01.asm:449):
     *   JSR CopyPriceListTemplate  ; (Phase 4 stub)
     *   LDA #$21                   ; "X"
     *   fall through to WritePricesToDynamicTransferBuf
     *
     * Drain at src/oracle/cave/cave_runtime.c:126. */

    /* TODO Phase 4: native cave_copy_price_list_template(). The
     * template is a fixed 30-byte ROM blob copied into the static
     * transfer buf — not yet ported. */

    /* Price char $21 = NES tile "X" (multiplier prefix in shop). */
    cave_write_prices_to_dynamic_transfer_buf(0x21u);
}

void cave_update_cave_person(unsigned int slot)
{
    /* NES UpdateCavePerson (Z_01.asm:300). Drain at
     * src/oracle/cave/cave_runtime.c:326-353. Drain MATCH per Gate 1
     * finding 3_4n_h_cave_update_cave_person.md. */

    /* State 4 frame-skip: every other frame skip draw + go straight to
     * dispatch. NES `LDA ObjState+1 / CMP #4 / BNE :+ / LDA FrameCounter
     *               / AND #$01 / BNE @UpdateCavePersonDirect`. */
    const unsigned char state = CAVE_PERSON_STATE;
    if (!(state == 4u && (RAM(0x0015) & 1u))) {  /* FrameCounter = $0015 */
        cave_draw_person(slot);

        /* Medicine-shop letter ($74) logic. NES: `LDA ObjType+1 / CMP #$74
         *   / BNE @DrawItems / LDA InvLetter / CMP #$02 / BEQ @DrawItems`. */
        if (cave_room_type_get() == 0x74u && CAVE_ROOM_SCRIPT_STATE != 2u) {
            /* SelectedItemSlot ($0656) == 0x0F (letter slot) AND B pressed
             * (ButtonsPressed bit 0x40) → use letter. */
            if (RAM(0x0656) == 0x0Fu && (CAVE_LINK_INPUT_FLAGS & 0x40u)) {
                RAM(0x0602) = 4u;                /* Tune1Request = secret-found tune */
                CAVE_ROOM_SCRIPT_STATE =
                    (uint8_t)(CAVE_ROOM_SCRIPT_STATE + 1u);  /* INC InvLetter */
                RAM(0x0656) = 7u;                /* SelectedItemSlot = potion */
                /* Falls through to draw_items + dispatch below. */
            } else {
                /* @Unhalt: if halted (ObjState == $40), unhalt. NES UnhaltLink
                 * (Z_01.asm:100) = `LDA #$00 / STA ObjState`. */
                if (CAVE_LINK_ACTION_TIMER == 0x40u) {
                    CAVE_LINK_ACTION_TIMER = 0u;
                }
                return;
            }
        }
        cave_draw_items();
    }

    /* 9-state dispatch — NES UpdateCavePerson_JumpTable (Z_01.asm:359-368).
     * Native arms invoked where ported; states 1/3/6/7 are stubs pending
     * Phase 4 native cave_update_person_state_textbox + native
     * cue_transfer_blank_person_wares. */
    switch (CAVE_PERSON_STATE) {
        case 0u: cave_update_transfer_prices(); break;
        case 1u: /* TODO Phase 4: native cave_update_person_state_textbox(). */
                 break;
        case 2u: cave_update_talk_shop_or_door_charge(); break;
        case 3u: core_cue_transfer_blank_person_wares(); break;
        case 4u: cave_update_person_state_delay_then_hide(); break;
        case 5u: cave_update_hint_or_money_game(); break;
        case 6u: core_cue_transfer_blank_person_wares(); break;  /* same as state 3 */
        case 7u: /* TODO Phase 4: same as state 1 (textbox). */
                 break;
        case 8u: /* DoNothing */
                 break;
        default: break;
    }
}

void cave_update_person_state_delay_then_hide(void)
{
    /* NES UpdatePersonState_DelayThenHide (Z_01.asm:838). Drain trivial
     * per Phase 3 summary. Sets CAVE_ROOM_TYPE = 0 (i.e. "no cave
     * person") once the delay timer reaches zero. */
    if (CAVE_DELAY_TIMER == 0u) {
        cave_room_type_set(0u);
    }
}

void cave_clear_prices_flag(void)
{
    /* Public wrapper around the file-static inline helper. Mirrors
     * cavert_clear_prices_cave_flag (drain trivial: CAVE_FLAGS &= 0xF7,
     * i.e. clear the show-prices bit 0x08). */
    cave_clear_prices_flag_inline();
}

void cave_update_hint_or_money_game(void)
{
    /* NES UpdateCavePersonState_HintOrMoneyGame (Z_01.asm:851).
     * Drain: src/oracle/cave/cave_runtime.c:285-324. MATCH verdict per
     * Phase 3 summary. */

    /* Branch 1: hint cave (cave_flag $10). */
    if (cave_flags_get() & 0x10u) {
        const unsigned char base_off =
            (cave_room_type_get() == 0x75u) ? 0u : 3u;
        const unsigned char sel_idx =
            (unsigned char)(base_off + RAM(0x0438));  /* CAVE_SELECTED_WARE_INDEX */
        CAVE_TEXT_SELECTOR    = k_hint_cave_text_selectors[sel_idx];
        CAVE_TEXT_LINE_ADDR_LO = k_textbox_line_addrs_lo[2];
        CAVE_TEXT_CHAR_INDEX  = 0u;
        cave_clear_prices_flag_inline();
        core_cue_transfer_buf_and_advance_state(30u);
        return;
    }

    /* Branch 2: door-charge variant (CAVE_ROOM_TYPE >= $7B). */
    if (cave_room_type_get() >= 0x7Bu) {
        /* TODO Phase 4: native cave_copy_price_list_template(). */
        /* TODO Phase 4: native cave_write_prices_to_dynamic_transfer_buf(36). */
        CAVE_TEXT_TICK_SFX = 8u;
        progress_set_room_flag_uw_item_state();
        CAVE_PERSON_STATE  = 8u;
        core_post_credit((unsigned int)RAM(0x0430 + 1));  /* CAVE_PRICE(1) */
        return;
    }

    /* Branch 3: money game. */
    if ((unsigned char)LINK_RUPEES < 0x0Au) {
        return;
    }
    CAVE_TEXT_TICK_SFX = 8u;
    /* Copy prize amounts to ware prices (3 slots). */
    RAM(0x0430 + 0) = RAM(0x0448 + 0);  /* CAVE_PRICE(0) = CAVE_PRIZE_ORDER(0) */
    RAM(0x0430 + 1) = RAM(0x0448 + 1);
    RAM(0x0430 + 2) = RAM(0x0448 + 2);
    cave_write_prices_transfer_buf();
    CAVE_PERSON_STATE = 8u;
    cave_prepend_sign_to_price_inline(RAM(0x0448 + 0), 1u);
    cave_prepend_sign_to_price_inline(RAM(0x0448 + 1), 5u);
    cave_prepend_sign_to_price_inline(RAM(0x0448 + 2), 9u);
    {
        const unsigned char chosen = RAM(0x0438);  /* CAVE_SELECTED_WARE_INDEX */
        const unsigned char amount = RAM(0x0448 + chosen);  /* CAVE_PRIZE_ORDER */
        if (amount == 0x14u || amount == 0x32u) {
            core_post_credit((unsigned int)amount);
        } else {
            core_post_debit((unsigned int)amount);
        }
    }
}

void cave_draw_person(unsigned int slot)
{
    /* drain at oracle/cave/cave_runtime.c:191-197. NES DrawCavePerson
     * (Z_01.asm DrawCavePerson via c_draw_cave_person).
     *
     * Fetch sprite descriptor pos, then mirrored vs non-mirrored
     * draw based on cave_id $7B threshold. Frame defaults to 0 —
     * the c_draw_object_* shim doesn't set D0 either, and cave
     * persons are static. */
    sprite_anim_fetch_obj_pos(slot);
    const unsigned char cave_id = cave_room_type_get();
    if (cave_id < 0x7Bu) {
        draw_object_mirrored(0u, slot);
    } else {
        draw_object_not_mirrored(0u, slot);
    }
}

void cave_try_take_item(unsigned int slot)
{
    /* drain at cave_runtime.c:356-378. */
    if ((unsigned char)RAM(0x03A8u + slot) >= 0xF0u) {
        return;
    }
    {
        const unsigned char dy = (unsigned char)(
            (unsigned char)RAM(0x0084u) + 3u - (unsigned char)OBJ_Y(slot));
        if (core_abs((unsigned int)dy) >= 9u) {
            return;
        }
    }
    {
        const unsigned char dx = (unsigned char)(
            (unsigned char)RAM(0x0070u) - (unsigned char)OBJ_X(slot));
        if (core_abs((unsigned int)dx) >= 9u) {
            return;
        }
    }
    OBJ_STATE(slot) = 0xFFu;
    OBJ_Y(slot) = 0xFFu;
    if (slot == CAVE_WARE_DRAW_SLOT) {
        progress_set_room_flag_uw_item_state();
    }
    item_take_item((unsigned char)CAVE_TMP4);
}

void cave_try_take_room_item(void)
{
    /* drain at cave_runtime.c:380-393. */
    const unsigned int slot = CAVE_WARE_DRAW_SLOT;
    if (((unsigned char)CAVE_LINK_ACTION_TIMER & 0xC0u) == 0x40u) {
        return;
    }
    if (progress_get_room_flag_uw_item_state() != 0u) {
        return;
    }
    if ((unsigned char)OBJ_STATE(slot) & 0x80u) {
        return;
    }
    CAVE_TMP4 = (uint8_t)OBJ_DIR(slot);
    cave_try_take_item(slot);
}

/* STAGE-2 partial port: Link side-render during textbox. NES asm
 * Link_EndMoveAndDraw freezes anim timer + chains to
 * Link_EndMoveAndAnimate (huge ladder/water/warp/draw chain).
 * For textbox context Link is halted, so the move + warp logic is
 * effectively no-op — only the draw matters. Native partial
 * implementation: freeze anim, fetch sprite-descriptor pos,
 * draw Link statically via native draw_dispatch. Full fidelity
 * (ladder/water/warp/animation) deferred to phase 5
 * Link_EndMoveAndAnimate native port. */
static void cave_link_end_move_and_draw_stub(void)
{
    OBJ_ANIM_TIMER(0) = 6u;
    sprite_anim_fetch_obj_pos(0u);
    draw_object_mirrored(0u, 0u);
}

void cave_update_person_state_textbox(void)
{
    /* drain at cave_runtime.c:131-174. */
    cave_link_end_move_and_draw_stub();
    if ((unsigned char)CAVE_DELAY_TIMER != 0u) {
        return;
    }
    CAVE_DELAY_TIMER = 6u;

    /* Copy 5-byte textbox char transfer record template into
     * CAVE_TRANSFER_BUF_CHAR_BASE ($0302..$0306). */
    for (signed int i = 4; i >= 0; --i) {
        RAM(CAVE_TRANSFER_BUF_CHAR_BASE + (unsigned char)i) =
            TextboxCharTransferRecTemplate[i];
    }

    unsigned char ch;
    unsigned char char_idx;
    unsigned short ptr;
    /* Skip $25 (no-op char). */
    do {
        RAM(0x0303u) = (unsigned char)CAVE_TEXT_LINE_ADDR_LO;
        CAVE_TEXT_LINE_ADDR_LO =
            (uint8_t)((unsigned char)CAVE_TEXT_LINE_ADDR_LO + 1u);
        const unsigned char selector = (unsigned char)CAVE_TEXT_SELECTOR;
        CAVE_TMP0 = PersonTextAddrs[selector];
        CAVE_TMP1 = PersonTextAddrs[selector + 1u];
        char_idx = (unsigned char)CAVE_TEXT_CHAR_INDEX;
        CAVE_TEXT_CHAR_INDEX =
            (uint8_t)((unsigned char)CAVE_TEXT_CHAR_INDEX + 1u);
        ptr = (unsigned short)(((unsigned short)(unsigned char)CAVE_TMP1 << 8) |
                               (unsigned char)CAVE_TMP0);
        ch = (unsigned char)(nes_ram[ptr + char_idx] & 0x3Fu);
    } while (ch == 0x25u);

    RAM(0x0305u) = ch;
    CAVE_TEXT_TICK_SFX = 16u;

    const unsigned char line_flags =
        (unsigned char)(nes_ram[ptr + char_idx] & 0xC0u);
    if (line_flags == 0u) {
        return;
    }
    unsigned char line_index;
    if (line_flags == 0xC0u) {
        line_index = 2u;
    } else if (line_flags == 0x40u) {
        line_index = 1u;
    } else {
        line_index = 0u;
    }
    CAVE_TEXT_LINE_ADDR_LO = k_textbox_line_addrs_lo[line_index];
    if (line_index == 2u) {
        CAVE_PERSON_STATE =
            (uint8_t)((unsigned char)CAVE_PERSON_STATE + 1u);
        core_unhalt_link();
    }
}
