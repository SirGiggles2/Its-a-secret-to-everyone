;==============================================================================
; midi_player.asm — Compact event-driven YM2612 MIDI player.
;
; Public symbols (called from main.c):
;       ym_init        — load Voice 00 bell pad on YM channels 0..5, mute PSG
;       midi_init      — point play state at compiled blob, prime time_to_next
;       midi_tick      — call once per VBlank; dispatches due events
;
; Compiled blob is incbin'd at label `midi_blob`.  Layout (big-endian):
;       u32 magic = 'MIDI'
;       u32 num_events
;       u32 loop_offset    (byte offset into events[] for loop point)
;       events[N]:
;           u16 delta_frames
;           u8  op        ($00 note-off, $01 note-on, $FF end-of-song)
;           u8  ch        (0..5 -> YM channel)
;           u8  bf_hi     ((block<<3)|fnum_hi)  — destined for $A4+offset
;           u8  fnum_lo   — destined for $A0+offset
;==============================================================================

;----------------------------------------------------------------------
; Hardware ports
;----------------------------------------------------------------------
YM_ADDR1        equ $A04000
YM_DATA1        equ $A04001
YM_ADDR2        equ $A04002
YM_DATA2        equ $A04003
PSG_PORT        equ $C00011

;----------------------------------------------------------------------
; Player state (lives in RAM)
;----------------------------------------------------------------------
MIDI_STATE      equ $FFE000
MS_PLAY_PTR     equ MIDI_STATE+0     ; long: pointer to next event's delta byte
MS_EVENTS_BASE  equ MIDI_STATE+4     ; long: pointer to events[] start
MS_LOOP_PTR     equ MIDI_STATE+8     ; long: events[] + loop_offset
MS_TIME_NEXT    equ MIDI_STATE+12    ; word: frames until next event
MS_END_PTR      equ MIDI_STATE+14    ; long: events[] end (events_base + 6*num_events)

    section "text",code

;==============================================================================
; ym_write1 — write address+data atomically to YM2612 Part I.
; Input:  D0.b = register, D1.b = data.  Preserves D0,D1.
;==============================================================================
ym_write1:
.wait1:
    tst.b   (YM_ADDR1).l
    bmi.s   .wait1
    move.b  D0,(YM_ADDR1).l
    nop
    nop
    nop
    move.b  D1,(YM_DATA1).l
    rts

;==============================================================================
; ym_write2 — write address+data atomically to YM2612 Part II.
; Busy flag is shared, so still poll Part I.
;==============================================================================
ym_write2:
.wait2:
    tst.b   (YM_ADDR1).l
    bmi.s   .wait2
    move.b  D0,(YM_ADDR2).l
    nop
    nop
    nop
    move.b  D1,(YM_DATA2).l
    rts

;==============================================================================
; load_fm_patch_named — load 25-byte patch into one channel.
; Input: A0 = pointer to 25-byte patch, D6.b = YM channel 0..5
;==============================================================================
load_fm_patch_named:
    movem.l D0-D2/D6/A0-A1,-(SP)
    lea     FM_PATCH_REGS(PC),A1
    moveq   #24,D2                  ; 25 register/value pairs
    cmpi.b  #3,D6
    blt.s   .partI
    ; ch 3..5 — Part II, channel offset = ch-3
    subi.b  #3,D6
.lpII:
    move.b  (A1)+,D0
    add.b   D6,D0
    move.b  (A0)+,D1
    bsr     ym_write2
    dbra    D2,.lpII
    bra.s   .done
.partI:
.lpI:
    move.b  (A1)+,D0
    add.b   D6,D0
    move.b  (A0)+,D1
    bsr     ym_write1
    dbra    D2,.lpI
.done:
    movem.l (SP)+,D0-D2/D6/A0-A1
    rts

;==============================================================================
; ym_init — set up YM2612 for 6-voice bell pad playback.
;==============================================================================
    xdef    ym_init
ym_init:
    movem.l D0-D6/A0,-(SP)

    ; Key-off all 6 channels (reg $28; key bits = $00, ch bits 0,1,2,4,5,6)
    move.b  #$28,D0
    moveq   #$00,D1
    bsr     ym_write1
    moveq   #$01,D1
    bsr     ym_write1
    moveq   #$02,D1
    bsr     ym_write1
    moveq   #$04,D1
    bsr     ym_write1
    moveq   #$05,D1
    bsr     ym_write1
    moveq   #$06,D1
    bsr     ym_write1

    ; LFO off
    move.b  #$22,D0
    moveq   #0,D1
    bsr     ym_write1

    ; DAC disabled (ch 6 stays as FM, but we don't use it)
    move.b  #$2B,D0
    moveq   #0,D1
    bsr     ym_write1

    ; Clear SSG-EG for every operator on all 6 channels.
    ; Part I = ch 0,1,2.  Part II = ch 3,4,5 (channel offsets 0,1,2 on Part II).
    moveq   #0,D1
    moveq   #0,D6
.ssg_loop:
    move.b  D6,D0
    addi.b  #$90,D0
    bsr     ym_write1
    move.b  D6,D0
    addi.b  #$90,D0
    bsr     ym_write2
    addq.b  #1,D6
    cmpi.b  #15,D6                  ; 16 iterations covers $90..$9F (4 ops x 3 ch + skip)
    ble.s   .ssg_loop

    ; Load harp patch on ch 0..2 (lead), bell pad on ch 3..5 (backup).
    moveq   #0,D6
.patch_lead:
    lea     PATCH_VOICE00(PC),A0    ; bell pad on lead — best fit per user A/B
    bsr     load_fm_patch_named
    addq.b  #1,D6
    cmpi.b  #2,D6
    ble.s   .patch_lead
.patch_backup:
    lea     PATCH_PAD(PC),A0        ; slow-swell mystical pad for backup line
    bsr     load_fm_patch_named
    addq.b  #1,D6
    cmpi.b  #5,D6
    ble.s   .patch_backup

    ; Panning L+R for ch 0..2 ($B4..$B6 Part I)
    move.b  #$C0,D1
    move.b  #$B4,D0
    bsr     ym_write1
    move.b  #$B5,D0
    bsr     ym_write1
    move.b  #$B6,D0
    bsr     ym_write1
    ; ch 3..5 ($B4..$B6 Part II)
    move.b  #$B4,D0
    bsr     ym_write2
    move.b  #$B5,D0
    bsr     ym_write2
    move.b  #$B6,D0
    bsr     ym_write2

    ; Mute PSG (we don't use it)
    move.b  #$9F,(PSG_PORT).l
    move.b  #$BF,(PSG_PORT).l
    move.b  #$DF,(PSG_PORT).l
    move.b  #$FF,(PSG_PORT).l

    movem.l (SP)+,D0-D6/A0
    rts

;==============================================================================
; midi_init — initialize player state from the compiled blob.
;==============================================================================
    xdef    midi_init
midi_init:
    movem.l D0-D2/A0,-(SP)
    lea     midi_blob(PC),A0

    ; Verify magic == 'MIDI'.  If wrong, leave state zeroed (player no-ops).
    cmpi.l  #$4D494449,(A0)
    bne     .bad

    move.l  4(A0),D0                 ; num_events
    move.l  8(A0),D1                 ; loop_offset (bytes)

    lea     12(A0),A0                ; A0 -> events_base (skip 12-byte header)
    move.l  A0,(MS_EVENTS_BASE).l
    move.l  A0,(MS_PLAY_PTR).l

    ; Loop pointer = events_base + loop_offset
    move.l  A0,D2
    add.l   D1,D2
    move.l  D2,(MS_LOOP_PTR).l

    ; End pointer = events_base + 6 * num_events
    move.l  D0,D2
    lsl.l   #1,D2                    ; *2
    add.l   D0,D2
    add.l   D0,D2
    add.l   D0,D2
    add.l   D0,D2                    ; D2 = num_events*6 (1+1+1+1+1+1 = 6)
    add.l   A0,D2
    move.l  D2,(MS_END_PTR).l

    ; Prime time_to_next from the first event's delta (peek u16 at A0).
    move.w  (A0),D0
    move.w  D0,(MS_TIME_NEXT).l

    movem.l (SP)+,D0-D2/A0
    rts

.bad:
    move.w  #$7FFF,(MS_TIME_NEXT).l  ; effectively idle forever
    movem.l (SP)+,D0-D2/A0
    rts

;==============================================================================
; midi_tick — called once per VBlank.
;==============================================================================
    xdef    midi_tick
midi_tick:
    movem.l D0-D6/A0,-(SP)

    move.w  (MS_TIME_NEXT).l,D7
    beq.s   .due
    subq.w  #1,D7
    move.w  D7,(MS_TIME_NEXT).l
    bne     .out
.due:
    movea.l (MS_PLAY_PTR).l,A0

.dispatch:
    ; Bounds check (defensive — well-formed blob hits 0xFF before this)
    move.l  A0,D0
    cmp.l   (MS_END_PTR).l,D0
    bge.s   .loop_back

    ; Read header: u16 delta, u8 op, u8 ch, u8 bf_hi, u8 fnum_lo
    move.w  (A0)+,D5                 ; delta (already consumed when we entered)
    move.b  (A0)+,D0                 ; op
    move.b  (A0)+,D6                 ; ch (0..5)
    move.b  (A0)+,D3                 ; bf_hi (block<<3 | fnum_hi)
    move.b  (A0)+,D4                 ; fnum_lo

    cmpi.b  #$FF,D0
    beq.s   .loop_back

    cmpi.b  #$01,D0
    beq.s   .note_on
    ; else note-off
    bsr     do_note_off
    bra.s   .next_event

.note_on:
    bsr     do_note_on

.next_event:
    ; Peek next event's delta to see whether to keep dispatching this frame.
    move.l  A0,D0
    cmp.l   (MS_END_PTR).l,D0
    bge.s   .loop_back
    move.w  (A0),D0                  ; next event's delta
    bne.s   .stop_dispatch
    bra.s   .dispatch                ; delta=0, dispatch immediately

.stop_dispatch:
    move.w  D0,(MS_TIME_NEXT).l
    move.l  A0,(MS_PLAY_PTR).l
    bra.s   .out

.loop_back:
    movea.l (MS_LOOP_PTR).l,A0
    move.w  (A0),D0
    move.w  D0,(MS_TIME_NEXT).l
    move.l  A0,(MS_PLAY_PTR).l
    ; If we just landed on a delta-0 event, dispatch it now.
    tst.w   D0
    beq.s   .dispatch

.out:
    movem.l (SP)+,D0-D6/A0
    rts

;==============================================================================
; do_note_on — emit block/fnum to YM ch in D6, then key-on all operators.
; Input:  D6.b = ch 0..5, D3.b = bf_hi, D4.b = fnum_lo
;==============================================================================
do_note_on:
    movem.l D0-D2,-(SP)

    cmpi.b  #3,D6
    blt.s   .freq_partI
    ; Part II
    move.b  D6,D2
    subi.b  #3,D2                    ; ch-3 = Part II offset
    move.b  D2,D0
    addi.b  #$A4,D0                  ; reg $A4+offset
    move.b  D3,D1                    ; data = bf_hi
    bsr     ym_write2
    move.b  D2,D0
    addi.b  #$A0,D0
    move.b  D4,D1
    bsr     ym_write2
    bra.s   .key_on

.freq_partI:
    move.b  D6,D0
    addi.b  #$A4,D0
    move.b  D3,D1
    bsr     ym_write1
    move.b  D6,D0
    addi.b  #$A0,D0
    move.b  D4,D1
    bsr     ym_write1

.key_on:
    ; Key-on: reg $28 always Part I.  Data = $F0 | yamaha_id where
    ; yamaha_id = ch for ch<3, else ch+1.
    move.b  #$28,D0
    move.b  D6,D1
    cmpi.b  #3,D6
    blt.s   .ko_lt
    addq.b  #1,D1
.ko_lt:
    ori.b   #$F0,D1
    bsr     ym_write1

    movem.l (SP)+,D0-D2
    rts

;==============================================================================
; do_note_off — key-off all operators on YM ch in D6.
;==============================================================================
do_note_off:
    movem.l D0-D1,-(SP)
    move.b  #$28,D0
    move.b  D6,D1
    cmpi.b  #3,D6
    blt.s   .kf_lt
    addq.b  #1,D1
.kf_lt:
    andi.b  #$0F,D1                  ; key bits = 0 -> all operators off
    bsr     ym_write1
    movem.l (SP)+,D0-D1
    rts

;==============================================================================
; FM patch tables
;==============================================================================
    section "rodata",data

    even
FM_PATCH_REGS:
    dc.b    $B0
    dc.b    $30,$34,$38,$3C
    dc.b    $50,$54,$58,$5C
    dc.b    $60,$64,$68,$6C
    dc.b    $70,$74,$78,$7C
    dc.b    $80,$84,$88,$8C
    dc.b    $40,$44,$48,$4C
    even

; Voice $00 — bell pad (Sonic 2 EHZ; verbatim from src/audio_driver.asm)
PATCH_VOICE00:
    dc.b    $2D                     ; FB/ALG: (5<<3)|5
    dc.b    $04,$01,$01,$01         ; DT/MUL — op1 MUL 4 (bell modulator)
    dc.b    $1F,$1F,$1F,$1F         ; RS/AR max
    dc.b    $08,$04,$04,$04         ; AM/D1R
    dc.b    $00,$00,$00,$00         ; D2R
    dc.b    $47,$37,$37,$17         ; DL/RR — bell tail
    dc.b    $14,$1E,$1E,$1E         ; TL — modulator $14, carriers $1E
    even

; Mystical pad — distinctly different from the celesta lead.  Carriers
; have a SLOW attack so each note swells in like a breath of mist behind
; the bright lead twinkle.  Op1 modulator stays at MUL 4 with high TL so
; only a faint metallic shimmer rides on top of pure-tone carriers.  No
; FB.  Carriers mildly detuned for chorus.  Net effect: airy washes
; that bloom under the lead's plucks instead of competing with them.
PATCH_PAD:
    dc.b    $05                     ; FB/ALG: FB 0, ALG 5
    dc.b    $04,$11,$01,$51         ; DT/MUL — op1 MUL 4 modulator
    dc.b    $1F,$10,$10,$10         ; RS/AR — mod instant, carriers SLOW attack
    dc.b    $00,$02,$02,$02         ; AM/D1R — long decay
    dc.b    $00,$00,$00,$00         ; D2R
    dc.b    $4A,$28,$28,$28         ; DL/RR — long sustained tail
    dc.b    $30,$1A,$1A,$1A         ; TL — mod whisper, carriers gentle
    even

; Flute/organ patch — additive ALG 7 (4 carriers in parallel).
;   Op MUL ratios 1:2:3:4 add octave and 5th overtones for an airy, woody
;   timbre.  Sustained envelope (no decay during note hold), fast release
;   on key-off.  FB 1 for slight warmth without distortion.
;   Slot byte order in YM2612 patches is op1, op3, op2, op4.
PATCH_FLUTE:
    dc.b    $0F                     ; FB/ALG: (1<<3)|7
    dc.b    $01,$03,$02,$04         ; DT/MUL (op1=1, op3=3, op2=2, op4=4)
    dc.b    $1F,$1F,$1F,$1F         ; RS/AR — instant attack
    dc.b    $00,$00,$00,$00         ; AM/D1R — no decay, sustain at TL
    dc.b    $00,$00,$00,$00         ; D2R
    dc.b    $0F,$0F,$0F,$0F         ; DL/RR — DL 0, RR 15 (fast release)
    dc.b    $18,$24,$20,$2C         ; TL — fundamental loudest, harmonics quieter
    even

; Voice $03 — EHZ FM3 lead (Sonic 2; bright FB7 / Algorithm 5).
PATCH_VOICE03:
    dc.b    $3D                     ; FB/ALG: (7<<3)|5
    dc.b    $01,$51,$21,$01         ; DT/MUL
    dc.b    $1F,$1F,$1F,$1F         ; RS/AR
    dc.b    $0A,$05,$05,$05         ; AM/D1R
    dc.b    $00,$00,$00,$00         ; D2R
    dc.b    $2B,$2B,$2B,$1B         ; DL/RR
    dc.b    $19,$18,$18,$18         ; TL
    even

; Twinkle / celesta lead — soft mystical bell, light and bright.
;   Algorithm 5 (3 carriers driven by op1 modulator), FB 0 keeps timbre
;   clean and pure (no FB-induced grit).  Op1 MUL 2 with low modulator
;   level adds just a hint of chime without harsh overtones.  Carriers
;   are slightly detuned (DT 1, 0, -1) for a gentle chorus shimmer that
;   reads as "mystical" rather than dry.  Long DL+RR gives notes a
;   relaxing tail that overlaps into chord-like ringouts.
PATCH_TWINKLE:
    dc.b    $05                     ; FB/ALG: FB 0, ALG 5
    dc.b    $02,$11,$01,$51         ; DT/MUL — slot order op1,op3,op2,op4
    dc.b    $1F,$1F,$1F,$1F         ; RS/AR — instant attack
    dc.b    $00,$03,$03,$03         ; AM/D1R — mod sustained, carriers gentle decay
    dc.b    $00,$00,$00,$00         ; D2R
    dc.b    $48,$36,$36,$26         ; DL/RR — long shimmery tail
    dc.b    $24,$14,$14,$14         ; TL — mod gentle ($24), carriers bright ($14)
    even

;==============================================================================
; midi_blob — compiled MIDI event blob (incbin'd from out/midi_data.bin)
;==============================================================================
    xdef    midi_blob
    even
midi_blob:
    incbin  "out/midi_data.bin"
    even
