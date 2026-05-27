# Round 3 — What's the NEXT layer of failures?

R2 converged: dispatch is NES-authoritative (4 sprite groups + 2 BG layouts).
Plan = H0-H5 byte-diff iteration.

R3 drills into the layers H5 will surface:

## Question 1: SAT publish ORDER
Codex R1: "deterministic SAT order — Link, cave actor, fire, items, effects, terminator."
NES OAM order is FIFO via RollingSpriteIndex. Genesis port has SAT slot pool. Do they match?
- If Gen renders Link in slot 0, NPC in slot 1, fires in slots 2/3, items in slots 19+ —
- And NES OAM lays Link first, NPC after, fires after, items after —
- Then sprite link chain (per memory feedback_genesis_sprite_link_chain) could break if intermediate slot has link=0.
- Will OAM byte-diff catch this, or false-pass?

## Question 2: PALETTE per-cave_id
NES cave sprites use sub-palette 2 (per NES PALRAM layout) regardless of cave_id.
But cave_77 captured shows ORANGE for NPC (bonfire color, sub-pal 2 entry 3).
cave_6A NPC shows ORANGE too (same sub-pal).
cave_7B "doorway" tiles use BG sub-palette.
Question: per-cave palette is FIXED at cave_init (`roomrom_ow_room_render_load_palette` at main.c:680), one palette for ALL caves. Is that right per NES?

## Question 3: ITEM rendering per cave_id
Each cave has 0-3 items in CaveItemIds[$0422..$0424]. Phase D wired draw_animate_item_object at cave_dispatch.c:305.
Item ids $00..$3F. Each renders with own sprite descriptor.
Q: For cave_id $7B (3 doorways shown), what are CaveItemIds[0..2]?
   For cave_id $6A (Old Man + sword), CaveItemIds[0]=$01 (sword)?
   Verify by reading LBA_E source data + nes_ram cave init.

## Question 4: Q2 cave differences
NES Z_06.asm:263-267 patches 8 OW rooms for Q2. Same cave_id may have different OW room.
But INTERIOR cave content (items/text/sprite) — is it ALSO Q2-different?
Or is the cave_id → content mapping Q-independent?
If Q-independent, our 20 cave scenarios cover Q2 too.
If Q-dependent, need 40 cave scenarios (20 × 2 quests).

## Question 5: NES capture strategy for byte-diff
NES has NO MODE_TELEPORT debug. Two options:
A) Pre-built savestates: navigate NES manually, save state per scenario, commit ~12MB binary blob.
B) Force-state via Lua: write GameMode/RoomId/CurLevel/CaveId directly to NES RAM at $0012/$00EB/$00AD/$0350, force the engine into the right scene.
   Risk: NES may glitch if state not consistent (sprite slots empty, etc).

Which approach for H3?

Each voice: answer ALL 5 in 400 words. Cite file:line.
