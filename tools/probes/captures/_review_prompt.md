You are an adversarial senior engineer reviewing an IMPLEMENTATION PLAN (not code yet). The project is a cycle-accurate Zelda 1 NES → Sega Genesis (SGDK) port. The bar is BYTE-EXACT parity with the NES ROM. House rules that govern this project:

- RULE ZERO: never guess tile IDs / palette / VRAM / OAM / RAM / addresses / timing. Probe NES live + Genesis live + byte-diff BEFORE any code.
- RULE V1: a screenshot is NOT verification — only a byte-diff proves "matches NES".
- RULE V3: every probe captures ALL relevant domains in FULL ranges with metadata (enumerate memory domains live; never assume a domain name or address).
- Drain-first: drained C in src/game/<subsystem>/*_runtime.c is PRIMARY evidence; NES disasm (reference/aldonunez/*.asm) is the final authority on ties. Do NOT greenfield when a drain/native impl exists — EXTEND it.
- No new files under RoomRom/; gameplay code lives in src/game/<subsystem>/.

Your job: find what is WRONG, RISKY, UNDERSPECIFIED, or MISORDERED in the plan below. Be specific and technical. For each issue give: (severity: BLOCKER|MAJOR|MINOR|NIT) — (the concrete problem) — (the fix). Prioritize:

1. Correctness of the NES ground-truth claims (addresses, frame counts, pixel deltas, RAM cells). Flag any number the plan asserts that is NOT backed by a cited asm line or a live capture — those are RULE ZERO violations waiting to happen.
2. Ordering hazards — does any step depend on data a later step produces? Is the probe-fix-first ordering actually sufficient?
3. The −7px frame-0 Y theory, the 48px×1fpp ascend, the (112,221) cave-bottom spawn, the SAT@$F800 address, the behind-BG-vs-sprite-priority choice, and the stairs-tile auto-exit trigger. Which of these are well-evidenced vs guesses dressed as facts?
4. Missing verification: what could pass the stated byte-diff gate and STILL be wrong vs NES? (e.g. coordinate-space normalization between NES 8-bit ObjY and Genesis 16-bit Y, HUD row offset, capture-frame phase alignment.)
5. Anything the plan omits entirely that NES cave entry/exit actually does (sound effect timing, item-state reset, scroll lock, EffectRequest, cellar vs cave distinction, shortcut Mode $0C path).

End with a VERDICT line: APPROVE / APPROVE-WITH-CHANGES / REWORK, plus the single highest-priority fix.

==================== PLAN UNDER REVIEW ====================

# Cave-Entry Animation / Positioning / Transition — NES Byte-Parity

## Context
NES sequence when Link walks onto a cave-entrance tile: forced 64-frame walk-down descent (Link sinks behind the arch), atomic scene+palette swap to the single-screen cave, Link placed at cave bottom facing up, then a 48-frame forced walk-up "emerge" before control releases. Exit mirrors this.

Genesis scaffolding already exists (cave_fade.{h,c}, cave_entrance.c, cave_dispatch.c, wired in RoomRom/src/main.c). A live byte-diff (tools/probes/captures/cave_diff_report.txt) + asm read prove divergences:
1. Frame-0 standing Y wrong — NES Link Y=$4D on entrance tile, Genesis=$54 (−7px).
2. Emerge ascend wrong — cave_fade.c LINK_ASCEND mirrors descent (16px×4fpp). NES emerge is 48px×1fpp (ObjGridOffset=$30, InitMode_WalkCave MoveObject per frame).
3. Cave-bottom spawn wrong — handler + comment say (120,192). NES is ObjX=$70(112), ObjY=$DD(221), facing up.
4. Exit is manual C+START chord; NES auto-fires when Link walks onto cave-interior stairs tile (UndergroundExitType=$01).
5. Sprite priority + walk-pose during descent unverified — NES sets OAM attr bit $20 (behind-BG) on full Link sprite, cycles walk-pose tiles/H-flip every frame. Genesis uses BG-side priority stamp, toggles walk frame every 4 frames.
6. Probe stale/buggy — every Genesis OAM Link slot reads 00 across the whole capture; SAT read missing or wrong VRAM address. Diff's sprite conclusions untrustworthy until probe fixed + re-run.

Locked decisions: entry+exit full parity (fix ascend, add NES stairs-tile auto-exit, keep C+START as debug fallback); match NES exactly — NO per-frame fade, single atomic palette swap; acceptance = byte-exact on RAM {ObjX,ObjY,ObjDir,ObjGridOffset,GameMode,Submode} + Link SAT {y,x,attr,tile} across the 64+1+48 frame window (±1 frame capture-phase shift).

## NES ground truth cited
- Z_05.asm:7313 HandleWarpOW — tiles $24,$70-$73,$88; LevelBlockAttrsB[room_id]&$FC selects cave (>=$40 non-$50 -> Mode $0B; $50 -> Mode $0C shortcut).
- Z_05.asm:2308 UpdateMode10Stairs_Full — StairsTargetY=ObjY+$10; every 4 frames (FrameCounter&$03==0) INC ObjY; Link behind BG (PutLinkBehindBackground, OAM attr $20 lower-half); at ObjY==StairsTargetY, GameMode:=TargetMode.
- Z_01.asm:2956 InitModeB_EnterCave_Bank5 — ObjX=$70, ObjY=$DD, ObjDir=$08(up), ObjGridOffset=$30, UndergroundExitType=$01.
- Z_05.asm:6643 InitMode_WalkCave — while ObjGridOffset!=0, MoveObject 1px UP per frame (48 frames); then release control.
RAM: $12 GameMode, $13 GameSubmode, $10 FrameCounter, $84 ObjY[0], $85/$70 ObjX[0], $94 ObjDir[0], $B0 ObjGridOffset[0].

## Steps
Step 1 — Fix+review probes (blocks all). Genesis SAT read at VRAM $F800 (PR-2 DMA target, not $FC00); emit Link slots {y,x,attr,tile}/frame; add CRAM $00-$3F, Plane A 16x8 window around Link, metadata (GameMode/Submode mirror, FrameCounter, vscroll). NES probe: enumerate domains live, full PALRAM $3F00-$3F1F, OAM $10-$15, RAM $84/$85/$94/$B0/$12/$13/$10, PPUCTRL. /octo:review both Lua before running. Re-run, regenerate diff. Re-confirm −7px + ascend cadence against clean capture before trusting Steps 2-7.
Step 2 — Frame-0 Y reconciliation. Capture NES $84 on exact frame ObjCollidedTile==$24 (cross-ref FrameCounter to align frame 0). Locate Genesis trigger gate in main.c (~2089) + player-Y init. Fix standing-Y to NES value. Candidates: y_low gate one tile too low, or HUD-row offset (ROOMROM_ROOM_FIRST_ROW=7) miscount. Pin to captured byte, not arithmetic.
Step 3 — Cave-bottom reposition. cave_fade_swap_entry_handler (~487): x=0x70(112), y=0xDD(221); face=UP already correct. Fix stale (120,192) comment in cave_fade.h:47. Verify Y=221 inside cave-room Plane A render bounds.
Step 4 — Emerge ascend rewrite. Add CAVE_ASCEND_PIXELS=48, CAVE_ASCEND_FRAMES_PER_PX=1. In LINK_ASCEND branch (~160): drop (frame&3)==0 gate (step every frame); terminator >= CAVE_ASCEND_PIXELS not CAVE_DESCEND_PIXELS. Audit shared s_step_idx/s_frame_counter so descend (16x4) unaffected. EXTEND only.
Step 5 — Walk-pose anim cadence. NES ticks pose every frame. Genesis toggles s_link_frame once per 4-frame step. Add per-frame anim tick when phase in {DESCEND,ASCEND} — new on_anim_tick callback or move s_link_frame^=1 into per-frame cave_fade-active block (~1989). Keep position step on 4-frame schedule.
Step 6 — Behind-BG priority verify. Confirm cave_fade_mark_arch_hi_prio (BG-side stamp, cave_fade.c:95) matches NES OAM $20. Dump CHR pixel content of Plane A cells above Link at descent frame ~32. If transparent (color-0), switch to sprite-side: drop Link SAT priority bit during DESCEND/ASCEND. Document with side-by-side NES screenshot (triage only).
Step 7 — NES stairs-tile auto-exit. Capture NES walking in+out of cave; record frame GameMode flips $0B->$10 + ObjGridOffset/ObjY state to pin exit condition. Add mirror of OW entrance check inside SCENE_CAVE block (~2256): when collision_get_collidable_tile_still(0) returns stairs tile (or captured Y/grid condition), fire cave_fade_begin_exit(s_cave_return_room). Keep C+START fallback. Reuse existing path, no new files.
Step 8 — Palette (confirm only). Capture PALRAM every frame descend−1..swap+1. If 32 bytes stable until $10->$0B swap, no fade — cave_palette.c single-shot already matches. No code change expected.
Step 9 — Final verify + bookkeeping. Per-step byte-diff after 2-7 (diff scope must shrink). Final: zero diff on agreed fields across 64+1+48 window (±1 frame) or documented normalized difference. python tools/run_regression_matrix.py. python tools/audit/primedirective/prime_refresh.py --record-out-of-phase.

## Critical files
probe_cave_fade_gen.lua (EDIT: SAT@$F800,CRAM,PlaneA,metadata); probe_cave_fade_nes.lua (EDIT: full PALRAM/OAM/RAM/PPUCTRL); cave_fade.c (EXTEND: ascend 48x1, per-frame anim, phase-aware constants); cave_fade.h (fix comment); RoomRom/src/main.c (spawn (112,221), frame-0 Y, anim cadence, SCENE_CAVE auto-exit); cave_entrance.c (READ-ONLY, dispatch correct); cave_palette.c (READ-ONLY, confirm Step 8); Z_05.asm/Z_01.asm (READ-ONLY authority).

Reuse not greenfield: EXTEND cave_fade, reuse cave_entrance_check/cave_fade_begin_exit/cave_dispatch. No new files. Substrate untouched.
