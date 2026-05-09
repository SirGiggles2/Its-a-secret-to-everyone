# Phase 7 Task 7.2 step 11 — native enrt_update_darknut + $0B/$0C wiring

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_04.asm:6474 UpdateDarknut`
                  + `reference/aldonunez/Z_07.asm:5116`
                    `Anim_AdvanceAnimCounterAndSetObjPosForSpriteDescriptor`
- **Drained C**:  `src/oracle/enemies/enemy_walker_runtime.c::enrt_update_darknut`
                  (NEW step 11; sibling to existing `enrt_update_stalfos`).
                  Wired in `src/game/enemies/enemy_loop.c` rows
                  `enemy_update_fns[$0B]` / `[$0C]`.
- **Coverage**:   FULL — UpdateDarknut body translated line-by-line.
                  No deferrals. (UpdateCommonWanderer + CheckMonsterCollisions
                  already drained.)
- **Stance**:     EXTEND — INIT side (`enrt_init_darknut`) already drained
                  + wired (step 7); only the UPDATE row was missing.

## What NES does (Z_04.asm:6474-6514)

```asm
UpdateDarknut:
    LDA #$80                              ; turn rate $80
    JSR UpdateCommonWanderer
    JSR CheckMonsterCollisions
    LDA #$00 / STA ObjStunTimer, X        ; never stunned
    LDA #$08 / JSR Anim_Advance...        ; advance anim, A=0 on return
    LDA ObjDir, X / CMP #$02 / BNE :+
    INC $0F                               ; hflip if facing left
:
    LSR / LSR                             ; 2 up, 1 down, 0 horizontal
    LDY ObjAnimFrame, X / BEQ :+
    CLC / ADC #$03                        ; frame 1 = base + 3
    LDY ObjDir, X / CPY #$08 / BNE :+
    INC $0F                               ; hflip if up + frame 1
:
    JSR DrawObjectNotMirrored
    RTS
```

Custom frame derivation: base = `dir >> 2` (2 up, 1 down, 0 horizontal),
plus 3 if `ObjAnimFrame != 0`, with conditional hflip based on (dir,
frame). Cannot reuse `enrt_animate_and_draw_common_object` because that
helper always passes frame=0 to the draw call.

## Drained C (added at enemy_walker_runtime.c)

```c
void enrt_update_darknut(unsigned int slot) {
    enrt_update_common_wanderer(0x80u, slot);
    c_check_monster_collisions(slot);
    ENEMY_STUN_TIMER(slot) = 0u;
    z07_anim_advance_and_fetch(8u, slot);

    unsigned char dir = (unsigned char)ENEMY_DIR(slot);

    if (dir == 0x02u)
        RAM(0x000F) = (unsigned char)(RAM(0x000F) + 1u);

    unsigned char frame = (unsigned char)(dir >> 2);

    if (ENEMY_DRAW_FRAME(slot) != 0u) {
        frame = (unsigned char)(frame + 3u);
        if (dir == 0x08u)
            RAM(0x000F) = (unsigned char)(RAM(0x000F) + 1u);
    }

    c_draw_object_not_mirrored_with_frame((unsigned int)frame, slot);
}
```

## Probe extension

Multi-slot probe block at `$FF7F80` extended from 4 → 5 slots.
Slot 5 seeded `enemy_loop_force_spawn_typed(5, $0B, $C0, $A0, 0)`
(BlueDarknut at 192, 160). Boot probe `alive_after` expectation
bumped 4 → 5 (check[1]).

`tools/debug/probes/probe_walker_tick_trace.lua` now reads slot 5
with two new gates:
- G11: slot 5 type=$0B alive+type held
- G12: darknut (slot 5) X or Y advanced

## Verification — 12/12 PASS

```
slot 1 type=$07 alive 1->1 xy=(128,128)->(128,115) dir=$08 anim=5->4   draw=$03->$00 spd=$00->$20
slot 2 type=$03 alive 1->1 xy=( 64, 96)->( 51, 96) dir=$02 anim=1->1   draw=$00->$00 spd=$00->$20
slot 3 type=$05 alive 1->1 xy=( 55,160)->( 27,160) dir=$02 anim=1->1   draw=$00->$00 spd=$20->$20
slot 4 type=$2A alive 1->1 xy=(183, 96)->(155, 96) dir=$02 anim=6->7   draw=$01->$00 spd=$20->$20
slot 5 type=$0B alive 1->1 xy=(192,151)->(192,123) dir=$08 anim=6->7   draw=$01->$00 spd=$20->$20
>>> WALKER TICK TRACE: PASS <<<  G1..G12 ALL PASS
```

Darknut motion: (192,151) → (192,123), 28px Y delta in 120 frames.
Same magnitude as goriya/stalfos (28px) — consistent with shared
walker quarter-speed $20 and the new native body advancing to the
draw call without crashing.

Slot 5 first-sample y=151 (not seed y=160) because force_spawn writes
ENEMY_Y=$A0 (160) but `clear_slot_scratch` runs first so the slot
already starts walking during the boot+settle frames before the
first trace sample. (Same effect as slots 3/4 in step 10.)

Slot 1 octorok regression unchanged from step 10 (G1-G6 same).
Slots 2-4 regression unchanged from step 10 (G7-G10 same).

## Master plan checklist progress

After step 11 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking      (step 6 native UPDATE)
- [x] moblin walking       (step 7 dispatch + step 9 shoot loop unblock)
- [x] stalfos walking      (step 10 default WALK_SPEED)
- [x] goriya walking       (step 10 default WALK_SPEED)
- [x] darknut walking      (step 11 native UPDATE — THIS STEP)
- [x] projectile hook      (step 9 c_shoot_if_wanted native, partial —
                            shot UPDATE rows still NULL)
- [ ] probe movement+collision  (movement done; collision via
                                 c_check_monster_collisions exists,
                                 needs probe extension)
- [ ] probe damage+death+drop   (combat hook not wired)
- [ ] commit family             (final phase commit)

5 of 9 walker-family checklist items done. All five primary walker
types ($07-$0A octorok, $03/$04 moblin, $05/$06 goriya, $0B/$0C
darknut, $2A stalfos) tick + advance position deterministically.

## Rolled-forward TODOs

- Central post-dispatch animate/draw hook (or extend bare bodies) —
  goriya/moblin still don't draw sprites.
- Walker_CheckTileCollision (room tile registry).
- Lynel ($01/$02) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring (drains exist, just need rows).
- Shot UPDATE rows ($53 flying rock, $5B arrow, $57 sword shot, $5C
  boomerang) + DestroyMonsterShot decrement of ENEMY_SHOT_COUNT.
- `c_obj_shove` native (combat damage hook) — still stubbed.
- Probe extension for c_check_monster_collisions outcomes (would
  cover the "probe movement+collision" checklist row).
