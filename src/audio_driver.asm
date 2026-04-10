    include "data/music_blob.inc"

;==============================================================================
; audio_driver.asm — YM2612 + PSG driver for NES APU emulation
;
; Maps NES APU channels to Genesis sound hardware using Sonic 2 Emerald Hill
; Zone FM patches:
;   Pulse 1 → YM2612 ch 0 (EHZ Voice $00, Algorithm 7)
;   Pulse 2 → YM2612 ch 1 (EHZ Voice $03, Algorithm 5)
;   Triangle → YM2612 ch 2 (EHZ Voice $07, Algorithm 0)
;   Noise   → SN76489 PSG ch 3
;
; Include BEFORE nes_io.asm so helpers are available to APU stubs.
;==============================================================================

;----------------------------------------------------------------------
; Hardware ports
;----------------------------------------------------------------------
YM_ADDR1        equ $A04000     ; YM2612 Part I address
YM_DATA1        equ $A04001     ; YM2612 Part I data
PSG_PORT        equ $C00011     ; SN76489 PSG data

;----------------------------------------------------------------------
; Shadow APU registers ($FF0A00–$FF0A15)
; Clear of NES RAM ($FF0000-$FF07FF), PPU/MMC1 ($FF0800-$FF083F),
; H-int queue ($FF0816-$FF081F), forensics ($FF0900-$FF0943).
;----------------------------------------------------------------------
APU_SH_BASE     equ $FF0A00
APU_SH_4000     equ APU_SH_BASE+$00    ; Pulse 1 duty/volume
APU_SH_4001     equ APU_SH_BASE+$01    ; Pulse 1 sweep (unused)
APU_SH_4002     equ APU_SH_BASE+$02    ; Pulse 1 period low
APU_SH_4003     equ APU_SH_BASE+$03    ; Pulse 1 period high + length
APU_SH_4004     equ APU_SH_BASE+$04    ; Pulse 2 duty/volume
APU_SH_4005     equ APU_SH_BASE+$05    ; Pulse 2 sweep (unused)
APU_SH_4006     equ APU_SH_BASE+$06    ; Pulse 2 period low
APU_SH_4007     equ APU_SH_BASE+$07    ; Pulse 2 period high + length
APU_SH_4008     equ APU_SH_BASE+$08    ; Triangle linear counter
APU_SH_400A     equ APU_SH_BASE+$0A    ; Triangle period low
APU_SH_400B     equ APU_SH_BASE+$0B    ; Triangle period high + length
APU_SH_400C     equ APU_SH_BASE+$0C    ; Noise volume/envelope
APU_SH_400E     equ APU_SH_BASE+$0E    ; Noise mode + period
APU_SH_400F     equ APU_SH_BASE+$0F    ; Noise length counter
APU_SH_4015     equ APU_SH_BASE+$10    ; Channel enable flags

;----------------------------------------------------------------------
; Frequency conversion constants
;
; NES pulse:    f = CPU_CLK / (16 * (P+1)),   CPU_CLK = 1,789,773
; NES triangle: f = CPU_CLK / (32 * (P+1))    (one octave lower)
; YM2612:       f = (F_num * 2^block * YM_CLK) / (144 * 2^20)
;                   YM_CLK = 7,670,453
;
; K_pulse = CPU_CLK * 144 * 2^20 / (16 * YM_CLK) = 2,201,710
; K5_pulse = K_pulse >> 5 = 68,803   (base block = 5)
; K5_tri   = K5_pulse / 2 = 34,401
;----------------------------------------------------------------------
NES_YM_K5_PULSE equ 68803
NES_YM_K5_TRI   equ 34401

;==============================================================================
; ym_write1 — Write one register to YM2612 Part I
;
; Input:  D0.b = register address
;         D1.b = data value
; Output: none
; Preserves: all registers
;==============================================================================
ym_write1:
.wait:
    tst.b   (YM_ADDR1).l            ; bit 7 = busy flag
    bmi.s   .wait
    move.b  D0,(YM_ADDR1).l         ; write register address
    nop                              ; address setup delay
    nop
    nop
    move.b  D1,(YM_DATA1).l         ; write data
    rts

;==============================================================================
; nes_to_ym_freq — Convert NES 11-bit period to YM2612 frequency
;
; Input:  D2.w = 11-bit NES period (0–2047)
;         D3.l = K constant (NES_YM_K5_PULSE or NES_YM_K5_TRI)
; Output: D2.b = A4 register value (block<<3 | F_num bits 10:8)
;         D3.b = A0 register value (F_num bits 7:0)
; Destroys: D4, D5
;==============================================================================
nes_to_ym_freq:
    addq.w  #1,D2                   ; D2 = P + 1
    cmp.w   #2,D2
    blo.s   .silence                ; period 0 → silence
    divu    D2,D3                   ; D3.l / D2.w → quotient in D3.w
    bvs.s   .silence                ; overflow safety
    move.w  D3,D5                   ; D5 = raw quotient = F_num at block 5
    moveq   #5,D4                   ; starting block (K was pre-shifted by 5)
.norm:
    cmp.w   #2047,D5
    bls.s   .done                   ; F_num fits in 11 bits
    lsr.w   #1,D5                   ; halve F_num
    addq.b  #1,D4                   ; increment block
    cmp.b   #7,D4
    bhi.s   .clamp                  ; block overflow → clamp
    bra.s   .norm
.done:
    ; D5.w = F_num (0–2047), D4.b = block (0–7)
    move.b  D4,D2
    lsl.b   #3,D2                   ; block << 3
    move.w  D5,D3
    lsr.w   #8,D3                   ; F_num >> 8 = high 3 bits
    or.b    D3,D2                   ; D2.b = (block<<3) | F_num_high
    move.b  D5,D3                   ; D3.b = F_num_low
    rts
.clamp:
    ; Frequency too high for YM2612 — clamp to max
    move.b  #$3F,D2                 ; block 7, F_num high = 7
    move.b  #$FF,D3                 ; F_num low = $FF → F_num = 2047
    rts
.silence:
    moveq   #0,D2
    moveq   #0,D3
    rts

;==============================================================================
; load_fm_patch — Load a 25-byte FM patch into a YM2612 channel
;
; Input:  A0 = pointer to 25-byte patch data
;         D6.b = channel (0, 1, or 2)
; Output: none
; Preserves: D0-D6, A0-A1 (saved/restored internally)
;==============================================================================
load_fm_patch:
    movem.l D0-D2/A0-A1,-(SP)
    lea     FM_PATCH_REGS(PC),A1
    moveq   #24,D2                  ; 25 register/value pairs
.loop:
    move.b  (A1)+,D0                ; register base address
    add.b   D6,D0                   ; + channel offset (0/1/2)
    move.b  (A0)+,D1                ; data value
    bsr     ym_write1
    dbra    D2,.loop
    movem.l (SP)+,D0-D2/A0-A1
    rts

;==============================================================================
; audio_init — Initialize YM2612 and PSG for NES audio emulation
;
; Called once during boot. Sets up FM patches and mutes all channels.
; Preserves: A4, A5, D7 (NES register shadows)
;==============================================================================
audio_init:
    movem.l D0-D6/A0,-(SP)

    ;------------------------------------------------------------------
    ; Key-off all 6 YM2612 channels
    ;------------------------------------------------------------------
    move.b  #$28,D0                 ; Key on/off register
    moveq   #0,D1
    bsr     ym_write1               ; ch 0 off
    move.b  #$01,D1
    bsr     ym_write1               ; ch 1 off
    move.b  #$02,D1
    bsr     ym_write1               ; ch 2 off
    move.b  #$04,D1
    bsr     ym_write1               ; ch 4 off (Part II)
    move.b  #$05,D1
    bsr     ym_write1               ; ch 5 off
    move.b  #$06,D1
    bsr     ym_write1               ; ch 6 off

    ;------------------------------------------------------------------
    ; Disable DAC (register $2B bit 7 = 0)
    ;------------------------------------------------------------------
    move.b  #$2B,D0
    moveq   #0,D1
    bsr     ym_write1

    ;------------------------------------------------------------------
    ; LFO off (register $22 = 0)
    ;------------------------------------------------------------------
    move.b  #$22,D0
    moveq   #0,D1
    bsr     ym_write1

    ;------------------------------------------------------------------
    ; Load EHZ Voice $00 into ch 0 (Pulse 1 — Algorithm 7, pad)
    ;------------------------------------------------------------------
    lea     PATCH_VOICE00(PC),A0
    moveq   #0,D6                   ; channel 0
    bsr     load_fm_patch

    ;------------------------------------------------------------------
    ; Load EHZ Voice $03 into ch 1 (Pulse 2 — Algorithm 5, lead)
    ;------------------------------------------------------------------
    lea     PATCH_VOICE03(PC),A0
    moveq   #1,D6                   ; channel 1
    bsr     load_fm_patch

    ;------------------------------------------------------------------
    ; Load EHZ Voice $07 into ch 2 (Triangle — Algorithm 0, bass)
    ;------------------------------------------------------------------
    lea     PATCH_VOICE07(PC),A0
    moveq   #2,D6                   ; channel 2
    bsr     load_fm_patch

    ;------------------------------------------------------------------
    ; Set panning: both speakers for ch 0–2
    ; Register $B4+ch, data $C0 = L+R output
    ;------------------------------------------------------------------
    move.b  #$B4,D0
    move.b  #$C0,D1
    bsr     ym_write1               ; ch 0 panning
    move.b  #$B5,D0
    bsr     ym_write1               ; ch 1 panning
    move.b  #$B6,D0
    bsr     ym_write1               ; ch 2 panning

    ;------------------------------------------------------------------
    ; Mute all 4 PSG channels (attenuation = $F = maximum)
    ;------------------------------------------------------------------
    move.b  #$9F,(PSG_PORT).l       ; Tone 1 mute
    move.b  #$BF,(PSG_PORT).l       ; Tone 2 mute
    move.b  #$DF,(PSG_PORT).l       ; Tone 3 mute
    move.b  #$FF,(PSG_PORT).l       ; Noise mute

    ;------------------------------------------------------------------
    ; Clear shadow APU registers
    ;------------------------------------------------------------------
    lea     (APU_SH_BASE).l,A0
    moveq   #($11/2),D0            ; 18 bytes / 2 = 9 words (round up)
.clr:
    clr.w   (A0)+
    dbra    D0,.clr

    ;------------------------------------------------------------------
    ; Clear native music player state
    ;------------------------------------------------------------------
    lea     (MUSIC_BASE).l,A0
    moveq   #(MUSIC_STATE_SIZE/4)-1,D0
.clr_music:
    clr.l   (A0)+
    dbra    D0,.clr_music

    movem.l (SP)+,D0-D6/A0
    rts

;==============================================================================
; FM Patch Register Address Table
;
; 25 register base addresses (add channel 0/1/2 for target channel).
; Order matches the 25 data bytes in each PATCH_VOICExx block.
;==============================================================================
    even
FM_PATCH_REGS:
    dc.b    $B0                     ; FB/ALG
    dc.b    $30,$34,$38,$3C         ; DT1/MUL (slot1,slot3,slot2,slot4)
    dc.b    $50,$54,$58,$5C         ; RS/AR
    dc.b    $60,$64,$68,$6C         ; AM/D1R
    dc.b    $70,$74,$78,$7C         ; D2R
    dc.b    $80,$84,$88,$8C         ; DL/RR
    dc.b    $40,$44,$48,$4C         ; TL
    even

;==============================================================================
; FM Patch Data — Sonic 2 Emerald Hill Zone voices
;
; 25 bytes each in YM2612 slot order: slot1(SMPS op4), slot3(op2),
; slot2(op3), slot4(op1).  Matches FM_PATCH_REGS register sequence.
;==============================================================================

; Voice $00 — EHZ FM5 opening voice (warm pad)
; Algorithm 7 (all 4 ops are carriers), Feedback 0
PATCH_VOICE00:
    dc.b    $07                     ; FB/ALG: (0<<3)|7
    dc.b    $05,$01,$00,$02         ; DT/MUL
    dc.b    $1F,$1F,$1F,$1F         ; RS/AR
    dc.b    $0E,$0E,$0E,$0E         ; AM/D1R
    dc.b    $02,$02,$02,$02         ; D2R
    dc.b    $55,$55,$55,$54         ; DL/RR
    dc.b    $00,$00,$00,$00         ; TL (all carriers at max)
    even

; Voice $03 — EHZ FM3 opening voice (iconic lead)
; Algorithm 5 (slots 2,3,4 are carriers), Feedback 7
PATCH_VOICE03:
    dc.b    $3D                     ; FB/ALG: (7<<3)|5
    dc.b    $01,$51,$21,$01         ; DT/MUL
    dc.b    $12,$14,$14,$0F         ; RS/AR
    dc.b    $0A,$05,$05,$05         ; AM/D1R
    dc.b    $00,$00,$00,$00         ; D2R
    dc.b    $2B,$2B,$2B,$1B         ; DL/RR
    dc.b    $19,$00,$00,$00         ; TL (slot1=mod $19, rest=carrier $00)
    even

; Voice $07 — EHZ FM1 bass voice
; Algorithm 0 (only slot 4 is carrier), Feedback 1
PATCH_VOICE07:
    dc.b    $08                     ; FB/ALG: (1<<3)|0
    dc.b    $0A,$30,$70,$00         ; DT/MUL
    dc.b    $1F,$5F,$1F,$5F         ; RS/AR
    dc.b    $12,$0A,$0E,$0A         ; AM/D1R
    dc.b    $00,$04,$04,$03         ; D2R
    dc.b    $2F,$2F,$2F,$2F         ; DL/RR
    dc.b    $24,$13,$2D,$00         ; TL (slot4=carrier $00, rest=modulators)
    even

;==============================================================================
;==============================================================================
; NATIVE M68K MUSIC PLAYER
;
; Ports the NES Zelda DriveSong engine verbatim, reading the same script
; opcodes but emitting YM2612/PSG writes instead of NES APU writes.
;
; State lives at $FF0B00.  Song data is pulled from the contiguous
; MusicBlob (SongTable + 9 song headers + 9 song scripts, 2757 bytes)
; loaded at label MusicBlob.  NES CPU addresses in song headers are
; converted to M68K pointers via (nes_addr - MUSIC_BLOB_NES_BASE) + MusicBlob.
;==============================================================================
;==============================================================================

;----------------------------------------------------------------------
; Music state RAM ($FF0B00-$FF0B3F, 64 bytes)
;----------------------------------------------------------------------
MUSIC_BASE          equ $FF0B00
MUSIC_STATE_SIZE    equ $40

m_song              equ MUSIC_BASE+$00  ; current song bitmap
m_song_req          equ MUSIC_BASE+$01  ; requested song change
m_phrase            equ MUSIC_BASE+$02  ; current phrase index
m_len_base          equ MUSIC_BASE+$03  ; note length table base
m_env_sel           equ MUSIC_BASE+$04  ; envelope selector
m_mystery           equ MUSIC_BASE+$05  ; header byte 7 ($05F1 equiv)
m_noise_first       equ MUSIC_BASE+$06  ; noise loop start
m_script_ptr        equ MUSIC_BASE+$08  ; long: M68K pointer to script base

; Sq1 (Pulse 1 → YM ch 0)
m_sq1_off           equ MUSIC_BASE+$0C
m_sq1_cnt           equ MUSIC_BASE+$0D
m_sq1_len           equ MUSIC_BASE+$0E
m_sq1_vib           equ MUSIC_BASE+$0F
m_sq1_per           equ MUSIC_BASE+$10

; Sq0 (Pulse 2 → YM ch 1)
m_sq0_off           equ MUSIC_BASE+$14
m_sq0_cnt           equ MUSIC_BASE+$15
m_sq0_len           equ MUSIC_BASE+$16
m_sq0_vib           equ MUSIC_BASE+$17
m_sq0_per           equ MUSIC_BASE+$18

; Triangle (→ YM ch 2)
m_trg_off           equ MUSIC_BASE+$1C
m_trg_cnt           equ MUSIC_BASE+$1D
m_trg_len           equ MUSIC_BASE+$1E
m_trg_vib           equ MUSIC_BASE+$1F
m_trg_per           equ MUSIC_BASE+$20
m_trg_rep_n         equ MUSIC_BASE+$21
m_trg_rep_s         equ MUSIC_BASE+$22

; Noise (→ PSG ch 3)
m_noise_off         equ MUSIC_BASE+$24
m_noise_cnt         equ MUSIC_BASE+$25

;==============================================================================
; music_play — request a song change
; Input: D0.b = song bitmap
;==============================================================================
music_play:
    move.b  D0,(m_song_req).l
    rts

;==============================================================================
; music_tick — DriveSong equivalent.  Call once per VBlank.
;==============================================================================
music_tick:
    movem.l D0-D7/A0-A2,-(SP)
    move.b  (m_song_req).l,D0
    beq.s   .no_req
    clr.b   (m_song_req).l
    move.b  D0,(m_song).l
    bsr     change_song
    bra.s   .done
.no_req:
    tst.b   (m_song).l
    beq.s   .done
    bsr     tick_sq1
.done:
    movem.l (SP)+,D0-D7/A0-A2
    rts

;==============================================================================
; change_song — ported from @ChangeSong
; Input: D0.b = new song bitmap (already stored in m_song)
;
; Selects the starting phrase index for the new song, then falls into
; prep_phrase / play_next_phrase to begin playback.  Final step performs
; an immediate tick_sq1 (matching KeepPlayingSong fall-through).
;==============================================================================
change_song:
    tst.b   D0
    bmi.s   .first_demo                 ; bit 7 → demo/title
    cmp.b   #$06,D0
    bne.s   .not_zelda
    move.b  #$24,(m_phrase).l           ; zelda: phrase $24 directly
    bsr     prep_phrase
    bra     tick_sq1
.not_zelda:
    cmp.b   #$01,D0
    beq.s   .first_ow
    cmp.b   #$40,D0
    beq.s   .first_uw
    cmp.b   #$10,D0
    bne     play_next_phrase            ; single-phrase song
    move.b  #$11,(m_phrase).l           ; ending: SetPrev then fall into PlayNext
    bra     play_next_phrase
.first_ow:
    move.b  #$08,(m_phrase).l
    bra     play_next_phrase
.first_uw:
    move.b  #$0F,(m_phrase).l
    bra     play_next_phrase
.first_demo:
    move.b  #$19,(m_phrase).l
    bra     play_next_phrase

;==============================================================================
; play_next_phrase — ported from PlayNextPhrase
; Increments phrase index for multi-phrase songs (with wrap), then
; calls prep_phrase and falls into tick_sq1.
;==============================================================================
play_next_phrase:
    move.b  (m_song).l,D0
    bmi.s   .next_demo                  ; bit 7 → demo (multi)
    cmp.b   #$01,D0
    beq.s   .next_ow
    cmp.b   #$40,D0
    beq.s   .next_uw
    cmp.b   #$10,D0
    beq.s   .next_ending
    ; Single-phrase song: find bit position, phrase = index
    moveq   #0,D1
    moveq   #0,D2
    move.b  D0,D2
.bitloop:
    addq.b  #1,D1
    lsr.b   #1,D2
    bcc.s   .bitloop
    move.b  D1,(m_phrase).l
    bsr     prep_phrase
    bra     tick_sq1
.next_ending:
    addq.b  #1,(m_phrase).l
    cmpi.b  #$1A,(m_phrase).l
    bne.s   .prep_and_tick
    move.b  #$14,(m_phrase).l
    bra     play_next_phrase
.next_uw:
    addq.b  #1,(m_phrase).l
    cmpi.b  #$12,(m_phrase).l
    bne.s   .prep_and_tick
    move.b  #$0F,(m_phrase).l
    bra     play_next_phrase
.next_ow:
    addq.b  #1,(m_phrase).l
    cmpi.b  #$10,(m_phrase).l
    bne.s   .prep_and_tick
    move.b  #$09,(m_phrase).l
    bra     play_next_phrase
.next_demo:
    addq.b  #1,(m_phrase).l
    cmpi.b  #$24,(m_phrase).l
    bne.s   .prep_and_tick
    move.b  #$19,(m_phrase).l
    bra     play_next_phrase
.prep_and_tick:
    bsr     prep_phrase
    bra     tick_sq1

;==============================================================================
; prep_phrase — ported from PrepPhrase
; Reads 8-byte header at MusicBlob[MusicBlob[m_phrase-1]].
;==============================================================================
prep_phrase:
    lea     (MusicBlob).l,A1
    moveq   #0,D1
    move.b  (m_phrase).l,D1
    subq.w  #1,D1
    move.b  (A1,D1.w),D1                ; indirect: inner index
    andi.w  #$FF,D1

    ; byte 0: NoteLengthTableBase
    move.b  (A1,D1.w),(m_len_base).l
    addq.w  #1,D1
    ; byte 1: script ptr lo
    moveq   #0,D2
    move.b  (A1,D1.w),D2
    addq.w  #1,D1
    ; byte 2: script ptr hi
    moveq   #0,D3
    move.b  (A1,D1.w),D3
    addq.w  #1,D1
    lsl.w   #8,D3
    or.w    D2,D3                        ; D3 = NES CPU address
    sub.w   #MUSIC_BLOB_NES_BASE,D3
    andi.l  #$FFFF,D3
    lea     (MusicBlob).l,A0
    adda.l  D3,A0                        ; A0 = M68K script base
    move.l  A0,(m_script_ptr).l

    ; byte 3: NoteOffsetSongTrg
    move.b  (A1,D1.w),(m_trg_off).l
    addq.w  #1,D1
    ; byte 4: NoteOffsetSongSq0
    move.b  (A1,D1.w),(m_sq0_off).l
    addq.w  #1,D1
    ; byte 5: NoteOffsetSongNoise (also FirstNoiseIdx)
    move.b  (A1,D1.w),(m_noise_off).l
    move.b  (A1,D1.w),(m_noise_first).l
    addq.w  #1,D1
    ; byte 6: SongEnvelopeSelector
    move.b  (A1,D1.w),(m_env_sel).l
    addq.w  #1,D1
    ; byte 7: mystery
    move.b  (A1,D1.w),(m_mystery).l

    ; Reset counters and Sq1 offset
    move.b  #1,(m_sq1_cnt).l
    move.b  #1,(m_sq0_cnt).l
    move.b  #1,(m_trg_cnt).l
    move.b  #1,(m_noise_cnt).l
    clr.b   (m_sq1_off).l
    clr.b   (m_trg_rep_n).l
    rts

;==============================================================================
; tick_sq1 — Sq1 channel update (primary: owns phrase advance on song-end)
;==============================================================================
tick_sq1:
    subq.b  #1,(m_sq1_cnt).l
    bne     tick_sq0                     ; no new note
.read:
    move.l  (m_script_ptr).l,A0
    moveq   #0,D1
    move.b  (m_sq1_off).l,D1
    addq.b  #1,(m_sq1_off).l
    move.b  (A0,D1.w),D0
    beq.s   .song_ended
    tst.b   D0
    bmi.s   .prep_then_note              ; bit 7 set → control byte
    bra.s   .play_note
.prep_then_note:
    bsr     get_song_note_length         ; D0 in → D0 length
    move.b  D0,(m_sq1_len).l
    move.l  (m_script_ptr).l,A0
    moveq   #0,D1
    move.b  (m_sq1_off).l,D1
    addq.b  #1,(m_sq1_off).l
    move.b  (A0,D1.w),D0
.play_note:
    bsr     emit_note_sq1                 ; D0 = note id
    move.b  (m_sq1_len).l,(m_sq1_cnt).l
    bra     tick_sq0
.song_ended:
    move.b  (m_song).l,D0
    andi.b  #$F1,D0
    bne.s   .play_again
    bra     music_silence
.play_again:
    bsr     play_next_phrase_no_tick
    bra.s   .read

;----------------------------------------------------------------------
; play_next_phrase_no_tick — variant that ends with rts (via prep_phrase
; tail call) instead of falling into tick_sq1.  Used from inside tick_sq1
; to restart a looping song when $00 opcode is read.
;----------------------------------------------------------------------
play_next_phrase_no_tick:
    move.b  (m_song).l,D0
    bmi     .nsp_demo
    cmp.b   #$01,D0
    beq     .nsp_ow
    cmp.b   #$40,D0
    beq     .nsp_uw
    cmp.b   #$10,D0
    beq     .nsp_ending
    ; single-phrase: rebuild phrase from bit
    moveq   #0,D1
    moveq   #0,D2
    move.b  D0,D2
.nsp_loop:
    addq.b  #1,D1
    lsr.b   #1,D2
    bcc     .nsp_loop
    move.b  D1,(m_phrase).l
    bra     prep_phrase
.nsp_ending:
    addq.b  #1,(m_phrase).l
    cmpi.b  #$1A,(m_phrase).l
    bne     prep_phrase
    move.b  #$14,(m_phrase).l
    bra     prep_phrase
.nsp_uw:
    addq.b  #1,(m_phrase).l
    cmpi.b  #$12,(m_phrase).l
    bne     prep_phrase
    move.b  #$0F,(m_phrase).l
    bra     prep_phrase
.nsp_ow:
    addq.b  #1,(m_phrase).l
    cmpi.b  #$10,(m_phrase).l
    bne     prep_phrase
    move.b  #$09,(m_phrase).l
    bra     prep_phrase
.nsp_demo:
    addq.b  #1,(m_phrase).l
    cmpi.b  #$24,(m_phrase).l
    bne     prep_phrase
    move.b  #$19,(m_phrase).l
    bra     prep_phrase

;==============================================================================
; tick_sq0 — Sq0 channel update
;==============================================================================
tick_sq0:
    tst.b   (m_sq0_off).l                 ; if starting offset 0 → channel off
    beq     tick_trg
    subq.b  #1,(m_sq0_cnt).l
    bne     tick_trg
    move.l  (m_script_ptr).l,A0
    moveq   #0,D1
    move.b  (m_sq0_off).l,D1
    addq.b  #1,(m_sq0_off).l
    move.b  (A0,D1.w),D0
    tst.b   D0
    bpl.s   .play
    bsr     get_song_note_length
    move.b  D0,(m_sq0_len).l
    move.l  (m_script_ptr).l,A0
    moveq   #0,D1
    move.b  (m_sq0_off).l,D1
    addq.b  #1,(m_sq0_off).l
    move.b  (A0,D1.w),D0
.play:
    bsr     emit_note_sq0
    move.b  (m_sq0_len).l,(m_sq0_cnt).l
    bra     tick_trg

;==============================================================================
; tick_trg — Triangle channel update (handles $F0/$F1-$FF passage ops)
;==============================================================================
tick_trg:
    tst.b   (m_trg_off).l
    beq     tick_noise
    subq.b  #1,(m_trg_cnt).l
    bne     tick_noise
.prep_note_or_passage:
    move.l  (m_script_ptr).l,A0
    moveq   #0,D1
    move.b  (m_trg_off).l,D1
    addq.b  #1,(m_trg_off).l
    move.b  (A0,D1.w),D0
    beq.s   .silence_trg                  ; $00 → silence triangle this step
    tst.b   D0
    bpl.s   .play_note_trg                ; direct note
    cmpi.b  #$F0,D0
    beq.s   .end_of_passage
    bcs.s   .prep_note_trg                ; $80-$EF → control
    ; $F1-$FF → start passage
    subi.b  #$F0,D0
    move.b  D0,(m_trg_rep_n).l
    move.b  (m_trg_off).l,(m_trg_rep_s).l
    bra.s   .prep_note_or_passage
.end_of_passage:
    subq.b  #1,(m_trg_rep_n).l
    beq.s   .pass_done
    move.b  (m_trg_rep_s).l,(m_trg_off).l
.pass_done:
    bra.s   .prep_note_or_passage
.prep_note_trg:
    bsr     get_song_note_length
    move.b  D0,(m_trg_len).l
    move.l  (m_script_ptr).l,A0
    moveq   #0,D1
    move.b  (m_trg_off).l,D1
    addq.b  #1,(m_trg_off).l
    move.b  (A0,D1.w),D0
    beq.s   .silence_trg
.play_note_trg:
    bsr     emit_note_trg
    move.b  (m_trg_len).l,(m_trg_cnt).l
    bra     tick_noise
.silence_trg:
    bsr     key_off_trg
    move.b  (m_trg_len).l,(m_trg_cnt).l
    bra     tick_noise

;==============================================================================
; tick_noise — PSG noise channel (demo/ending/overworld only)
;==============================================================================
tick_noise:
    move.b  (m_song).l,D0
    andi.b  #$91,D0
    beq     .tn_done
    subq.b  #1,(m_noise_cnt).l
    bne     .tn_done
.read:
    move.l  (m_script_ptr).l,A0
    moveq   #0,D1
    move.b  (m_noise_off).l,D1
    addq.b  #1,(m_noise_off).l
    move.b  (A0,D1.w),D0
    bne.s   .got
    move.b  (m_noise_first).l,(m_noise_off).l
    bra.s   .read
.got:
    move.b  D0,D4                         ; preserve control note for length calc
    ; Length via GetSongNoiseNoteLength: rotate control note bits then AND #$07
    ; Original: ROR (through C), ROL, ROL, ROL, AND #$07, ADC NoteLengthTableBase
    ; Net effect: reorders to "low 3 bits of rotated" which is bits (2,1,0) ←
    ; (0,7,6). For our port we replicate exactly.
    moveq   #0,D2
    move.b  D4,D2
    ; We need bit0→2, bit7→1, bit6→0 of the original → into D0 bits 2,1,0.
    moveq   #0,D0
    btst    #0,D2
    beq.s   .b0
    bset    #2,D0
.b0:
    btst    #7,D2
    beq.s   .b7
    bset    #1,D0
.b7:
    btst    #6,D2
    beq.s   .b6
    bset    #0,D0
.b6:
    moveq   #0,D1
    move.b  (m_len_base).l,D1
    add.w   D0,D1
    lea     (NoteLengthTables).l,A1
    move.b  (A1,D1.w),(m_noise_cnt).l
    ; Extract index 0-3: (note AND #$3E) >> 4
    move.b  D4,D0
    andi.b  #$3E,D0
    lsr.b   #4,D0
    moveq   #0,D1
    move.b  D0,D1
    ; Map to PSG noise: set volume + period
    bsr     set_psg_noise
.tn_done:
    rts

;==============================================================================
; get_song_note_length — equivalent to GetSongNoteLength
; Input: D0 = control byte → Output: D0 = length
;==============================================================================
get_song_note_length:
    andi.w  #$07,D0
    moveq   #0,D1
    move.b  (m_len_base).l,D1
    add.w   D0,D1
    lea     (NoteLengthTables).l,A1
    move.b  (A1,D1.w),D0
    rts

;==============================================================================
; emit_note_sq1 — Play a note on YM ch 0 (Pulse 1 slot)
; Input: D0.b = note id (even byte offset into MusicNotePeriodTable)
;==============================================================================
emit_note_sq1:
    andi.w  #$FF,D0
    lea     (MusicNotePeriodTable).l,A1
    moveq   #0,D2
    move.b  1(A1,D0.w),D2                 ; lo
    beq     key_off_sq1                    ; lo=0 → rest → key off
    moveq   #0,D3
    move.b  0(A1,D0.w),D3                 ; hi
    lsl.w   #8,D3
    or.w    D2,D3                          ; D3.w = period
    andi.w  #$07FF,D3
    move.b  D2,(m_sq1_per).l              ; save low period for vibrato
    move.w  D3,D2
    move.l  #NES_YM_K5_PULSE,D3
    bsr     nes_to_ym_freq                ; D2=A4val, D3=A0val
    move.b  #$A4,D0                        ; ch 0
    move.b  D2,D1
    bsr     ym_write1
    move.b  #$A0,D0
    move.b  D3,D1
    bsr     ym_write1
    ; Key on ch 0, all ops
    move.b  #$28,D0
    move.b  #$F0,D1
    bra     ym_write1

;==============================================================================
; emit_note_sq0 — Play a note on YM ch 1 (Pulse 2 slot)
;==============================================================================
emit_note_sq0:
    andi.w  #$FF,D0
    lea     (MusicNotePeriodTable).l,A1
    moveq   #0,D2
    move.b  1(A1,D0.w),D2
    beq     key_off_sq0
    moveq   #0,D3
    move.b  0(A1,D0.w),D3
    lsl.w   #8,D3
    or.w    D2,D3
    andi.w  #$07FF,D3
    move.b  D2,(m_sq0_per).l
    move.w  D3,D2
    move.l  #NES_YM_K5_PULSE,D3
    bsr     nes_to_ym_freq
    move.b  #$A5,D0                        ; ch 1
    move.b  D2,D1
    bsr     ym_write1
    move.b  #$A1,D0
    move.b  D3,D1
    bsr     ym_write1
    move.b  #$28,D0
    move.b  #$F1,D1
    bra     ym_write1

;==============================================================================
; emit_note_trg — Play a note on YM ch 2 (triangle slot, octave lower)
;==============================================================================
emit_note_trg:
    andi.w  #$FF,D0
    lea     (MusicNotePeriodTable).l,A1
    moveq   #0,D2
    move.b  1(A1,D0.w),D2
    beq     key_off_trg
    moveq   #0,D3
    move.b  0(A1,D0.w),D3
    lsl.w   #8,D3
    or.w    D2,D3
    andi.w  #$07FF,D3
    move.b  D2,(m_trg_per).l
    move.w  D3,D2
    move.l  #NES_YM_K5_TRI,D3
    bsr     nes_to_ym_freq
    move.b  #$A6,D0                        ; ch 2
    move.b  D2,D1
    bsr     ym_write1
    move.b  #$A2,D0
    move.b  D3,D1
    bsr     ym_write1
    move.b  #$28,D0
    move.b  #$F2,D1
    bra     ym_write1

;==============================================================================
; key_off_{sq1,sq0,trg} — silence the channel without reloading freq
;==============================================================================
key_off_sq1:
    move.b  #$28,D0
    move.b  #$00,D1
    bra     ym_write1
key_off_sq0:
    move.b  #$28,D0
    move.b  #$01,D1
    bra     ym_write1
key_off_trg:
    move.b  #$28,D0
    move.b  #$02,D1
    bra     ym_write1

;==============================================================================
; set_psg_noise — Program PSG noise channel
; Input: D1.w = noise index 0-3 (into NoiseVolumes/Periods/Lengths)
;==============================================================================
set_psg_noise:
    lea     (NoiseVolumesTbl).l,A1
    move.b  (A1,D1.w),D0                   ; NES noise "volume" ($10/$1C/$1C/$1C)
    ; Bits 3:0 of $400C = volume. We translate to PSG attenuation:
    ; atten = 15 - (vol & $0F).  $10→0 (off), $1C→$F-$C=$3, etc.
    andi.b  #$0F,D0
    neg.b   D0
    addi.b  #$0F,D0
    andi.b  #$0F,D0
    ori.b   #$F0,D0                        ; PSG noise atten latch
    move.b  D0,(PSG_PORT).l
    ; Set noise mode/period: bit 2 = mode (1=periodic), bits 1:0 = shift rate
    lea     (NoisePeriodsTbl).l,A1
    move.b  (A1,D1.w),D0
    andi.b  #$07,D0
    ori.b   #$E0,D0                        ; PSG noise control latch
    move.b  D0,(PSG_PORT).l
    rts

;==============================================================================
; music_silence — Full silence: key-off all channels, clear song state
;==============================================================================
music_silence:
    clr.b   (m_song).l
    bsr     key_off_sq1
    bsr     key_off_sq0
    bsr     key_off_trg
    move.b  #$FF,(PSG_PORT).l              ; PSG noise mute
    rts

;==============================================================================
; Music data tables
;==============================================================================
    even

; MusicNotePeriodTable — 114 bytes, big-endian 16-bit periods indexed by
; even note IDs (byte offsets).  Pulled from reference Z_00.asm.
; (Local copy to avoid label collision with the transpiled MusicNotePeriodTable
; in zelda_translated/z_00.asm, whose in-memory layout may have `even`
; padding that breaks offset math.)
MusicNotePeriodTable:
    dc.b    $00,$23,$00,$6A,$03,$27,$00,$97
    dc.b    $00,$00,$02,$F9,$02,$CF,$02,$A6
    dc.b    $02,$80,$02,$5C,$02,$3A,$02,$1A
    dc.b    $01,$FC,$01,$DF,$01,$C4,$01,$AB
    dc.b    $01,$93,$01,$7C,$01,$67,$01,$53
    dc.b    $01,$40,$01,$2E,$01,$1D,$01,$0D
    dc.b    $00,$FE,$00,$EF,$00,$E2,$00,$D5
    dc.b    $00,$C9,$00,$BE,$00,$B3,$00,$A9
    dc.b    $00,$A0,$00,$8E,$00,$86,$00,$77
    dc.b    $00,$7E,$00,$71,$00,$54,$00,$64
    dc.b    $00,$5F,$00,$59,$00,$50,$00,$47
    dc.b    $00,$43,$00,$3F,$00,$38,$00,$32
    dc.b    $00,$21,$05,$4D,$05,$01,$04,$B9
    dc.b    $04,$35,$03,$F8,$03,$BF,$03,$89
    dc.b    $03,$57
    even

; NoteLengthTables — 5x 8-byte tables concatenated (40 bytes).
NoteLengthTables:
    dc.b    $03,$0A,$01,$14,$05,$28,$3C,$70  ; table 0
    dc.b    $07,$1B,$35,$14,$0D,$28,$3C,$50  ; table 1
    dc.b    $06,$0C,$08,$18,$24,$30,$48,$10  ; table 2
    dc.b    $07,$0D,$09,$1B,$24,$36,$48,$10  ; table 3
    dc.b    $3C,$50,$0A,$05,$14,$0D,$28,$0E  ; table 4
    even

NoiseVolumesTbl:
    dc.b    $10,$1C,$1C,$1C
NoisePeriodsTbl:
    dc.b    $00,$03,$0A,$03
NoiseLengthsTbl:
    dc.b    $00,$18,$18,$58
    even

;==============================================================================
; MusicBlob — SongTable + 9 song headers + 9 song scripts (2757 bytes)
; Pulled verbatim from PRG bank 0 at NES $8D60.
;==============================================================================
MusicBlob:
    incbin  "data/music_blob.dat"
    even
