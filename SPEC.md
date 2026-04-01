# WHAT IF — Project Specification

Full architecture, milestone definitions, probe registry, and risk tracking for the *Legend of Zelda* NES → Sega Genesis port.

For project overview, build instructions, and current status summary, see [`../README.md`](../README.md).

---

## Accuracy Philosophy

This project is guided by four principles:

### 1. Preserve original logic
Wherever possible, the translated build should still reflect Zelda's original control flow, state changes, data tables, and frame logic.

### 2. Emulate hardware expectations, not just outputs
A screen that "looks right" is not enough. The project aims to preserve the assumptions Zelda makes about NMI timing, RAM layout, PPU register behavior, controller polling, sprite/OAM handling, and audio event flow.

### 3. Verify with evidence
Each milestone has a concrete pass/fail test with defined thresholds. Visual success alone is not enough.

### 4. Prefer structural fixes over manual patches
If the port breaks because the translator, shim, or test infrastructure is incomplete, fix the structure instead of piling on one-off hacks.

---

## Architecture

### Register Allocation

| M68K Register | Purpose |
|---|---|
| `D0` | 6502 accumulator (`A`) |
| `D2` | 6502 `X` |
| `D3` | 6502 `Y` |
| `D7` | NES stack pointer shadow |
| `A4` | NES RAM base (`$FF0000`) |
| `A5` | NES stack base / translated stack support |

### NES RAM Mapping

NES work RAM (`$0000-$07FF`) is mapped into Genesis RAM at `$FF0000-$FF07FF`. Translated accesses use `(offset,A4)`. Additional shim / PPU-side state lives in a reserved Genesis RAM block beyond `$FF0800`.

### VDP Layout

| Address | Content |
|---|---|
| `$0000-$AFFF` | CHR-derived tile data |
| `$B000-$B7FF` | Window plane / HUD |
| `$C000-$CFFF` | Plane A (main playfield) |
| `$D800-$DA7F` | Sprite attribute table |
| `$DC00-$DF7F` | H-scroll table |
| `$E000-$EFFF` | Plane B / staging (role changes to active display if dual-plane mirroring is selected at T11b) |

### MMC1 Mapper Handling

Zelda uses the MMC1 mapper. In the transpiler approach all code banks are assembled into one binary, so cross-bank *code* calls work by construction — no runtime PRG bank switching is needed. However three MMC1 behaviors require explicit emulation:

| MMC1 behavior | When it matters | Planned milestone |
|---|---|---|
| **CHR bank register** | Zelda switches CHR banks to select which 4KB graphics bank is "active" for PPU reads. The active bank determines which tile data is uploaded to Genesis VRAM. | T16/T17 (CHR upload) — **depends on T11b** |
| **Nametable mirroring mode** | Zelda switches between horizontal (overworld) and vertical (dungeon) nametable mirroring via MMC1 register 0 bits 2–3. This changes which nametable addresses map to which VDP plane addresses. | T18 (nametable transfer) — must handle both modes |
| **PRG-RAM enable** | MMC1 controls whether the $6000–$7FFF save RAM is enabled and write-protected. Required for save/load. | T45 (save/load) |

**Nametable mirroring** is the highest-risk item because it affects every room transition (overworld ↔ dungeon). Zelda flips between horizontal mirroring (overworld — shared vertical scroll) and vertical mirroring (dungeons — shared horizontal scroll). The shim must dynamically remap VRAM addresses or plane usage on the fly. Two implementation paths are under consideration:

1. **VRAM address translation**: Every nametable write passes through a translation step that remaps the target address based on current mirroring mode. Simpler to implement, but adds per-write overhead on a hot path.
2. **Dual-plane swap**: Use both Plane A and Plane B, swapping which plane is "live" based on mirroring mode. Cleaner at runtime, but more complex initial setup and requires careful coordination with the scroll registers.

A provisional decision will be made during T11b implementation based on complexity and estimated overhead. This decision is revisable — actual shim overhead is not profiled until T21, so if the chosen approach turns out to be too expensive under real rendering load, T21 is the checkpoint where the mirroring strategy can be changed before it propagates further.

**CHR banking** interacts directly with the tile decode/upload pipeline. The CHR bank register determines *which* 4KB window the game's PPU writes target, so the tile upload pipeline (T16/T17b) must know the current CHR bank state at upload time. T16 and T17b therefore have an explicit dependency on T11b. T17a (pure decode correctness) can be validated independently.

MMC1 state tracking (CHR bank register, mirroring mode, PRG-RAM enable) is stored in Genesis RAM alongside the PPU state block.

### Graphics Pipeline Constraints

**VBlank cycle budget**: The Genesis 68000 has roughly 4,500 cycles of active VBlank. A full 256-tile CHR bank upload (8KB of NES 2bpp → 16KB of Genesis 4bpp) will not fit in a single frame. The tile upload pipeline must use staged uploads across multiple frames or a dirty-tile tracking system that only uploads changed tiles.

**Attribute/palette mapping**: NES attribute bytes assign palettes in 16×16 pixel blocks (2×2 tile quadrants), each selecting one of four 4-color palettes. Genesis tiles carry per-tile palette indices. The shim must expand attribute data to per-tile granularity during nametable transfer, increasing data volume per frame.

**Shim overhead on hot paths**: Every PPU register write going through a subroutine call adds up. Shim cost per frame must be profiled at T21 (first visible rendering). T21 is also the checkpoint where the nametable mirroring strategy chosen provisionally at T11b can be revisited if overhead is too high.

### Sprite / OAM Constraints

Zelda's metasprite system and OAM writes are timing-sensitive. The staging buffer approach should work, but several areas need explicit validation:

- **Sprite priority**: NES sprite priority (lower OAM index = higher priority) must be correctly mapped to the Genesis sprite link chain.
- **Coordinate translation during scrolling**: This is where subtle bugs hide. T28 must include a scrolling test case.
- **Flips and palette**: Horizontal/vertical flip bits and palette selection must map correctly from NES OAM format to Genesis sprite table format.

### Controller Button Mapping

The NES has 8 buttons; the Genesis 3-button pad has 4 (A, B, C, Start) plus D-pad. Fixed mapping:

| NES button | Genesis button |
|---|---|
| A | B |
| B | A |
| Start | Start |
| Select | C |
| D-pad | D-pad |

This puts NES A on Genesis B (right face button, matching the NES rightmost-primary convention) and NES B on Genesis A. Select → C is required because Zelda uses Select for the inventory/map screen. The shim must correctly translate all 8 NES button bits through this mapping.

### Controller Read Path

There are two layers between a physical Genesis button press and the translated Zelda code seeing input:

**Layer 1 — Genesis hardware read + translation (shim):** The shim reads the Genesis controller I/O ports (`$A10003`/`$A10005`) once per frame during VBlank, translates the physical button state through the mapping table above, and writes the result as an NES-format input byte into a known RAM location (the same address the translated Zelda code expects to find controller state, e.g. `$FF00F8`).

**Layer 2 — NES-side serial/strobe semantics (translated code):** The original Zelda code reads controllers via `$4016`/`$4017` using a strobe-then-shift protocol. The transpiled version of this routine (`ReadControllers` or equivalent) emits writes to `$4016` (strobe) and reads from `$4016`/`$4017` (serial shift). The shim intercepts these: the strobe write latches the current translated input byte, and each subsequent read returns the next bit in NES serial order (A, B, Select, Start, Up, Down, Left, Right).

This two-layer design preserves the original `ReadControllers` logic in the translated code (accuracy-first) while sourcing the actual button state from Genesis hardware. The alternative — stubbing out `ReadControllers` entirely and writing directly to the game's input RAM — would be simpler but would bypass the original input processing path, which could miss game-specific input filtering or timing.

**Probe implications:** T26 tests Layer 2 in isolation (does the strobe/shift protocol return correct bit patterns when the shim's input byte is pre-loaded?). T27 tests the full path from Layer 1 through Layer 2 (does a physical Genesis button press end up as the correct bit in the game's input RAM after `ReadControllers` runs?).

### Audio Bridge

The NES APU and Genesis YM2612+PSG are fundamentally different architectures. The intended bridge approach is:

**Sequencer interception**: The transpiled Zelda code already emits all the original APU register writes (`_apu_write_*` stubs). The shim accumulates these as timestamped events — one entry per register write, per frame. A Genesis-side sequencer consumes this event stream each NMI and drives YM2612/PSG equivalents.

| NES channel | Genesis target | Notes |
|---|---|---|
| Pulse 1 / 2 | YM2612 FM channels 1 / 2 | Duty cycle → operator feedback |
| Triangle | YM2612 FM channel 3 (sustained, no vibrato) | Triangle's timbre is hard to match with FM; requires patch iteration |
| Noise | PSG noise channel | PSG noise is a closer match to NES noise than most expect |
| DPCM (samples) | Silent stub | Out of scope for initial target |

This preserves the original music data flow without re-authoring. **Volume balancing** will require tuning — the NES APU's volume curves are nonlinear and the relative balance across channels will not translate 1:1.

Audio is deferred to T42–T44 as a deliberate priority decision, not because the architecture is unknown.

### Hand-Edit Tracking

Generated code in `src/zelda_translated/` should not be hand-edited. When a hand-edit is genuinely required (self-modifying code, untranslatable patterns, deliberate exceptions), it must be tracked:

1. Add a comment block immediately above the edit:
   ```asm
   ; HAND-EDIT: <reason> — auto-overwrite risk. See patches/z_XX_patch_NNN.md
   ```
2. Add a corresponding entry in `src/zelda_translated/patches/` describing what was changed, why, and what the transpiler would have emitted.
3. If the transpiler regenerates the file, the hand-edit must be reapplied from the patch file.

The `transpile_6502.py` script should eventually support an `--apply-patches` mode that replays tracked patches automatically after generation. **Until `--apply-patches` is implemented, hand-edits must be manually reapplied after every transpiler run. This is a live risk.**

### Key Translation / Compatibility Decisions

- **Table-jump support**: Zelda uses 6502 dispatch patterns that must be translated into equivalent M68K indexed control flow.
- **Alignment safety**: Generated labels must stay on even addresses so code never becomes unexecutable due to odd alignment.
- **Carry behavior translation**: 6502 `CMP/CPX/CPY/SBC` carry behavior does not map directly to M68K and must be handled explicitly.
- **`RTI` handling**: Zelda's NMI logic is invoked through the Genesis-side interrupt path and must return consistently with the chosen calling structure.
- **`SEI` handling**: Interrupt masking cannot be naively copied if it would suppress required Genesis VBlank behavior.
- **Exception forensics**: Bus/address/default exception handlers dump fault information into RAM for emulator-side inspection.

---

## Testing Philosophy

Every major feature should be tested at the lowest useful level before it is judged visually complete.

Preferred validation methods: probe scripts, forced fault tests, watched RAM diffs, execution landmarks, side-by-side screenshot comparisons, deterministic replay comparisons, long-run soak tests.

---

## Regression Testing

`tools/run_all_probes.bat` runs every probe in sequence and writes a combined pass/fail summary to `builds/reports/regression_summary.txt`. Re-run:

- after any change to `nes_io.asm`
- after any transpiler change that regenerates `src/zelda_translated/`
- before advancing to the next milestone group

### Probe Registry

Update as probes are added.

| Probe | Milestone | Output |
|---|---|---|
| `bizhawk_boot_probe.lua` | T7/T8/T9/T10/T11 | `bizhawk_boot_probe.txt` |
| `bizhawk_ppu_latch_probe.lua` | T12 | `bizhawk_ppu_latch_probe.txt` |
| `bizhawk_ppu_increment_probe.lua` | T13 | `bizhawk_ppu_increment_probe.txt` |
| `bizhawk_ppu_ctrl_probe.lua` | T14 | `bizhawk_ppu_ctrl_probe.txt` |
| `bizhawk_scroll_latch_probe.lua` | T15 | `bizhawk_scroll_latch_probe.txt` |
| `bizhawk_mmc1_probe.lua` | T11b | `bizhawk_mmc1_probe.txt` |

---

## Milestones

### Foundation

| # | Name | What | Pass Condition |
|---|---|---|---|
| **T1** | Genesis shell boots | Vector table, stack, startup path, VDP init, VBlank ISR stub | ROM boots to a stable screen with no exception |
| **T2** | Exception forensics live | Crash handlers save useful fault state to RAM | Forced fault produces readable dump at known RAM address |
| **T3** | Fixed bank transpiles | `Z_07` translates cleanly | Generated fixed bank assembles with zero errors and zero warnings |
| **T4** | Full codebase transpiles | All Zelda banks translate | All 8 generated bank files exist and assemble with zero errors |
| **T5** | Full ROM assembles | Shell + shim + translated banks build together | ROM builds with valid Genesis header, size ≥ 128KB, zero assembler errors |

### Boot / Timing / Memory

| # | Name | What | Pass Condition |
|---|---|---|---|
| **T6** | Reset vector runs | Zelda reset path executes on Genesis | PC reaches `IsrReset` entry point (address confirmed via listing) |
| **T7** | Reset trace sanity | Major boot routines occur in expected order | Probe detects all expected landmarks in correct sequence: `IsrReset` → `WarmBootings` → `ColdBootings` → `LoopForever` (or equivalent translated labels) |
| **T8** | Frame/NMI cadence works | VBlank ISR and Zelda NMI path behave once per frame in the correct order | NMI count / frame count ratio within 99–101% over 300 frames; zero double-NMI events |
| **T9** | No hidden exceptions | Early execution is stable | 300-frame soak produces zero exception dumps |
| **T10** | NES RAM map is sound | Zelda RAM assumptions hold through Genesis RAM mirror | Probe reads from `$FF0000`–`$FF07FF` succeed; `PPUCTRL` shadow location contains expected post-init value ($B0) |
| **T11** | RAM snapshot parity | Selected pre-PPU RAM regions match NES after fixed boot | RAM diff of zero page ($FF0000–$FF00FF) and stack pointer shadow at `LoopForever` entry: zero mismatched bytes |
| **T11b** | MMC1 state tracking (Zelda init + transitions) | CHR bank register, nametable mirroring mode, and PRG-RAM enable are tracked in Genesis RAM and update correctly when the game writes to $8000/$A000/$C000/$E000. Note: this validates MMC1 state as Zelda's code uses it, not pure MMC1 hardware semantics in isolation — the pass conditions assume Zelda's specific init and transition sequences | MMC1 probe: (1) after `IsrReset` completes, mirroring mode = horizontal (MMC1 powers on single-screen; `IsrReset` explicitly sets horizontal — probe must fire after init, not at power-on); (2) after forced dungeon-entry write sequence, mirroring mode = vertical; (3) CHR bank register reflects last written value; (4) all three registers readable at known RAM addresses |

### PPU Register Behavior

| # | Name | What | Pass Condition |
|---|---|---|---|
| **T12** | PPUADDR latch works | `$2006` high/low latch and `$2007` write path behave correctly | 7 probe checks: high byte, low byte, combined address, write lands at target, latch resets after write, second address pair works, no cross-contamination |
| **T13** | PPU increment mode works | `$2007` increments correctly based on control state | 10 probe checks: +1 mode sequential writes form consecutive addresses; +32 mode sequential writes form column pattern; row wrap at nametable boundary |
| **T14** | PPUCTRL / PPUMASK / PPUSTATUS semantics | `$2000/$2001/$2002` behavior is close enough for Zelda | 9 probe checks: PPUCTRL write/readback, NMI enable bit, base nametable bits, vblank flag set/clear on PPUSTATUS read, sprite size bit |
| **T15** | Scroll latch correctness | `$2005` write ordering and scroll state are correct | Probe: first write sets X scroll, second write sets Y scroll, latch toggles correctly, `$2002` read resets latch; all 4 checks pass |

### Graphics Pipeline

**Dependencies**: T16 and T17b depend on T11b (MMC1 state tracking) because CHR bank state determines which tile data is uploaded. T17a (pure decode correctness) has no T11b dependency and can run in parallel. T18 depends on T11b for nametable mirroring mode.

**Known constraint**: VBlank cycle budget (~4,500 68000 cycles) is insufficient for a full 256-tile CHR upload in one frame. The upload strategy must support staged/partial transfers from the start.

| # | Name | What | Pass Condition |
|---|---|---|---|
| **T16** | CHR upload path works | NES graphics data reaches Genesis VRAM (respecting current CHR bank state from T11b) | ≥ 64 non-zero tiles present in VRAM range `$0000`–`$AFFF` after boot + CHR upload sequence |
| **T17a** | Tile decode correctness | NES 2bpp → Genesis 4bpp conversion is bit-accurate in isolation (no dependency on T11b) | 8 known reference tiles (selected from title screen CHR, fed as raw input) decoded and compared byte-for-byte against precomputed expected output; zero mismatches |
| **T17b** | Bank-aware tile pipeline | Tile decode respects live CHR bank state from T11b; correct bank's tiles reach VRAM | After CHR bank switch, uploaded tiles match the newly selected bank's data, not the previous bank's; 8-tile spot check, zero mismatches |
| **T18** | Nametable transfer works | Background tile indices populate the active playfield plane(s) correctly; both mirroring modes produce correct visible layout | Tilemap viewer shows expected tile indices for (a) horizontal mirroring test case and (b) vertical mirroring test case; ≤ 2 tile-index mismatches per 32×30 nametable |
| **T19** | Palette writes reach CRAM | NES palette updates become visible Genesis colors | All 4 background palettes (16 entries) present in CRAM; zero mismatches against precomputed NES→Genesis color mapping table |
| **T20** | Attribute/palette mapping works | NES attribute bytes map correctly to Genesis palette selection (expanded from 2×2 tile quadrant granularity to per-tile) | 8×8 attribute test region: ≤ 1 tile with incorrect palette assignment per 16×16 attribute block |
| **T21** | Title screen background appears | Core background rendering is visible and stable; first VBlank budget checkpoint | Title screen background appears without corruption; shim overhead profiled: total VBlank shim time ≤ 3,000 of ~4,500 available cycles (binding — if exceeded, shim must be optimized or mirroring/upload strategy revisited before advancing to T22). Measurement method: instrumented cycle counter in `nes_io.asm` — read 68000 timer or VDP HV counter at VBlank entry and exit, write delta to a known RAM address, probe reads the value. Note: T21 is the first binding budget gate but not the last — later milestones adding sprites (T24), HUD (T31), and scrolling rooms (T30/T35) increase VBlank pressure and should be re-profiled if budget was near the limit here |
| **T22** | Title screen parity | Title screen layout, palette regions, and structure match NES closely | Three checks: (1) nametable index accuracy inherits T18 threshold: ≤ 2 tile-index mismatches in 32×30 tilemap; (2) visual output match (rendered tile comparison accounting for CHR decode + palette + attribute mapping): ≤ 8 visually incorrect tiles (tiles whose indices are correct but whose rendered pixels differ due to CHR, palette, or attribute errors); (3) RAM checkpoint: diff `$FF0000`–`$FF00FF` against NES trace at same frame, ≤ 4 mismatched bytes |

### Sprites / Input / Front-End Flow

| # | Name | What | Pass Condition |
|---|---|---|---|
| **T23** | OAM write semantics work | `$2003/$2004` staging behavior is correct enough for Zelda | Staging buffer contains expected Y, tile, attribute, X values for ≥ 4 test sprites written via `$2004` sequential writes |
| **T24** | Sprite transfer/display works | OAM-derived data reaches Genesis sprite table correctly; NES sprite priority maps to Genesis sprite link chain | ≥ 4 sprites visible at correct screen positions (±1 pixel); overlapping sprites render in correct priority order |
| **T25** | Link sprite appears correctly | Player metasprite composition is basically correct | Link's 2×2 metasprite (4 tiles) renders at expected position with correct tile IDs; no missing or duplicated tiles |
| **T26** | Controller strobe/shift semantics (Layer 2) | NES-side `$4016`/`$4017` serial protocol works correctly in isolation | Probe pre-loads shim input byte with known button state, then runs translated `ReadControllers` strobe/shift sequence; output bits arrive in correct NES serial order (A, B, Select, Start, Up, Down, Left, Right) for all 8 buttons |
| **T27** | Full controller path (Layer 1 + Layer 2) | Genesis physical button presses flow through shim hardware read, translation, strobe/shift, and into the game's input RAM | Each Genesis button (Gen A, Gen B, Gen C, Gen Start, D-pad) sets the expected NES-logical bit in the game's input RAM location (`$FF00F8` or equivalent) after `ReadControllers` completes; all 8 NES buttons confirmed through the full path. Mapping: NES A→Gen B, NES B→Gen A, NES Select→Gen C, NES Start→Gen Start, D-pad→D-pad |
| **T28** | Sprite attribute fidelity | Flips, priority, palette, size, and coordinates are correct under both static and scrolling conditions | 6 test cases pass: (1) H-flip, (2) V-flip, (3) palette index, (4) behind-background priority, (5) correct position while scrolled, (6) correct position at scroll boundary |
| **T29** | File select flow works | Title → file select → new game path is usable | Scripted input sequence: NES Start bit → file select screen renders → cursor moves via NES D-pad bits → NES A bit selects file → game mode transitions; all 4 transitions occur |

### Gameplay Bring-Up

| # | Name | What | Pass Condition |
|---|---|---|---|
| **T30** | Room render path works | A real gameplay room loads and displays | Opening room (overworld $77): ≥ 80% of 32×22 playfield tiles are non-zero; no exception dump |
| **T31** | HUD / window plane works | HUD and playfield coexist correctly | HUD hearts/rupees/keys visible in window plane region; zero tile corruption in playfield rows below HUD |
| **T32** | Room render parity | Room tilemap, palette, and major sprite placements match NES closely | Opening room side-by-side: ≤ 8% tile mismatches in playfield; palette regions match; RAM checkpoint: diff `$FF0000`–`$FF07FF` against NES trace at same game state, ≤ 16 mismatched bytes |
| **T33** | Link movement works | Position and animation update from controller input | 60-frame scripted input (hold Right 30 frames, hold Down 30 frames): Link's X position increases by ≥ 36 pixels, then Y position increases by ≥ 36 pixels (expected ~45 each at 1.5 px/frame; threshold is 80% to allow minor timing variance) |
| **T34** | Collision semantics work | Walls, water, doors, and solids behave correctly | 4 collision cases: (1) wall stops movement, (2) water blocks entry, (3) cave entrance triggers transition, (4) open path allows movement; all 4 pass |
| **T35** | Room transitions work | Door / edge transitions load the next room correctly; nametable mirroring switch (overworld ↔ dungeon) must not corrupt display | Walk to screen edge → new room loads with non-zero tilemap; enter dungeon → mirroring switches and room renders without corruption; 2/2 transitions pass |
| **T36** | Opening-room accuracy target met | First strong gameplay benchmark | Opening room matches NES: ≤ 5% tilemap mismatches, ≤ 2 sprite anchor mismatches, palette regions correct, Link position matches within ±2 pixels after identical 120-frame input movie |

### Core Gameplay Fidelity

| # | Name | What | Pass Condition |
|---|---|---|---|
| **T37** | Core enemy logic survives | Basic enemy spawn/update/render loop behaves correctly | 3 enemy types (Octorok, Tektite, Peahat) spawn, move, and render without crash over 300 frames; position updates are non-zero |
| **T38** | Combat semantics work | Sword hits, damage, knockback, and invulnerability behave correctly | Sword swing → Octorok hit: (1) enemy HP decreases, (2) knockback displacement ≥ 4 pixels, (3) invulnerability timer set; Link hit by enemy: (4) Link HP decreases, (5) Link knockback occurs; 5/5 pass |
| **T39** | Deterministic replay parity | Same starting state + same inputs produce the same results | Fixed 1,800-frame input movie from new-game start: player position, room ID, HP, and RNG state at frame 1800 match across 3 consecutive runs; zero divergence |
| **T40** | Multi-room gameplay stability | Gameplay remains stable across several rooms/minutes | 5-minute scripted play session traversing ≥ 8 rooms: zero exception dumps, zero hard locks, mean emulated frame cadence remains within 99% of native NTSC rate, with no sustained slowdown below 98% for more than 120 consecutive frames. Measurement method: Lua probe reads BizHawk's `emu.framecount()` and `os.clock()` each frame, logs the ratio of emulated frames to wall-clock seconds; compare against 59.922 Hz NTSC target |
| **T41** | Long-run soak stability | Runtime does not drift, corrupt, or crash over time | 30-minute unattended soak (idle at opening room + periodic random input): zero exception dumps, zero corruption in watched RAM regions (`$FF0000`–`$FF07FF`), stack pointer within expected bounds |

### Audio / Persistence / Finish Line

| # | Name | What | Pass Condition |
|---|---|---|---|
| **T42** | Music event path works | Zelda music engine emits sane translated event flow | ≥ 20 APU register write events logged per second during title screen music; event stream is stable (no runaway writes, no silence gaps > 500ms) |
| **T43** | Sound effect path works | Core SFX triggers reach the audio layer | 4 SFX confirmed: menu cursor, sword swing, enemy hit, item pickup; each produces ≥ 1 APU event within 2 frames of trigger |
| **T44** | Audio playback reaches target | Music and SFX are acceptably faithful | Title screen music: correct note sequence for first 8 bars (compared against reference MIDI/frequency log); overworld theme: recognizable melody with correct tempo ±10% |
| **T45** | Save/load correctness | File creation, persistence, and reload behavior work | Create file → save → reset → reload: player name, room ID, HP, inventory match pre-reset state; zero mismatches |
| **T46** | Quest-start playable | Quest 1 can be started and played normally | Human tester can: boot → NES Start to begin → move Link via D-pad → enter cave → NES A to get sword → exit → NES B to swing sword and fight enemy → transition 3 rooms; no crash, no softlock |
| **T47** | Broad gameplay parity sweep | Multiple rooms, UI flows, enemies, and interactions pass regression | 20-item parity checklist covering: 4 overworld rooms, 2 dungeon rooms, 3 enemy types, 2 items, HUD updates, 2 transitions, file select, death/continue, pause, sword beam; ≥ 18/20 pass |
| **T48** | Accuracy-first baseline complete | Port is out of bring-up and into refinement | All automated probes pass in `regression_summary.txt` with zero regressions; manual acceptance milestones (T44 audio fidelity, T46 human playability, T47 parity sweep) individually signed off |

---

## Known Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **Nametable mirroring switches** | Affects every overworld ↔ dungeon transition; incorrect remapping corrupts display | Dedicated MMC1 probe (T11b), explicit T18 validation for both modes, T35 cross-mode transition test |
| **VBlank cycle budget** | Full CHR upload won't fit in one frame; overrun causes visual tearing or missed frames | Design staged/dirty-tile upload from T16; profile shim overhead at T21 |
| **Shim overhead accumulation** | Per-write subroutine cost on PPU hot paths compounds as more systems come online | Profile at T21, optimize before T30 |
| **Transpiler edge cases** | Self-modifying code, RTS-as-jump-table, rare 6502 patterns produce broken output | Hand-edit tracking system, patch files, future `--apply-patches` mode |
| **NES APU → Genesis audio mapping** | FM voices cannot perfectly replicate NES pulse/triangle timbre; volume curves are nonlinear | Iterative patch tuning; target is recognizable melody with correct tempo, not identical waveform |
| **Attribute-to-per-tile palette expansion** | Increases data volume per nametable transfer frame | Factor into VBlank budget; may need staged attribute updates |
| **Hand-edit loss on transpiler re-run** | `--apply-patches` does not exist yet; every transpiler run silently overwrites hand-edits in `src/zelda_translated/`. Silent regression of manual fixes | Patch files in `patches/` directory act as re-apply recipes; manual reapplication required after every transpiler run until `--apply-patches` is implemented. Implementing `--apply-patches` should be prioritized once the first hand-edit is needed |

---

## Current Status

**Completed through T14** (2026-04-01), with probe evidence for each. T15 probe is written and pending run.

| Milestone | Status | Evidence |
|---|---|---|
| T1–T5 | ✓ Complete | Shell, forensics, transpiler, ROM assembly |
| T6 | ✓ Complete | PC reaches IsrReset → LoopForever |
| T7 | ✓ Complete | Boot probe 6/6 PASS — all landmarks in order |
| T8 | ✓ Complete | Boot probe 2/2 PASS — NMI cadence 100.4%, no double-NMI |
| T9 | ✓ Complete | Boot probe 1/1 PASS — 300 frames clean |
| T10 | ✓ Complete | Boot probe 3/3 PASS — RAM readable, PPUCTRL set |
| T11 | ✓ Complete | Boot probe 3/3 PASS — zero page + SP snapshot parity at LoopForever entry, zero mismatched bytes |
| T11b | Pending | MMC1 state tracking not yet implemented or tested |
| T12 | ✓ Complete | PPU latch probe 7/7 PASS — VRAM writes at correct addresses |
| T13 | ✓ Complete | PPU increment probe 10/10 PASS — sequential writes, row wrap |
| T14 | ✓ Complete | PPU ctrl probe 9/9 PASS — PPUCTRL=$B0, PPUSTATUS semantics |
| T15 | In progress | Scroll latch probe written; pending run |

### Immediate Next Steps

1. Run T15 scroll latch probe
2. Implement T11b (MMC1 state tracking + dedicated probe)
3. T17a (pure tile decode correctness) can run in parallel with T11b — no MMC1 dependency
4. Begin T16 (CHR upload path) and T17b (bank-aware pipeline) — both blocked on T11b

---

## Development Priorities

1. Translator correctness
2. Hardware behavior fidelity
3. Probe quality
4. Deterministic reproducibility
5. Visible polish

Accuracy comes from structure, not cosmetics.
