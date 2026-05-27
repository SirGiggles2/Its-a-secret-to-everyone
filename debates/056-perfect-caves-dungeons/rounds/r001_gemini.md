Warning: True color (24-bit) support not detected. Using a terminal with true color enabled will result in a better visual experience.
YOLO mode is enabled. All tool calls will be automatically approved.
YOLO mode is enabled. All tool calls will be automatically approved.
Ripgrep is not available. Falling back to GrepTool.
Error executing tool read_file: File not found.
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 1s.. Retrying after 5546ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 3s.. Retrying after 5398ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 5s.. Retrying after 6659ms...
(node:12024) [DEP0190] DeprecationWarning: Passing args to a child process with shell option true can lead to security vulnerabilities, as the arguments are not escaped, only concatenated.
(Use `node --trace-deprecation ...` to show where the warning was created)
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 4s.. Retrying after 5017ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 2s.. Retrying after 5145ms...
To achieve **100% byte-exact parity** (NES-to-Genesis) across all 56 cave and dungeon interior scenarios, we must move from "templated rendering" to a strict **Oracle-driven validation model**. 

The "Perfect" definition requires that after normalization (NES 4-byte OAM → Gen 8-byte SAT, NES PALRAM → Gen CRAM via LUT), the resulting Genesis VDP state is bit-identical to the NES ground truth.

---

### Phase 1: The Interior Oracle (Knowledge Extraction)
We cannot rely on the current lenient verifier. We need a manifest of exactly what NES expects.
1.  **Extract Cave Layouts:** Script `reference/aldonunez/Z_01.asm` and `dat/Cave*.dat` to build `manifest_interiors.json`.
    - Map **Cave ID ($6A..$7D)** → {PersonID, Item1-3, Price1-3, TextID, BonfireMask}.
    - Map **Dungeon Entry/Exit** → {RoomID, LevelID, PaletteIndex}.
2.  **Define Translation Rules:**
    - **Color LUT:** Formalize the 64-entry NES color index → Genesis CRAM word mapping.
    - **Tile ID Map:** Create a static mapping for Cave BG tiles and Person CHR to Genesis VRAM addresses.

### Phase 2: NES Ground Truth (Baseline Capture)
We need the "Golden Bytes" from a running NES.
1.  **Implement `RoomRom/probe_nes_interior_baseline.lua`:**
    - Uses Mesen/FCEUX to iterate all 56 scenarios.
    - Force `GAME_MODE = $0B` (Cave) or `$07` (Dungeon).
    - Set `ObjType+1` and other state vars from the manifest.
    - Wait for `FrameCounter` to stabilize (stable OAM/Text).
    - Dump `OAM` (256 bytes), `PALRAM` (32 bytes), and `CIRAM` ($2000-$23FF) to `baseline/{scenario}_nes.bin`.

### Phase 3: Port Completion (Fixing D1–D4)
Complete the Genesis implementation in `src/game/cave/cave_dispatch.c` and `enemy_loop.c`.
1.  **D1: Bonfire SAT:** Modify `cave_tick` to explicitly update bonfire slots 2 and 3. Ensure `enrt_update_standing_fire` is called with `ENEMY_THROWER_SLOT` set correctly so they hit the SAT cache.
2.  **D2: Person OAM:** Update `cave_draw_person` to use `PersonType` from the manifest instead of just the `cave_id`. Map `Old Man`, `Merchant`, and `Woman` to their specific Genesis sprite tiles/palettes.
3.  **D3: Textbox States:** Implement the missing transitions for states 1, 3, 6, 7. Ensure state 3 (clear wares) and state 6 (terminal) correctly wipe the OAM/SAT for those slots.
4.  **D4: BCD Price Formatting:** Align `cave_format_decimal_byte` and the dynamic transfer buffer writer with NES edge cases (e.g., specific sign placement for negative door-repair amounts).

### Phase 4: Genesis State Capture (The Probe)
1.  **Implement `RoomRom/probe_roomrom_interior.lua`:**
    - Orchestrate the Genesis port to warp to the 56 scenarios.
    - Dump the raw **SAT (internal cache)**, **CRAM**, and **Plane A (VRAM)**.
    - Output to `out/{scenario}_gen.bin`.

### Phase 5: The Byte-Exact Verifier
Create `RoomRom/verify_interior_parity.py` to perform the "Perfect" check.
1.  **Normalization Loop:**
    - **Palette:** `NES_PAL[i] == LUT(GEN_CRAM[i])`.
    - **OAM:** Iterate 64 NES sprites. Translate $(Y, X, Tile, Attr)$ → Genesis SAT record. 
    - **Plane A:** Compare nametable tiles after normalizing for Genesis VRAM base offsets.
2.  **Strict Mode:** Fail on any pixel/byte mismatch, including "hidden" sprite attributes or unused nametable cells.

### Phase 5: Iteration & CI Integration
1.  **Execute:** `powershell.exe ./RoomRom/build.bat && python ./RoomRom/verify_interior_parity.py`.
2.  **Debug:** Use `overlay_state.lua` to visually highlight diffs in real-time (e.g., flashing red on Genesis tiles that don't match NES).
3.  **Completion:** All 56 scenarios (20 Caves + 36 Dungeon Entry/Exits) return `PASS`.

---

### Sequence of Action
1.  **Turns 1-3:** Create `manifest_interiors.json` and the NES baseline probe.
2.  **Turns 4-8:** Fix D1-D4 in `cave_dispatch.c`.
3.  **Turns 9-12:** Build the Python verifier and run the first "Total Pass" attempt.
4.  **Turns 13+:** Surgical fixes for remaining byte-diffs.

**Next Step:** I will begin by extracting the Cave/Dungeon data from the NES source to build the `manifest_interiors.json`.
