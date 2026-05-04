| ===================================================================
| Minimal Genesis ROM that plays an SN76489-only VGM file.
| Loops forever. Targets the Sega Megadrive/Genesis PSG at $C00011.
| ===================================================================

    .section .text.keepboot, "ax"

| ---- Vector table (256 bytes) ----
    .long   0x01000000          | 00: initial SP (top of work RAM mirror)
    .long   _start              | 04: initial PC
    .long   _err, _err, _err, _err
    .long   _err, _err, _err, _err
    .long   _err, _err
    .long   _err, _err, _err, _err
    .long   _err, _err, _err, _err
    .long   _err, _err, _err, _err
    .long   _err                | spurious
    .long   _err                | level1
    .long   _err                | level2
    .long   _err                | level3 (HINT)
    .long   _err                | level4
    .long   _err                | level5 (VINT)
    .long   _err                | level6
    .long   _err                | level7 NMI
    .long   _err, _err, _err, _err, _err, _err, _err, _err
    .long   _err, _err, _err, _err, _err, _err, _err, _err
    .long   _err, _err, _err, _err, _err, _err, _err, _err
    .long   _err, _err, _err, _err, _err, _err, _err, _err

| ---- ROM header ($100..$200) ----
    .ascii  "SEGA GENESIS    "                                  | $100 console
    .ascii  "(C)YOU 2026.APR "                                  | $110 copyright
    .ascii  "ZELDA OVERWORLD VGM PLAYER                      "  | $120 domestic (48)
    .ascii  "ZELDA OVERWORLD VGM PLAYER                      "  | $150 overseas (48)
    .ascii  "GM 00000000-00"                                    | $180 serial (14)
    .word   0x0000                                              | $18E checksum
    .ascii  "J               "                                  | $190 I/O support (16)
    .long   0x00000000                                          | $1A0 ROM start
    .long   0x000FFFFF                                          | $1A4 ROM end
    .long   0x00FF0000                                          | $1A8 RAM start
    .long   0x00FFFFFF                                          | $1AC RAM end
    .ascii  "            "                                      | $1B0 SRAM (12)
    .ascii  "            "                                      | $1BC modem (12)
    .ascii  "                                        "          | $1C8 notes (40)
    .ascii  "JUE             "                                  | $1F0 region (16)

| ---- Code starts at $200 ----
_start:
    move.w  #0x2700, %sr
    move.l  #0x01000000, %sp

    | TMSS unlock for model 1+ consoles
    move.b  0xA10001, %d0
    andi.b  #0x0F, %d0
    beq.s   no_tmss
    move.l  #0x53454741, 0xA14000          | "SEGA"
no_tmss:

    | Halt + reset Z80 so it does not glitch the PSG
    move.w  #0x0100, 0xA11100              | bus request
    move.w  #0x0100, 0xA11200              | reset off (then on -- see below)
1:  btst    #0, 0xA11100
    bne.s   1b

    | Silence all PSG channels
    move.b  #0x9F, 0xC00011
    move.b  #0xBF, 0xC00011
    move.b  #0xDF, 0xC00011
    move.b  #0xFF, 0xC00011

    | Minimal VDP init -- display off, no interrupts (we just want sound)
    move.l  #0xC00004, %a1
    move.w  #0x8004, (%a1)                 | reg 0
    move.w  #0x8104, (%a1)                 | reg 1: display off, VINT off
    move.w  #0x8200, (%a1)                 | reg 2..16 zeroed
    move.w  #0x8300, (%a1)
    move.w  #0x8400, (%a1)
    move.w  #0x8500, (%a1)
    move.w  #0x8600, (%a1)
    move.w  #0x8700, (%a1)
    move.w  #0x8800, (%a1)
    move.w  #0x8900, (%a1)
    move.w  #0x8A00, (%a1)
    move.w  #0x8B00, (%a1)
    move.w  #0x8C00, (%a1)
    move.w  #0x8D00, (%a1)
    move.w  #0x8E00, (%a1)
    move.w  #0x8F02, (%a1)                 | reg 15: auto-inc 2
    move.w  #0x9000, (%a1)
    move.w  #0x9100, (%a1)
    move.w  #0x9200, (%a1)

    | a0 = VGM data cursor, start past 0x40 header
    lea     vgm_data + 0x40, %a0
    | a2 = PSG port for fast access
    move.l  #0xC00011, %a2

play_loop:
    moveq   #0, %d0
    move.b  (%a0)+, %d0

    cmp.b   #0x50, %d0
    beq.s   do_psg
    cmp.b   #0x62, %d0
    beq.s   do_wait_60
    cmp.b   #0x61, %d0
    beq     do_wait_n
    cmp.b   #0x66, %d0
    beq     do_end
    cmp.b   #0x4F, %d0
    beq     do_skip1
    cmp.b   #0x63, %d0
    beq     do_wait_50

    | range dispatch
    cmp.b   #0x70, %d0
    bcs.s   chk_lo                          | < 0x70
    cmp.b   #0x80, %d0
    bcs     do_wait_short                   | 0x70..0x7F
    cmp.b   #0x90, %d0
    bcs     do_dac_wait                     | 0x80..0x8F (DAC + wait n)
    cmp.b   #0xA0, %d0
    bcs     halt                            | 0x90..0x9F unsafe variable -- stop
    cmp.b   #0xC0, %d0
    bcs     do_skip2                        | 0xA0..0xBF
    cmp.b   #0xE0, %d0
    bcs     do_skip3                        | 0xC0..0xDF
    bra     do_skip4                        | 0xE0..0xFF
chk_lo:
    cmp.b   #0x30, %d0
    bcs     halt                            | < 0x30 unknown
    cmp.b   #0x40, %d0
    bcs     do_skip1                        | 0x30..0x3F (1 dummy byte)
    bra     do_skip2                        | 0x40..0x4F (2 dummy bytes)

do_psg:
    move.b  (%a0)+, (%a2)
    bra     play_loop

do_wait_60:
    move.w  #735, %d1
    bsr     wait_samples
    bra     play_loop

do_wait_50:
    move.w  #882, %d1
    bsr     wait_samples
    bra     play_loop

do_wait_n:
    moveq   #0, %d1
    move.b  (%a0)+, %d1                     | low byte
    moveq   #0, %d2
    move.b  (%a0)+, %d2                     | high byte
    lsl.w   #8, %d2
    or.w    %d2, %d1
    bsr     wait_samples
    bra     play_loop

do_wait_short:
    | 0x7n -> wait n+1 samples
    moveq   #0, %d1
    move.b  %d0, %d1
    andi.w  #0x0F, %d1
    addq.w  #1, %d1
    bsr     wait_samples
    bra     play_loop

do_dac_wait:
    | 0x8n -> YM2612 DAC write + wait n samples; we drop the DAC
    moveq   #0, %d1
    move.b  %d0, %d1
    andi.w  #0x0F, %d1
    bsr     wait_samples
    bra     play_loop

do_skip1:
    addq.l  #1, %a0
    bra     play_loop
do_skip2:
    addq.l  #2, %a0
    bra     play_loop
do_skip3:
    addq.l  #3, %a0
    bra     play_loop
do_skip4:
    addq.l  #4, %a0
    bra     play_loop

do_end:
    | Loop the song forever -- silence first to clear note tails
    move.b  #0x9F, (%a2)
    move.b  #0xBF, (%a2)
    move.b  #0xDF, (%a2)
    move.b  #0xFF, (%a2)
    lea     vgm_data + 0x40, %a0
    bra     play_loop

halt:
    move.b  #0x9F, (%a2)
    move.b  #0xBF, (%a2)
    move.b  #0xDF, (%a2)
    move.b  #0xFF, (%a2)
9:  bra.s   9b

| ---- wait d1.w samples (~174 cycles each at 7.67MHz) ----
wait_samples:
    tst.w   %d1
    beq.s   ws_done
    subq.w  #1, %d1
ws_outer:
    move.w  #13, %d4
ws_inner:
    dbra    %d4, ws_inner
    nop
    nop
    nop
    dbra    %d1, ws_outer
ws_done:
    rts

_err:
    rte

| ---- VGM blob ----
    .balign 2
vgm_data:
    .incbin "song.vgm"
    .balign 2
