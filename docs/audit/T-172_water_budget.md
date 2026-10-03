# T-172 — water scene budget and VBlank synchronization

- **NES source:** `Z_01.asm:FormatHeartsInTextBuf`, `BoundDirectionHorizontally/Vertically`, `AddQSpeedToPositionFraction/SubQSpeedFromPositionFraction`; `Z_07.asm:MoveObject` and NMI frame work. SGDK pinned source: `sgdk/src/sys.c:SYS_doVBlankProcessEx`, `sgdk/src/vdp.c:VDP_waitVBlank`.
- **Drained C:** `src/game/hud/hud_dispatch.c:hud_heart_tile`; `src/oracle/world/object_runtime.c:objrt_move_object` and bounds helpers; existing native renderer/host (no renderer drain candidate).
- **Coverage:** PARTIAL: named water scene and shared consumers. Wider scene budgets/connected progression remain open.
- **Stance:** EXTEND existing cache, arithmetic and frame synchronization; preserve NES state owners.

## 1. Problem and captured evidence

T-056 frozen2307636A completed610 OW ladder ticks with61 extra video-frame stalls. Read-only profiles identified unchanged heart rows (338 instructions/call), native sprite submission (about1518/call), quarter-speed movement (about95/call) and bounds (29/31/call).

Live Genesis work-RAM capture also showed `s_map_cue=1` in the OW HUD at the end of the route. A mode-3 `$44` transfer raised the dungeon-map cue; only the UW map drawing path consumed it. The stale cue continually bypassed the HUD refresh gate.

After CPU reductions, six stalls remained on4D257E93. Video records show some ticks completed near `$DE/$DF` before VBlank, but SGDK's default `ON_VBLANK_START` then waited for a further edge if its setup crossed the current edge. Other work extended into blanking. These are distinct timing causes.

## 2. Structural changes

- Original heart rows cache their authoritative health/partial-health, visibility and row/column inputs. Existing force-redraw paths override the cache; Redux's frame-based animation bypasses it. The existing per-cell cache and transfer cadence remain.
- OW HUD drawing consumes the unused dungeon-map cue. UW still owns the actual map cue/draw path.
- Native sprite translation retains a small ordinary-tile return; special markers, lazy CHR, boss palettes and flashing retain their existing paths. Wallmaster capture eligibility is computed once per slot.
- MoveObject combines four quarter-speed additions/subtractions. Integer steps stop at the first grid limit in the chosen circular-byte direction; fractional accumulation continues, like NES. No-carry movement returns after publishing the fraction. Bounds use local samples while retaining scratch writes; paired bounds are inlined.
- The native frame host waits for SGDK's volatile V-Int counter to differ from the preceding tick, then calls `SYS_doVBlankProcessEx(ON_VBLANK)`. It can use the current blank without issuing two game ticks in one hardware frame. SGDK still owns DMA, scroll and palette processing. No driver fork or new raw VDP writes.

## 3. Arithmetic evidence

Exhaustive factored comparison against the original four-step recurrence passed131072 fraction/carry cases (every fraction and quarter-speed byte, both signs), and5120 grid-clamp cases (every grid byte,0–4 possible steps, Link/monster limits, both signs).

For positive motion, carry count is `(fraction + 4*speed) >> 8`. For negative motion it is `(4*speed + 255 - fraction) >> 8`; final fraction wraps to a byte. Clamp that count to both circular-byte distances from the starting grid to its limits. Once a limit is reached the original recurrence suppresses every later step, so its carry ordering cannot change the clamped result. Position uses the same byte delta. Direction priority and limit publication are unchanged.

The current Windows environment lacks host gcc/cc65/py65, so this is an exhaustive arithmetic proof plus live compiled-ROM checks, not a newly executed asm_equiv claim.

## 4. Windows verification

`Debug.bat` PASS, generated freshness9/9. Frozen local ROM `builds/playtests/Debug-T172-water-vblank.md`, SHA-256 `595AD94CAA6DE309A5C31D67BC07521B1DDB945EB7106BB4834EC960151F500E`; matching local ELF `build/scratch/Debug-T172-water-vblank.out`.

OW ladder report `t056_ladder_ow_t172_vblank`:610/610 KEY0; **LAG PASS, zero extra frames**. Every byte of the complete before/after Genesis NES mirror agrees across all610 ticks except the two frame-budget instrumentation cells `$01FE/$01FF`. Captured pixel comparisons at160/300/420 MATCH. No raw ratchet baseline is blessed:68 unclassified startup/native-display/scratch differences still yield GATE FAIL/NONE.

Intermediate measured stall counts:61 → heart cache31 → sprite cleanup31 → movement29 → local samples/no-carry24 → OW map cue7 → bounds inlining6 → frame synchronization0. Making all translations calls regressed to46; splitting a cold translation helper regressed to27. Both experiments were removed. Instruction counts alone did not predict 68000 cycle cost.

Final same-ROM checks: newgame266/266, potion664/664, Patra1533/1533 and Wallmaster8156/8156 GATE PASS. Raft800/800 and Q2 entry2313/2313 KEY0 with raw GATE FAIL/NONE (68 and74 cells); no new baselines blessed. All seven complete cases, including ladder, LAG PASS. Potion120/300, Patra500/1142/1435, Wallmaster7900/8000, raft468/550 and Q2 owned-map pause2190 SCREEN MATCH. Q2 installed LevelInfo256/256 bytes exact. The adjacent JSON retains raw gate outcomes and executed counts. No broad suite repeated.

### Limits

Zero gameplay stalls is not generous active-display headroom. Worst on-time end line remains `$DF`. Late hardware-counter markers persist at142/197/208/304/305/318, ending at `$E2–$E9`; current blanking still accommodates the work without an extra video frame in this route. The probes retain those markers. Wider headroom, pause/continue/loading and other busy scenes remain T-172 ACTIVE. New water raw-baseline classification and connected acquisition/save/Q2 location coverage remain T-056 REVIEW.
