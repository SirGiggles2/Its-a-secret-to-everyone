# Plan: Exact Zelda 1 Port to Sega Genesis
 
## Context
 
The "WHAT IF" project aims to port The Legend of Zelda (NES) as an **exact, faithful port** — the real game running natively on Genesis hardware. The current approach of building Zelda-like placeholder systems feels like "poor glue" — simplified movement, decorative tiles, nothing connected to the actual game data. This plan replaces that with a systematic extraction + faithful engine approach.
 
**Core strategy:** Extract the real game's data with Python scripts, then build a Genesis engine that faithfully executes it. Each phase is ordered so you can **boot the ROM and test something new** after completing it.
 
---
 
## Dependency Chain (why this order)
 
```
Phase 1: Extract tiles/palettes ──► you can SEE real Zelda graphics on Genesis
Phase 2: Renderer upgrade ────────► you can DISPLAY a room with scrolling + sprites
Phase 3: Room system ─────────────► you can LOAD and RENDER a real Zelda room
Phase 4: Player system ───────────► you can WALK Link through that room with real physics
Phase 5: Object/enemy system ─────► rooms come ALIVE with real enemies
Phase 6: Mode manager + state ────► full game FLOW (title → menu → play → transitions)
Phase 7: Frontend & menus ────────► title screen, file select, inventory, save/load
Phase 8: Audio engine ────────────► the game has SOUND
Phase 9: Polish & second quest ───► ship it
```
 
Each phase depends on the one before it. You never build something you can't immediately test.
 
---
 
## Phase 1: Data Extraction Pipeline (Python)
 
**Test milestone:** Boot ROM, see real Zelda tiles rendered in VRAM viewer / on a test screen.
 
Build Python scripts that read the NES ROM + Aldonunez disassembly and output Genesis-ready `.inc` files.
 
### 1A: Graphics Conversion (do first — everything visual depends on this)
- Convert NES 2bpp CHR tiles → Genesis 4bpp tile format
- Zelda 1 uses CHR-RAM (no CHR-ROM bank), so tile data is embedded in PRG-ROM and copied to PPU pattern tables at runtime. Extract the pattern block data referenced by Z_03's `TransferPatternBlocks` routines.
- Sprite tiles (Link, enemies, items, projectiles) and BG tiles (overworld, underworld, UI)
- Map NES 4-color palettes → Genesis 9-bit CRAM values (manual color tuning pass needed)
- Output: `src/data/tiles_overworld_bg.inc`, `src/data/tiles_underworld_bg.inc`, `src/data/tiles_sprites.inc`, `src/data/palettes.inc`
- **Replaces all hand-drawn tile data currently in renderer.asm**
 
### 1B: Room/Map Data
- Overworld 16x8 room grid (128 screens): tile columns, enemy spawn lists, exits, secrets
- 9 dungeon layouts from `LevelBlockAddrs` tables (Z_06)
- Room attributes and Second Quest patches
- Output: `src/data/overworld_rooms.inc`, `src/data/dungeon_rooms.inc`, `src/data/room_enemies.inc`
 
### 1C: Enemy & Object Tables
- ObjType dispatch table (Init/Update function IDs per enemy type)
- Per-type constants: HP, speed, sprite descriptor, damage, drop class
- Drop tables (HelpDrop system)
- Output: `src/data/enemy_tables.inc`, `src/data/drop_tables.inc`
 
### 1D: Player Constants
- Walk speed fractions, push-back distances, invincibility durations, sword hitbox/timers
- Output: `src/data/player_constants.inc`
 
### 1E: Item, Text & UI Data
- Item ID → sprite mappings, slot layout, use-effect dispatch
- NPC dialogue (PersonText.dat), menu text, HUD layout
- Output: `src/data/item_tables.inc`, `src/data/text.inc`, `src/data/ui_layout.inc`
 
### 1F: Audio Data (extract now, wire in Phase 8)
- Song note sequences from Z_00 .dat files, effect/envelope tables
- Output: `src/data/songs.inc`, `src/data/sfx.inc`
 
**New tool scripts:**
- `tools/extract_chr.py` — tile graphics converter (NES 2bpp → Genesis 4bpp)
- `tools/extract_rooms.py` — room/map data extractor
- `tools/extract_enemies.py` — enemy table extractor
- `tools/extract_misc.py` — items, text, palettes, player constants
- `tools/extract_audio.py` — music/sfx data
- Input: `Legend of Zelda, The (USA).nes` + `reference/aldonunez/*.asm`
 
---
 
## Phase 2: Renderer Upgrade for Real Gameplay
 
**Test milestone:** Boot ROM, see a real Zelda room rendered with correct tiles on Plane A, HUD on separate plane, Link sprite visible.
 
### 2A: Playfield + HUD Layout
- Plane A: 32x28 playfield (scrollable for room transitions)
- Window plane or Plane B: fixed HUD/status bar (hearts, rupees, map, items)
- Genesis-native replacement for NES sprite-0 split
 
### 2B: Sprite Table Manager
- 80-slot sprite table in RAM, DMA'd to VRAM during VBlank
- Slot allocation: Link (slots 0-3 for 2x2 metasprite), enemies, items, projectiles
- Clear/reset per frame, populate during update, submit during VBlank
 
### 2C: DMA-Based VBlank Transfer
- Submission queue: tile uploads, tilemap row/column updates, sprite table, palette changes
- Replace current blocking VRAM writes with queued DMA during VBlank
- Genesis-native equivalent of NES transfer buffer system
 
### 2D: Room Scrolling Foundation
- Column-by-column tilemap updates for horizontal room transitions
- Row-by-row for vertical transitions
 
**Files to modify:**
- `src/renderer.asm` — keep VRAM/CRAM write primitives, add sprite manager + DMA queue + scroll
- `src/platform.asm` — extend VBlank handler with DMA dispatch
 
---
 
## Phase 3: Room System
 
**Test milestone:** Boot ROM, see the real Overworld starting room (screen $77) rendered with correct tiles. Walk to screen edges and see adjacent rooms load.
 
### 3A: Room Loader
- Read extracted room data tables
- Decompress/layout room tiles onto Plane A tilemap
- Set room palette from level info
- Spawn enemy placeholders (enemy logic comes Phase 5, but spawn positions are visible)
 
### 3B: Room Transitions
- Edge-triggered room changes (walk off screen → load adjacent room)
- Scrolling transition animation using Phase 2D's column/row updates
- Match `UpdateMode7Scroll` behavior from Z_07
 
### 3C: Overworld + Dungeon Navigation
- Overworld: 16x8 room grid
- Dungeons: 8x8 room grid per level
- Door state (locked, bombed, key, shutter)
- Secret detection (bomb walls, push rocks, burn bushes)
- Warp/staircase system
 
**New files:**
- `src/rooms.asm` — room loader + transition logic
- `src/overworld.asm` — overworld grid navigation
- `src/dungeon.asm` — dungeon grid + door/key logic
- Reference: Z_05 (rooms/transitions), Z_06 (level loading)
 
---
 
## Phase 4: Player System
 
**Test milestone:** Boot ROM, walk Link through the Overworld starting room with NES-accurate movement speed. Swing sword, see hitbox interact with room tiles. Take damage from walking into placeholder enemies, see hearts decrease.
 
### 4A: Movement (faithful to NES)
- Sub-pixel position tracking (`ObjPosFrac` + `ObjGridOffset`)
- Grid-aligned movement with the **real NES walk speed values** from extracted constants
- Wall collision against actual room tile data
- Push-back/shove system
- Stair handling
 
### 4B: Combat
- Sword swing with real NES frame timers and hitbox
- Sword beam at full health
- Secondary item use (bombs, boomerang, bow, candle, etc.)
- Damage dealing and receiving with NES-accurate values
 
### 4C: State Machine
- Full Link state set: walking, attacking, hurt, stunned, entering-cave, using-item, death
- Invincibility timer with NES-accurate flash pattern
- Clock/knockback/paralysis effects
 
**New file:**
- `src/player.asm` (replaces `src/modules/link_test.asm`)
- Reference: Z_07 `UpdatePlayer`, `Link_HandleInput`, `Walker_Move`
 
---
 
## Phase 5: Object & Enemy System
 
**Test milestone:** Boot ROM, enter a room with Octorocks. They walk, turn, shoot projectiles. Sword kills them. Items drop. HP values match NES exactly.
 
### 5A: Object Slot Framework
- 20 object slots (matching NES), each with: type, X, Y, direction, state, timer, HP
- Per-frame update loop: dispatch Init or Update by ObjType from extracted tables
- Generic collision: object↔player, object↔sword, object↔room tiles
 
### 5B: Enemy Behavioral Classes (incremental, by class)
 
| Order | Class | Enemies Covered | Test |
|-------|-------|-----------------|------|
| 1st | Walker | Octorock, Moblin, Darknut, Lynel, Stalfos, Gibdo, Rope, Goriya | Walk, turn, collide |
| 2nd | Shooter | Octorock+, Moblin+, Goriya+ | Walker + projectile spawn |
| 3rd | Flyer | Keese, Peahat, Vire, Patra orbit | Float/sine patterns |
| 4th | Stationary | Trap, Bubble, Like-Like, Wallmaster | Trigger-based grab/move |
| 5th | Bosses | Aquamentus → Dodongo → ... → Ganon | One at a time, unique each |
 
Each class: one Init + one Update routine reading per-type constants from extracted data tables.
 
**New files:**
- `src/objects.asm` — slot framework + update loop
- `src/enemies.asm` — behavioral class implementations
- Reference: Z_04 (enemy code), Z_07 (object loop)
 
---
 
## Phase 6: Mode Manager & Game State
 
**Test milestone:** Boot ROM, see title screen → press Start → file select menu → select slot → load sequence → unfurl curtain → gameplay. Death → continue screen → respawn. Full game flow.
 
### 6A: Game State Variables
- `GameMode` (0-$13), `GameSubmode`, `IsUpdatingMode`
- `CurLevel`, `CurRoomId`, `DoorwayDir`
- All persistent state: hearts, rupees, keys, bombs, inventory, map flags, triforce pieces
 
### 6B: Mode Dispatch Table
The real 20-entry mode table from Z_07:
 
| Mode | Handler | Role |
|------|---------|------|
| 0 | Demo/Title | Attract loop + title |
| 1 | Menu | File select |
| 2 | Load | Quest/room data loading |
| 3 | Unfurl | Curtain reveal transition |
| 4,6 | Enter/Leave | Room entry/exit walking |
| 5,9,A,B,C | Play | Main gameplay (shared update, different init paths) |
| 7 | Scroll | Room scrolling transition |
| 8 | Continue | Continue/save/retry |
| D | Save | Save handling |
| E | Register | Name entry |
| F | Eliminate | File deletion |
| $10 | Stairs | Stair entry/exit |
| $11 | Death | Death sequence |
| $12 | EndLevel | Triforce collection |
| $13 | WinGame | Ending/credits |
 
### 6C: Transition Choreography
- Each Init mode sets up state, then hands off to its Update
- `BeginUpdateMode` handshake (from Z_01)
- `GoToNextMode` / `EndGameMode` transitions
 
**Files to modify:**
- `src/main.asm` — replace frontend routing with mode dispatch in frame loop
- New: `src/mode_manager.asm` (replaces `src/frontend.asm`)
- Reference: Z_07 `UpdateMode` table, Z_01 `BeginUpdateMode`
 
---
 
## Phase 7: Frontend & Menus
 
**Test milestone:** Full title sequence with real graphics + music cue. File select with 3 save slots, name entry, file elimination. Inventory submenu with real item grid and map.
 
### 7A: Title Screen
- Real extracted title graphics (not placeholder tiles)
- Demo/attract mode playback with accurate timing
- Story scroll text
 
### 7B: File Select Menu
- 3 save slots showing hearts/name/death count
- Register (name entry) and Eliminate modes
- SRAM save/load at Genesis $200001 (odd bytes, standard mapper)
 
### 7C: Inventory Submenu
- Pause overlay with item grid
- Overworld/dungeon map display
- Item selection with cursor
 
**New files:**
- `src/frontend.asm` (rewritten for real title/menu, not placeholders)
- `src/inventory.asm` — submenu overlay
- Reference: Z_02 (demo, menu, save), Z_05 (inventory)
 
---
 
## Phase 8: Audio Engine
 
**Test milestone:** Boot ROM, hear the title theme. Enter overworld, hear overworld music. Enter dungeon, hear dungeon theme. Pick up item, hear fanfare.
 
### 8A: YM2612 + PSG Driver
- Note-sequence player consuming extracted song data from Phase 1F
- Channel mapping: NES pulse 1,2 → YM2612 FM channels; NES triangle → FM or PSG; NES noise → PSG noise
- Request-driven API matching NES `PlaySong`/`PlayEffect` semantics
- Called once per frame from the main loop (matching NES `DriveAudio` pattern)
 
### 8B: Sound Effects
- Item pickup, sword slash, enemy hit/death, secret, low health beep, bomb
- Effect priority system (effects can interrupt/layer over music channels)
 
**New file:**
- `src/audio.asm` — driver + channel management
- Reference: Z_00 (entire audio engine)
 
---
 
## Phase 9: Polish & Second Quest
 
**Test milestone:** Play through Quest 1 start to finish. Play through Quest 2 start to finish. Frame timing is 60fps. All edge cases work.
 
- Second Quest room/enemy patches (already extracted in Phase 1)
- Color tuning pass (Genesis 512 colors vs NES 54 — make it look right)
- Frame timing verification (60fps NTSC, compare side-by-side with NES in BizHawk)
- Edge cases: screen wrapping, kill counts, help drops, continue screen, fairy ponds, shop prices
- Save system persistence testing across power cycles
 
---
 
## What Existing Code Is Kept vs. Replaced
 
| File | Disposition |
|------|------------|
| `src/platform.asm` | **Keep + extend** — VDP init, TMSS, joypad, VBlank. Add DMA helpers. |
| `src/main.asm` | **Keep structure** — ROM header, vectors, frame loop. Replace frontend routing with mode dispatch. |
| `src/renderer.asm` | **Keep primitives** — VRAM/CRAM write helpers. Strip placeholder tile data (replaced by extracted data). Add sprite manager + DMA queue + scroll. |
| `src/frontend.asm` | **Replace** — rewrite with real title/menu logic |
| `src/modules/link_test.asm` | **Replace** — becomes `src/player.asm` with faithful NES logic |
| `src/scenes/palette_diagnostic.asm` | **Keep** — hardware regression test |
| `build.bat` | **Keep + extend** — add extraction script step before assembly |
 
## Verification Strategy
 
Every phase has a **visual test** you can perform by booting the ROM:
 
| Phase | Boot the ROM and verify... |
|-------|---------------------------|
| 1 | Real Zelda tiles appear in VRAM viewer (BizHawk/BlastEm) |
| 2 | A test room renders with tiles on Plane A, HUD on Plane B, Link sprite visible |
| 3 | Starting room $77 loads correctly, walking off-screen triggers room transition |
| 4 | Link moves at NES-accurate speed, sword swings, wall collision works |
| 5 | Octorocks walk/shoot, die to sword, drop items |
| 6 | Title → Menu → Load → Unfurl → Play → Death → Continue cycle works |
| 7 | Title has real graphics, file select works, inventory submenu opens |
| 8 | Music plays on title, overworld, dungeon. SFX on sword/item/hit |
| 9 | Full playthrough of both quests |
 