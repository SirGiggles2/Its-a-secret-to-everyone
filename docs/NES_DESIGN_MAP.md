# NES Design Map

**Role:** Reference document. This maps the NES Zelda 1 behavior, frame flow, and scene responsibilities as extracted from the Aldonunez disassembly under `reference/aldonunez`. Used during implementation to ensure the Genesis engine faithfully reproduces NES game behavior.

**Source of truth:** The Aldonunez 6502 disassembly files and the NES ROM.

## High-level frame shell

Core frame ownership in the NES game lives primarily in `reference/aldonunez/Z_07.asm`.

- `IsrReset`
  - waits for stable VBlank
  - resets MMC1 state
  - selects the startup bank layout
  - jumps into `RunGame`
- `RunGame`
  - clears RAM, audio, and video state
  - enables NMI
  - then idles forever while NMI owns the game loop
- `IsrNmi`
  - applies pending nametable selection
  - sets mask state depending on sprite-0 split and transfer work
  - DMA-copies sprites to OAM
  - transfers the current tile buffer
  - waits for sprite-0 hit when needed for status-bar splits
  - applies scroll for the active gameplay-facing modes
  - decrements timers when not paused or in menu
  - reads controller input unless scrolling
  - drives audio once per frame
  - either initializes the current mode or updates it

For the Genesis port, this means the native shell should preserve the ownership pattern, not the implementation details:

- reset belongs to Genesis startup code
- VBlank owns transfer submission and frame pacing
- input should be sampled once per frame from the platform layer
- audio should be called from the frame shell, not ad hoc from scene code
- game mode initialization and update remain the top-level behavior dispatcher

## Initialization flow

Initialization splits into one-time game setup and per-mode setup.

- `InitializeGameOrMode` in `reference/aldonunez/Z_07.asm`
  - if the game is not initialized yet, copies common code/data and marks save RAM initialized
  - otherwise dispatches into `InitMode`
- `BeginUpdateMode` in `reference/aldonunez/Z_01.asm`
  - resets `GameSubmode`
  - sets `IsUpdatingMode`
  - acts as the common handshake from init logic into steady-state updates
- `GoToNextMode` and `EndGameMode` in `reference/aldonunez/Z_07.asm`
  - advance `GameMode`
  - clear `IsUpdatingMode`
  - reset `GameSubmode`

For `WHAT IF`, this is the behavioral model we want:

- a native Genesis mode manager with `mode`, `submode`, and `is_initializing`
- explicit init and update entrypoints per mode
- transitions that are data-driven and visible in one place instead of hidden in renderer code

## Update mode table

`UpdateMode` in `reference/aldonunez/Z_07.asm` is the clearest top-level behavior map in the original game.

| Mode | Update routine | Behavior role |
| --- | --- | --- |
| `0` | `UpdateMode0Demo` | title attract loop, story/demo flow, and the bridge into menu |
| `1` | `UpdateMode1Menu` | file select and main frontend menu |
| `2` | `UpdateMode2Load` | quest- and room-data loading and patching |
| `3` | `UpdateMode3Unfurl` | curtain / reveal transition into active play |
| `4` | `UpdateMode4and6EnterLeave` | room-entry walking and transition settling |
| `5` | `UpdateMode5Play` | steady-state play update |
| `6` | `UpdateMode4and6EnterLeave` | room-exit walking and transition settling |
| `7` | `UpdateMode7Scroll` | scrolling between rooms |
| `8` | `UpdateMode8ContinueQuestion` | continue/save retry question flow |
| `9` | `UpdateMode5Play` | play loop after cellar-specific init path |
| `A` | `UpdateMode5Play` | play loop after special subroom transition init |
| `B` | `UpdateMode5Play` | play loop for cave state after cave init |
| `C` | `UpdateMode5Play` | play loop for shortcut/subroom state after shortcut init |
| `D` | `UpdateModeDSave` | save handling |
| `E` | `UpdateModeERegister` | registration/name entry path |
| `F` | `UpdateModeFElimination` | file elimination path |
| `10` | `UpdateMode10Stairs` | stairs entry/exit behavior |
| `11` | `UpdateMode11Death` | death flow |
| `12` | `UpdateMode12EndLevel` | triforce/end-level sequence |
| `13` | `UpdateMode13WinGame` | ending/win-game sequence |

Important porting takeaway:

- the NES code has more distinct init modes than distinct steady-state update loops
- modes `5`, `9`, `A`, `B`, and `C` all converge on the same update routine after different initialization paths
- Genesis should preserve that convergence, because it suggests one gameplay update loop with several entry pipelines

## Frontend and title flow

Frontend ownership is mostly in `reference/aldonunez/Z_02.asm`.

### Demo / title mode

`UpdateMode0Demo` drives the attract/title path through submodes.

- submode `0`
  - animates the demo when not skipped
  - watches for Start
  - silences the current song on Start
  - turns off video and hides sprites before transitioning
- submode `2`
  - copies and formats save-slot data
  - copies names, death counts, quest numbers, and hearts into working slot info
  - advances to menu mode

The title setup is staged through small init tasks:

- `InitDemoSubphaseTransferTitlePalette`
  - writes a title palette transfer record into the dynamic tile buffer
  - resets demo-specific state
- `InitDemoSubphasePlayTitleSong`
  - requests the title song
  - selects the title nametable transfer buffer
- `TitlePaletteTransferRecord`
  - is a concrete example of how frontend scenes in the NES build are encoded as transfer records instead of direct renderer calls

### Menu mode

`UpdateMode1Menu` owns save-slot selection and option selection.

- submode `0`
  - handles Start and Select
  - cycles cursor position through save slots and options
  - writes cursor sprites
  - draws the Link sprites shown beside each save slot
- submode `1`
  - branches by chosen option
  - loads a save slot into runtime profile state
  - or routes into register / eliminate modes

### Ending frontend

`UpdateMode13WinGame` is a reminder that the frontend is not only the title screen.

- hides sprites and drives flash timing
- patches a palette entry during the ending flash
- requests the ending song
- later begins the peace/credits text progression

Port implication:

- Phase 3 should probably start with the frontend shell, not dungeon gameplay
- title/menu/ending flow already reveal the game's mode semantics without needing full combat or room logic

## Input flow

Controller ownership lives in `reference/aldonunez/Z_07.asm`.

- `ReadInputs`
  - strobes the controller ports
  - reads controller 1, then controller 2
- `ReadOneController`
  - repeatedly polls until it gets stable matching reads
  - records both `ButtonsDown` and edge-triggered `ButtonsPressed`
  - merges controller and expansion-port bits

Important behavioral details:

- input is intentionally skipped while sprite-0 room scrolling is active
- menu, pause, and gameplay all depend on the distinction between held buttons and newly pressed buttons
- Link's current directional intent is derived from the low nibble of `ButtonsDown`

Genesis-port implication:

- `Input_Poll` in `src/platform.asm` should eventually produce both held and pressed bitfields, not only a raw current state
- mode logic should never read hardware directly; it should consume a stable per-frame `InputState`

## Gameplay flow

### Core play loop

`UpdateMode5Play` in `reference/aldonunez/Z_07.asm` is the central gameplay coordinator.

Its responsibilities include:

- gating on temporary global conditions like flute delay or room brightening
- pause and submenu handling
- Start-button transition into submenu scroll
- Link update
- weapon/item slot updates
- chase-target selection used by enemy behavior
- monster/tile-object update loop
- underworld room systems
- overworld special systems
- deferred status-bar transfer signaling
- hearts and rupees maintenance

The inner structure matters:

1. Handle pause/menu gating before world update.
2. Update the player.
3. If mode changed during player update, stop early.
4. Update weapons/items.
5. Update autonomous object slots.
6. Run room-level special systems.
7. Queue transfer work if needed.
8. Finish with meters and status-bar upkeep.

That sequencing is useful for Genesis because it separates logic from rendering:

- player and object simulation happen first
- transfer / HUD / palette work becomes output work afterward

### Player behavior

`UpdatePlayer` in `reference/aldonunez/Z_07.asm` owns the player-centric slice of the play loop.

- decrements invincibility timer
- respects halted and paralyzed states
- calls `Link_HandleInput`
- calls `Walker_Move`
- finalizes movement and animation
- conditionally shows Link behind horizontal doors in underworld rooms
- snaps Link back to grid alignment when appropriate

Genesis-port implication:

- player update should become a pure gameplay subsystem that outputs animation/render intent
- collision and grid logic should survive mostly as behavior, even though the renderer and scroll model change

### Room transitions and room-state ownership

Several modes exist mainly to move between steady-state play situations.

- `InitMode4` / `UpdateMode4and6EnterLeave`
  - room entry / exit walking and transition cleanup
- `InitMode6`
  - saves kill-count state, sets leaving-room offsets, and enters the transition update
- `InitMode7` / `UpdateMode7Scroll`
  - scrolling between rooms, including sprite-0 split handling and mirroring changes on the NES side
- `InitMode9`
  - cellar-specific fade / layout / walk sequence
- `InitModeA`
  - special subroom path that returns to mode 4 after its own init chain
- `InitModeB`
  - cave path
- `InitModeC`
  - shortcut path
- `InitMode10`
  - stairs transition
- `InitMode11`
  - death sequence init
- `InitMode12`
  - end-level sequence init

Porting takeaway:

- room transitions should become first-class scene/state transitions in Genesis
- do not collapse all these into a single opaque "loading" flag
- the shared update path is simple, but the entry choreography is not

## Rendering-facing behavior

The NES game mixes gameplay with transfer-buffer generation, palette patching, and scroll timing. Those are exactly the pieces we need to reinterpret rather than port literally.

### Transfer records and buffers

Common patterns in the reference:

- static transfer buffer selection via `TileBufSelector`
- dynamic transfer construction in `DynTileBuf`
- palette transfer records like `TitlePaletteTransferRecord`
- row-by-row nametable copies during room transitions

Genesis-port implication:

- `src/renderer.asm` should grow toward a submission model that receives:
  - tile uploads
  - palette row changes
  - tilemap updates
  - scroll values
  - sprite/OAM equivalents
- mode logic should request renderer work, not write VDP state directly all over the codebase

### Scroll and split ownership

`IsrNmi` and `UpdateMode7SubmodeAndDrawLink` show that the NES frame has special logic for:

- sprite-0 status-bar split timing
- nametable switching
- horizontal vs vertical mirroring during room scroll
- selective scroll application in only some modes

Genesis-port implication:

- the status bar split is not a renderer feature to clone one-for-one
- instead, Phase 3 and Phase 4 should define a Genesis-native scene layout for HUD plus playfield
- keep the behavioral contract of "HUD plus play area plus room scrolling," but rebuild the presentation natively

### Palette ownership

Palette behavior shows up in both frontend and gameplay modes.

- title and story palettes are staged as transfer records
- save-slot color affects level palette patching during play init
- death and ending modes patch palette entries as part of scene logic

Porting takeaway:

- palette changes are scene-state outputs, not just art assets
- Genesis scene code should be able to request row-level palette swaps or patches without bypassing the renderer abstraction

## Audio entrypoints and call sites

Audio driver ownership starts in `reference/aldonunez/Z_00.asm`.

- `DriveAudio`
  - runs once per frame
  - mutes/re-enables channels while paused
  - drives tune, effect, sample, and song channels
  - clears all sound requests after servicing them

Representative call sites in gameplay/frontend code:

- title init requests song `$80`
- room-specific secrets can request tune/effect changes
- death mode requests the death tune
- end-level init requests the end-level song
- win-game mode requests the ending song

Genesis-port implication:

- preserve request-driven audio semantics
- do not let random gameplay code talk directly to YM2612/PSG state later
- keep a small audio request API in the platform/game shell

## File map by ownership

- `reference/aldonunez/Z_00.asm`
  - audio driver and song/tune/effect playback ownership
- `reference/aldonunez/Z_01.asm`
  - cave and underworld person logic
  - common gameplay helpers
  - `BeginUpdateMode`
- `reference/aldonunez/Z_02.asm`
  - demo, title, menu, save-slot presentation, ending frontend
- `reference/aldonunez/Z_03.asm`
  - pattern block bookkeeping
- `reference/aldonunez/Z_04.asm`
  - enemies, bosses, NPCs, items, projectiles
- `reference/aldonunez/Z_05.asm`
  - menus, room transitions, scrolling, doors, death, end-level, cave/cellar/subroom flows
- `reference/aldonunez/Z_06.asm`
  - load-time and second-quest room/data patching
- `reference/aldonunez/Z_07.asm`
  - reset, NMI frame shell, input, mode dispatch, play-loop coordination, player update

## Recommended Genesis slicing

Based on the current `WHAT IF` shell, the safest slice order now looks like this:

1. Keep `src/platform.asm` as the owner of reset, VBlank pacing, input polling, and display baseline.
2. Keep `src/renderer.asm` focused on submission helpers and explicit scene output, not game rules.
3. Turn Phase 3 into a native frontend shell first:
   - title scene
   - menu scene
   - basic mode/submode dispatcher
4. Port gameplay rules only after the mode shell and renderer contract exist.
5. Treat scroll, HUD, and palette effects as behavior requirements to reinterpret, not NES implementation details to mimic byte-for-byte.

## Immediate follow-up targets

- Define the Genesis-native equivalents of:
  - `GameMode`
  - `GameSubmode`
  - `IsUpdatingMode`
  - `ButtonsDown`
  - `ButtonsPressed`
  - `TileBufSelector` / `DynTileBuf` as renderer submission concepts
- Choose the first Phase 3 implementation target:
  - title-only shell
  - title plus menu shell
  - full frontend mode dispatcher
- Keep the current Phase 0 palette ROM untouched as the hardware regression baseline while the shell grows.
