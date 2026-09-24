You are reviewing TWO BizHawk Lua probes for a Zelda 1 NES→Sega Genesis byte-parity port, BEFORE they are run (mandatory per project RULE V2). These probes capture the cave-ENTRY ANIMATION (Link descends into a cave, scene swaps, Link emerges) for a byte-exact NES-vs-Genesis diff. A silent probe bug (wrong domain, wrong address, mid-animation anchor, off-by-one) poisons every downstream golden. Find every such bug.

The files are on disk — read them if you have file access:
- tools/parity/cave_golden/probe_nes_cave_transition.lua
- tools/parity/cave_golden/probe_gen_cave_transition.lua
Full source is also pasted below.

## Verified ground truth (already confirmed against reference/aldonunez/*.asm + Variables.inc)
- NES RAM cells: GameMode=$12, GameSubmode=$13, FrameCounter=$15, ObjX[0]=$70, ObjY[0]=$84, ObjDir[0]=$98, ObjGridOffset[0]=$394, ObjAnimCounter[0]=$3D0, ObjAnimFrame[0]=$3E4, FadeCycle=$51C, EffectRequest=$603, UndergroundEntranceTile=$65, UndergroundExitType=$5A, TargetMode=$5B, CurPpuControl_2000=$FF, PlayAreaTiles=$6530, RoomId=$EB, CurLevel=$10, CurQuest=$62D.
- InitMode10 (Z_05.asm:1399) runs as GameMode $10 submode 0: JSR GetCollidableTileStill; CMP #$24; if equal sets EffectRequest=$08 and StairsTargetY=ObjY+$10; else SKIPS. GetCollidableTileStill (Z_07.asm:2110) reads the tile under Link's hotspot from PlayAreaTiles ($6530), col-major (col*0x16+row, 22 rows).
- Descent: every 4 frames (FrameCounter&3==0) INC ObjY, 16 px / 64 frames. Behind-BG bit $20 set on OAM slots $12/$13 only; upper slots $10/$11 ride at Y=$F8. Walk pose advances every 6 frames (ObjAnimCounter rollover at $06). Emerge: ObjGridOffset=$30 (48 px) at 1 px/frame.
- NES domains (NesHawk): "RAM","OAM","PALRAM","VRAM"(=CHR-RAM 8KB),"CIRAM (nametables)".
- Genesis domains (genplus-gx): "68K RAM" (NES mirror at $8000+addr), "VRAM" (SAT@$F800 — mutation-proven in probe_gen_cave_golden.lua), "CRAM", "VSRAM". players[0].x=68KRAM $1564 (BE short), .y=$1566, s_scene low byte=$0281, in_gameplay=$0274, room=$0041.

## Specific things to check (be concrete; severity BLOCKER/MAJOR/MINOR/NIT, with the fix)
1. ADDRESS CORRECTNESS: every memory.read_u8/write_u8 offset + domain. Wrong domain or addr = garbage golden. Is FadeCycle=$51C / EffectRequest=$603 / ObjGridOffset=$394 / ObjAnimFrame=$3E4 / ObjAnimCounter=$3D0 read correctly on BOTH sides (NES "RAM" vs Gen "68K RAM" $8000+addr)?
2. NES BAND-FORCE: probe_nes computes col=(ObjX>>3)&0x1F and writes $24 into PlayAreaTiles cols c-1..c+1, all 22 rows. Will GetCollidableTileStill's hotspot (ObjY-8 for Link, per Z_07.asm:2110) actually land in a forced cell? Is the col->PlayAreaTiles mapping (col*0x16+row) correct, and is ObjX>>3 the right col when PlayAreaTiles rows=0x16=22? Could the hotspot read a DIFFERENT structure (nametable/CIRAM) than PlayAreaTiles?
3. NES ANCHOR: setting GameSubmode=0 then GameMode=$10 — does the NES mode dispatcher actually run InitMode10 (submode 0) on the next frame, or does the prior mode's submode machinery interfere? Is the 8-frame anchor poll correct?
4. GEN "ARM ONCE": probe_gen arms the $24 tile + Link pos + WALK mode for ONE frame then clears. The golden probe warns that re-forcing every frame FIGHTS cave_fade. Does this probe correctly avoid re-forcing during the 130-frame capture loop? Is anchoring frame 0 at the arm frame valid vs the NES GameMode=$10 anchor (the differ allows ±1 frame)?
5. FRAME ALIGNMENT: NES anchors on GameMode=$10; Gen anchors on the arm frame. Both then capture 130 frames. Is the cadence comparable? Note Gen GameMode mirror stays $05 (no mode $10) — so GameMode must NOT be raw-compared (the differ handles this). Is capturing it still useful (yes, for phase mapping)? 
6. RULE V3 COMPLETENESS: are all domains enumerated/used in full ranges with metadata? Anything missing for the stated goal (ObjY trajectory, sprite Y/X/attr/tile, walk-pose cadence, behind-BG, palette, EffectRequest)? Is dumping CHR/VRAM once at frame 32 (not per frame) safe given patterns are static across the window?
7. CRASH/HANG: any nil deref, infinite loop, file-handle leak, missing client.exit on an early-return path? os.execute mkdir correctness on Windows?
8. CORE ASSUMPTIONS: NES probe requires NesHawk for "VRAM" CHR-RAM reads — is that the only core-specific risk? Gen SAT@$F800 — trust the mutation-proof or re-verify?

End with VERDICT: APPROVE / APPROVE-WITH-CHANGES / REWORK and the single highest-priority fix.

==================== probe_nes_cave_transition.lua ====================
(see file tools/parity/cave_golden/probe_nes_cave_transition.lua — read it)

==================== probe_gen_cave_transition.lua ====================
(see file tools/parity/cave_golden/probe_gen_cave_transition.lua — read it)
