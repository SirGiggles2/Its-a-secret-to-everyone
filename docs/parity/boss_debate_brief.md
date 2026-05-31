DEBATE: Dungeon boss rendering is blocked on a NES Zelda 1 -> Sega Genesis port.
Answer the 3 questions at the end. Be concrete and technical. ~300 words.

CONTEXT (all byte-proven via live probes):
- Genesis port of NES Zelda 1. Dungeon BG + regular-enemy spawn DATA are now
  byte-exact vs NES (regenerated dungeon LevelBlockAttrs + FoeCounts from LIVE
  NES SRAM, since the reference .dat extractions did NOT match what NES loads
  into SRAM at runtime).
- Boss render path EXISTS on Genesis: ObjType slots scanned for boss types
  ($31-34/$38-3E/$41-48) -> sets s_boss_bank_active -> boss CHR DMA'd to a VRAM
  boss-tile base -> c_aquamentus_draw() writes 6 sprites to NES shadow OAM
  ($0200) via a rolling sprite index -> a boss-room OAM-shadow flush sweeps
  shadow OAM to the Genesis SAT.
- enemy_update_fns[$3C]=Manhandla, [$3D]=Aquamentus, [$3E]=Ganon (Genesis table
  matches NES InitObject_JumpTable exactly).

THE CONFLICT (byte-proven):
- I identified L1's boss room as $36 because $36 is the only room in my captured
  "L1 aggregate" with a boss-range template. But room $36's LevelBlockAttrsC
  gives ObjType $3C = MANHANDLA (the L3 boss), not Aquamentus ($3D) which is
  L1's actual boss. NO room in my L1 aggregate carries template $3D.
- NES underworld LevelBlocks are SHARED: one block for levels 1-6 (UW1), one for
  7-9 (UW2). So LevelBlockAttrsC[$36] is the same byte for all of L1-L6; each
  level only USES a subset of the 128 room slots. Manhandla is L3's boss, so
  room $36 likely belongs to L3, and my "L1 aggregate" (from a room-visit
  capture) mis-attributed $36 to L1.
- LIVE symptom: warping Genesis to L1 $36, the boss object spawns but
  c_aquamentus_draw's 6 sprites do NOT appear in shadow OAM $0200 (empty even
  with Link un-halted/live); only ONE stray boss-bank sprite ($CA, palette PAL3)
  reaches the SAT.
- BLOCKER: the forced room-load entry (poke GameMode=$10 stairs transition +
  mode-4 room re-decode) and the Link-halt "golden" capture do NOT reproduce a
  real live boss FIGHT, so I cannot get clean NES boss ground truth (true boss
  ObjType, 6-sprite OAM layout, palette) to verify any fix. RULE: never guess;
  probe live + byte-diff before coding.

QUESTIONS:
1. Is the $3C-vs-$3D conflict almost certainly "room $36 is an L3 Manhandla room
   mis-attributed to L1 by my capture", and how do I cheaply find L1's TRUE
   Aquamentus room+ObjType from data I can trust (the shared UW1 LevelBlock +
   the per-level LevelInfo) WITHOUT a clean live capture?
2. Why would c_aquamentus_draw write 6 sprites to shadow OAM $0200 yet $0200 read
   back empty (even live), while 1 boss sprite still reaches the SAT via another
   path? What are the likely disconnects (wrong OAM buffer base, dispatch not
   calling the draw, sweep reading a different buffer, rolling-index collision)?
3. Cheapest reliable way to get a CLEAN live-NES boss-fight capture for byte-diff
   ground truth: scripted dungeon traversal to the boss, a per-boss savestate,
   or a forced spawn that actually ticks the boss object each frame? Blind spots?
