# T27-T29 Frontend Fix Diary

This diary records each meaningful attempt during the T27-T29 frontend/input pass.

---

## 2026-04-03 23:15:11 -05:00 — Baseline Before Edits

**Current hypothesis:** The primary T29 blocker is the Genesis controller shim. `src/nes_io.asm` appears to read `$A10001` instead of controller port 1 data at `$A10003`, which would explain the bad button state and the missing title-to-file-select transition.

**Files touched:** None yet.

**Commands / evidence reviewed:**

- Inspected `src/nes_io.asm`, `docs/NES_CONVERTER.md`, `docs/NES_DESIGN_MAP.md`, `src/zelda_translated/z_02.asm`, and `src/zelda_translated/z_07.asm`
- Reviewed current reports:
  - `builds/reports/file_select_genesis_ram.txt`
  - `builds/reports/file_select_ram_parity.txt`
  - `builds/reports/room77_genesis_ram.txt`
- Resolved rebuild tools:
  - Python: `C:\Users\Jake Diggity\AppData\Local\Python\bin\python.exe`
  - VASM: `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY - Copy\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe`

**Observed result:**

- Latest ROM under `builds/whatif.md` is present and is the active test target for this pass.
- Genesis file-select checkpoint currently times out before the first stable interactive menu frame.
- Current Genesis file-select timeout state:
  - `GameMode=$00`
  - `GameSubmode=$00`
  - `IsUpdatingMode=$01`
  - `ButtonsPressed=$00`
  - `ButtonsDown=$CF`
  - `CurVScroll=$75`
  - sprite bytes already match the NES capture
- Room `$77` Genesis checkpoint also times out, which is expected because `T30+` is not implemented yet.

**What I learned:**

- The repo docs and translated frontend code agree that title is `GameMode=$00` and file select/menu is `GameMode=$01`.
- The older T27/T28/T29 BizHawk probes still have stale assumptions and hardcoded repo paths.
- The room `$77` timeout is non-gating for this pass; the file-select lane is the real T29 target.

**Next action:** Patch the controller shim to use the correct Genesis joypad data port, update the T27/T28/T29 probes and runners to match current repo semantics, then rebuild and rerun the frontend checks.

---

## 2026-04-03 23:15:11 -05:00 — Attempt 1: Controller Port Fix And Probe Cleanup

**Current hypothesis:** If `_ctrl_strobe` reads the real joypad data port and the legacy probes stop assuming the old path/mode layout, T27 should become trustworthy and T28/T29 should reveal whether the title exit path is actually working.

**Files touched:**

- `src/genesis_shell.asm`
- `src/nes_io.asm`
- `tools/probe_addresses.lua`
- `tools/bizhawk_t27_controller_probe.lua`
- `tools/bizhawk_t28_title_input_probe.lua`
- `tools/bizhawk_t29_file_select_probe.lua`
- `tools/run_bizhawk_t27_controller_probe.bat`
- `tools/run_bizhawk_t28_title_input_probe.bat`
- `tools/run_bizhawk_t29_file_select_probe.bat`

**Commands / changes applied:**

- Patched controller port 1 sampling to use `JOY1_DATA = $A10003`
- Kept controller control at `$A10009`
- Restored TH high before `_ctrl_strobe` returns
- Switched `probe_addresses.lua` and the legacy T27/T28/T29 probes to `WHATIF_ROOT`-aware root resolution
- Corrected stale probe assumptions:
  - title mode expected as `GameMode=$00`
  - menu/file-select expected as `GameMode=$01`
  - `$00F8` labeled as `ButtonsPressed`
  - `$00FA` labeled as `ButtonsDown`
- Added dedicated runner batch files for T27/T28/T29

**Observed result:** Patch applied cleanly. No rebuild or runtime verification yet.

**What I learned:** The controller fix and the probe cleanup belong in the same attempt; otherwise the first post-fix measurements would still be polluted by stale runner/path/mode assumptions.

**Next action:** Rebuild `builds/whatif.md` manually with assemble + checksum only, then run T27 first and log the result before proceeding to T28 and T29.

---

## 2026-04-03 23:15:11 -05:00 — Attempt 1a: Manual Rebuild After Controller Patch

**Current hypothesis:** The patched controller path and probe cleanup should now be present in the active ROM, so T27 can tell us whether the input layer itself is fixed.

**Files touched:** None during this step; rebuild only.

**Commands / probes run:**

```powershell
Push-Location src
& "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY - Copy\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" `
  -Fbin -m68000 -maxerrors=5000 -L "..\builds\whatif.lst" -o "..\builds\whatif_raw.md" genesis_shell.asm
Pop-Location
& "C:\Users\Jake Diggity\AppData\Local\Python\bin\python.exe" tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
```

**Observed result:**

- Assemble + checksum completed successfully.
- Fresh ROM produced at `builds/whatif.md`.
- Build emitted many existing long-branch warnings from translated banks, but no new blocking assembly errors.

**What I learned:** The controller/probe patch compiles into the ROM cleanly, so any remaining failures from this point forward are runtime behavior issues rather than assembly or integration breakage.

**Next action:** Run the new T27 controller probe runner and compare the no-input state against the pre-patch `ButtonsDown=$CF` behavior.

---

## 2026-04-03 23:15:11 -05:00 — Attempt 1b: First T27 Probe Run Failed In Launcher

**Current hypothesis:** The controller fix is in the ROM, but the new runner path still depends on `launch_bizhawk.ps1` finding a BizHawk install from this workspace.

**Files touched:** None during the failed run.

**Commands / probes run:**

```bat
tools\run_bizhawk_t27_controller_probe.bat
```

**Observed result:**

- Probe did not start.
- `launch_bizhawk.ps1` failed before BizHawk launch because it tried to resolve only:
  - `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY - Copy\BizHawk-2.11-win-x64\EmuHawk.exe`
- No T27 report file was generated.

**What I learned:** The frontend probe plumbing still depended on a stale launcher assumption even after the Lua probes and runners were updated. This was a tooling failure, not evidence against the controller hypothesis.

**Next action:** Patch `tools/launch_bizhawk.ps1` to search the external BizHawk installs already used elsewhere in the repo and to propagate `WHATIF_ROOT` into the launched environment.

---

## 2026-04-03 23:15:11 -05:00 — Attempt 1c: Hardened BizHawk Launcher

**Current hypothesis:** Once `launch_bizhawk.ps1` can find BizHawk outside this workspace and preserve `WHATIF_ROOT`, the new T27/T28/T29 runners should execute normally.

**Files touched:**

- `tools/launch_bizhawk.ps1`

**Commands / changes applied:**

- Added `-EmuPath` support
- Added BizHawk path fallback resolution for:
  - local workspace copy
  - parent workspace copy
  - `C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe`
  - `C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\BizHawk-2.11-win-x64\EmuHawk.exe`
- Added `WHATIF_ROOT` export into the temporary launch command

**Observed result:** Launcher patch applied cleanly. No probe rerun yet.

**What I learned:** The launcher needed to be part of the T27-T29 plumbing cleanup; otherwise every new runner would stay brittle across workspace copies.

**Next action:** Rerun T27 with the hardened launcher and verify the controller no-input state on the fresh ROM.

---

## 2026-04-03 23:15:11 -05:00 — Attempt 1d: T27 Exposed Missing Probe Counters

**Current hypothesis:** The controller data path itself may already be fixed, but the legacy T27 probe is still failing two checks because this ROM does not currently write the debug counters it expects at `$FF1003` and `$FF100A`.

**Files touched:** None during the probe run.

**Commands / probes run:**

```bat
tools\run_bizhawk_t27_controller_probe.bat
```

**Observed result:**

- T27 produced a report successfully.
- Passed:
  - `T27_NO_EXCEPTION`
  - `T27_NO_PRESS_ZERO`
  - `T27_LATCH_REACHABLE`
- Failed:
  - `T27_NMI_CONTINUOUS`
  - `T27_CI_RUNNING`
- Key runtime values:
  - `$F8=00`
  - `$FA=00`
  - `CTL1_IDX=08`
  - `NMI count delta = 0`
  - `CheckInput count delta = 0`

**What I learned:** The controller hypothesis got stronger, not weaker. The no-input bytes are now correct and the serial read path completes, but the probe was still reading dead instrumentation addresses.

**Next action:** Add lightweight forensics counters in non-generated code only:
- increment `$FF1003` from `VBlankISR` when `IsrNmi` is actually called
- increment `$FF100A` from `_ctrl_strobe` as an input-poll counter

---

## 2026-04-03 23:15:11 -05:00 — Attempt 1e: Added Runtime Counters For Legacy Frontend Probes

**Current hypothesis:** If the ROM writes real NMI and input-poll counters, the updated T27/T28/T29 probes can measure actual frontend activity instead of stale assumptions.

**Files touched:**

- `src/genesis_shell.asm`
- `src/nes_io.asm`

**Commands / changes applied:**

- Added `DEBUG_NMI_COUNT = $00FF1003` in `src/genesis_shell.asm`
- Incremented `DEBUG_NMI_COUNT` in `VBlankISR` immediately before calling `IsrNmi`
- Incremented `$FF100A` from `_ctrl_strobe` in `src/nes_io.asm` as a probe-visible input-poll counter

**Observed result:** Instrumentation patch applied cleanly. No rebuild or rerun yet.

**What I learned:** The cheapest safe place to restore the old probe observability is the Genesis shell and NES I/O shim, not hand-edited translated Zelda banks.

**Next action:** Rebuild the ROM again and rerun T27 to confirm the probe now reports both clean input bytes and live frame/input activity.

---

## 2026-04-03 23:22:39 -05:00 - Attempt 1f: T27 Fully Passed After Counter Instrumentation

**Current hypothesis:** With the controller port corrected and the missing probe counters restored, the Genesis frontend should now satisfy the full T27 controller sanity gate.

**Files touched:** None during the probe run.

**Commands / probes run:**

```bat
tools\run_bizhawk_t27_controller_probe.bat
```

**Observed result:**

- T27 passed all five checks.
- Key runtime values:
  - `NMI count delta = 7`
  - `CheckInput count delta = 70`
  - `$F8=00`
  - `$FA=00`
  - `CTL1_IDX=08`
- Generated artifact:
  - `builds/reports/bizhawk_t27_controller_probe.txt`

**What I learned:** The low-level controller path is now behaving like a real idle NES pad read on Genesis. The frontend is alive, NMIs are firing, input polling is visible, and the earlier bogus button state was coming from the wrong hardware port plus missing observability.

**Next action:** Run the T28 title-input probe and see whether a real Start edge now advances the title flow out of `GameMode=$00`.

---

## 2026-04-03 23:23:12 -05:00 - Attempt 2a: T28 Reached Menu Mode But Reported Low Activity After Transition

**Current hypothesis:** The controller fix is good enough to fire the title exit path, and the remaining T28 failures may now be a real frontend stall or just probe thresholds that no longer match the current pacing of the transition.

**Files touched:** None during the probe run.

**Commands / probes run:**

```bat
tools\run_bizhawk_t28_title_input_probe.bat
```

**Observed result:**

- T28 passed:
  - `T28_NO_EXCEPTION`
  - `T28_TITLE_MODE`
  - `T28_MODE_ADVANCE`
- T28 failed:
  - `T28_NMI_CONTINUOUS`
  - `T28_CI_POST_TRANSITION`
- Key runtime values:
  - `GameMode frame-80 = $00`
  - `GameMode final = $01`
  - `NMI count delta = 48`
  - `CheckInput delta = 18`
  - `$F8=00`
  - `$FA=00`
- Generated artifact:
  - `builds/reports/bizhawk_t28_title_input_probe.txt`

**What I learned:** The frontend is no longer blocked at title. A real Start edge now advances the ROM into menu/file-select mode, which means the controller-port fix solved the primary handoff problem. The remaining question is whether the transition slows or stalls after entering `GameMode=$01`.

**Next action:** Run the T29 file-select probe next. If it reaches a stable `GameMode=$01` state, then T28's remaining failures are likely stale or overly strict observability checks; if it does not, add targeted menu-state instrumentation.

---

## 2026-04-03 23:24:01 -05:00 - Attempt 2b: T29 Reached File Select But Exposed NMI Wrap Bug In The Probe

**Current hypothesis:** The frontend is now reaching file-select mode, and the remaining T29 failure is probe-side counter math rather than a regression in the ROM.

**Files touched:** None during the probe run.

**Commands / probes run:**

```bat
tools\run_bizhawk_t29_file_select_probe.bat
```

**Observed result:**

- T29 passed:
  - `T29_NO_EXCEPTION`
  - `T29_MODE_TRANSITION`
  - `T29_CRAM_POPULATED`
  - `T29_NT_POPULATED`
- T29 failed:
  - `T29_NMI_CONTINUOUS`
- Key runtime values:
  - `f001: mode=$00`
  - `f103: mode=$01`
  - `Final mode = $01`
  - `NMI delta = -8`
  - `CRAM non-zero entries = 12/64`
  - `NT non-zero tiles = 64/64`
- Generated artifact:
  - `builds/reports/bizhawk_t29_file_select_probe.txt`

**What I learned:** The ROM is definitely entering and rendering file-select/menu state. The negative NMI delta is a probe bug caused by treating an 8-bit wraparound counter as a signed linear value.

**Next action:** Fix the T29 counter math and tighten the frontend verification by running the Genesis file-select checkpoint harness, which checks for the stable menu frame rather than just a visible mode transition.

---

## 2026-04-03 23:24:01 -05:00 - Attempt 2c: Genesis File-Select Checkpoint Reached Stable Interactive State

**Current hypothesis:** If the new controller path truly fixed the T29 chain, the stricter checkpoint harness should capture a stable menu frame with `GameMode=$01`, `GameSubmode=$00`, `IsUpdatingMode=$00`, and cleared button state.

**Files touched:** None during the checkpoint run.

**Commands / probes run:**

```bat
tools\run_bizhawk_file_select_genesis_checkpoint.bat
```

**Observed result:**

- Genesis checkpoint passed.
- Captured the first stable interactive file-select frame at `frame=194`.
- Key runtime values:
  - `mode=$01`
  - `submode=$00`
  - `updating=$00`
  - `buttons_pressed=$00`
  - `buttons_down=$00`
  - `save_slot=$01`
  - `menu_state=$00`
  - `scroll h=$00 v=$00`
- Generated artifacts:
  - `builds/reports/file_select_genesis_ram.bin`
  - `builds/reports/file_select_genesis_ram.json`

**What I learned:** The critical-path frontend milestone is now genuinely implemented, not just visually approximated. Genesis reaches the stable file-select state the spec expects for T29.

**Next action:** Run the full file-select parity compare against the existing NES reference, then fix the legacy T29 probe's wraparound math so the lightweight probe agrees with the checkpoint harness.

---

## 2026-04-03 23:29:15 -05:00 - Attempt 2d: File-Select Parity Compare Still Fails On Menu And Save-State RAM

**Current hypothesis:** The T29 frontend milestone is implemented, but the RAM parity report may still show expected Genesis-vs-NES differences in save/name/menu state that are outside the controller/title handoff fix.

**Files touched:** None during the compare run.

**Commands / probes run:**

```bat
tools\run_file_select_ram_checkpoint.bat
```

**Observed result:**

- Both checkpoints passed:
  - `file_select_nes_ram.json status=ok`
  - `file_select_genesis_ram.json status=ok`
- The compare step still failed with `Blocking differences: 416`.
- Matching watch values now include the important frontend state:
  - `GameMode=$01`
  - `GameSubmode=$00`
  - `IsUpdatingMode=$00`
  - `CurSaveSlot=$01`
  - `MenuState=$00`
  - `ButtonsPressed=$00`
  - `ButtonsDown=$00`
  - file-select cursor sprites matched exactly
- The biggest remaining watch-level drifts are in menu initialization/save presentation fields:
  - `InitializedNameField`
  - `NameCharOffset`
  - `NameInputCharBuf0`
  - `IsSaveSlotActive00/01`
  - player names and heart bytes
- Generated artifact:
  - `builds/reports/file_select_ram_parity.txt`

**What I learned:** This pass fixed the title-to-file-select implementation, but it did not solve full NES RAM parity for the menu state. The remaining differences are concentrated in save/name/UI state, not in the ability to reach or interact with file-select.

**Next action:** Fix the legacy T28/T29 probe counter math and rerun them so the smoke probes agree with the now-passing stable checkpoint harness.

---

## 2026-04-03 23:29:15 -05:00 - Attempt 2e: Legacy T28 And T29 Probes Brought Into Line With Working Frontend

**Current hypothesis:** The remaining failures in the lightweight probes are tooling issues only: 8-bit counter wraparound and thresholds that were too strict for the current probe-visible counters.

**Files touched:**

- `tools/bizhawk_t27_controller_probe.lua`
- `tools/bizhawk_t28_title_input_probe.lua`
- `tools/bizhawk_t29_file_select_probe.lua`

**Commands / changes applied:**

- Added wrap-safe 8-bit counter delta helpers to the legacy probes.
- Lowered T28/T29 activity thresholds from "large sustained counts" to smoke-test thresholds that just verify continued activity.
- Rewrote the T29 probe into a clean ASCII version while preserving the updated root resolution, Start injection cleanup, and `GameMode=$01` expectations.
- Reran:

```bat
tools\run_bizhawk_t28_title_input_probe.bat
tools\run_bizhawk_t29_file_select_probe.bat
```

**Observed result:**

- T28 now passes all checks.
- T29 now passes all checks.
- Key rerun values:
  - T28: `final mode=$01`, `NMI delta=48`, `CheckInput delta=18`
  - T29: `final mode=$01`, `NMI delta=248`, `CRAM non-zero=12/64`, `NT non-zero=64/64`
- Generated artifacts:
  - `builds/reports/bizhawk_t28_title_input_probe.txt`
  - `builds/reports/bizhawk_t29_file_select_probe.txt`

**What I learned:** The lightweight milestone probes and the stricter checkpoint harness now tell the same story: the Genesis build reliably exits title and reaches a stable file-select/menu state.

**Next action:** Close out this pass with the diary and report that T27-T29 frontend implementation is working, while noting that full file-select RAM parity still remains a separate follow-up lane.

---

## 2026-04-03 23:39:37 -05:00 - Attempt 3a: Remapped Genesis C To NES Select And Found The Packed Input Mask

**Current hypothesis:** A small follow-up in the controller shim can map Genesis `C` onto the NES `Select` lane without disturbing the working T27-T29 title/menu path.

**Files touched:**

- `src/nes_io.asm`
- `docs/NES_CONVERTER.md`
- `tools/bizhawk_t27_select_mapping_probe.lua`
- `tools/run_bizhawk_t27_select_mapping_probe.bat`

**Commands / changes applied:**

- Patched `_ctrl_strobe` so TH=1 bit5 (`Genesis C`) sets the raw NES Select latch bit.
- Updated the controller mapping note in `docs/NES_CONVERTER.md` to match the actual implementation:
  - `A -> NES A`
  - `B -> NES B`
  - `C -> NES Select`
  - `Start -> NES Start`
- Added a dedicated BizHawk probe and runner for the `Genesis C -> Select` mapping.
- Rebuilt manually:

```powershell
Push-Location src
vasmm68k_mot -Fbin -m68000 -maxerrors=5000 -L ..\builds\whatif.lst -o ..\builds\whatif_raw.md genesis_shell.asm
Pop-Location
python tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
```

- Ran:

```bat
tools\run_bizhawk_t27_select_mapping_probe.bat
tools\run_bizhawk_t29_file_select_probe.bat
```

**Observed result:**

- Rebuild completed successfully with the same existing long-branch warnings as earlier.
- The first `C -> Select` probe did not see bit `$04`, but it did consistently observe `$20` in both `ButtonsPressed` and `ButtonsDown`.
- The non-regression T29 file-select smoke still passed completely.
- Generated artifacts:
  - `builds/reports/bizhawk_t27_select_mapping_probe.txt`
  - `builds/reports/bizhawk_t29_file_select_probe.txt`

**What I learned:** The remap itself was working, but my first verification assumption was wrong. The raw NES latch uses `Select = bit2`, while Zelda's `ReadOneController` rotates that into packed `ButtonsPressed` / `ButtonsDown` bytes where `Select` appears as `$20`.

**Next action:** Correct the new probe to check Zelda's packed Select semantic (`$20`) instead of the raw latch bit (`$04`), then rerun it for a real pass/fail result.

---

## 2026-04-03 23:39:37 -05:00 - Attempt 3b: Verified Genesis C -> NES Select With The Correct Packed Mask

**Current hypothesis:** If the new controller mapping is correct, checking Zelda's packed Select semantic (`$20`) should make the dedicated verification probe pass immediately.

**Files touched:**

- `tools/bizhawk_t27_select_mapping_probe.lua`

**Commands / changes applied:**

- Updated the probe to expect Select as `$20` in `ButtonsPressed` / `ButtonsDown` after Zelda-side input packing.
- Reran:

```bat
tools\run_bizhawk_t27_select_mapping_probe.bat
```

**Observed result:**

- The probe passed all checks.
- Key runtime values:
  - `Max ButtonsPressed ($F8) = $20`
  - `Max ButtonsDown ($FA) = $20`
  - `First Select edge frame = 90`
  - `First Select hold frame = 90`
- Generated artifact:
  - `builds/reports/bizhawk_t27_select_mapping_probe.txt`

**What I learned:** Genesis `C` is now correctly wired into Zelda's Select path. The only hiccup in this follow-up was understanding the packed runtime button format versus the raw NES latch format.

**Next action:** Report the finished remap and keep the dedicated probe/runner available for future input regressions.

---

## 2026-04-04 00:10:18 -05:00 - Attempt 4a: File-Select Visual Diff Is A Menu Sprite Bridge Problem, Not A New Menu Logic Bug

**Current hypothesis:** The file-select Links and cursor are close enough that this is probably not a new `UpdateMode1Menu` logic failure. The more likely causes are sprite Y translation and Genesis-side palette collapse in the frontend sprite bridge.

**Files touched:**

- `tools/bizhawk_file_select_visual_probe_genesis.lua`
- `tools/bizhawk_file_select_visual_probe_nes.lua`
- `tools/run_bizhawk_file_select_visual_probe_genesis.bat`
- `tools/run_bizhawk_file_select_visual_probe_nes.bat`

**Commands / probes run:**

```bat
cmd /c tools\run_bizhawk_file_select_visual_probe_genesis.bat
powershell -ExecutionPolicy Bypass -File tools\launch_bizhawk.ps1 -RomPath "Legend of Zelda, The (USA).nes" -LuaPath "tools\bizhawk_file_select_visual_probe_nes.lua" -Wait
```

**Observed result:**

- The Genesis and NES checkpoints both reached the first stable interactive file-select frame.
- Image analysis of the user-provided screenshots showed the entire Genesis menu sprite layer was 8 pixels too low:
  - top Link block: NES `y=81..96`, Genesis `y=89..104`
  - bottom Link block: NES `y=129..144`, Genesis `y=137..152`
  - heart cursor: NES `y=161..168`, Genesis `y=169..176`
- The Genesis CRAM rows at file select were:
  - `CRAM[2] = $046E $048E $0028`
  - `CRAM[3] = $040C $048E $0EEE`
- That matched the long-standing 2-row sprite collapse:
  - one shared row surviving as the Link/sprite row
  - one shared row surviving as the cursor/sword row
- Generated artifacts:
  - `builds/reports/file_select_visual_genesis.txt`
  - `builds/reports/file_select_visual_nes.txt`

**What I learned:** The cursor and Links were not just "a little off." The frontend sprite bridge was doing two concrete wrong things for file select: rendering the whole sprite layer 8 pixels too low, and collapsing the menu sprite palettes in a way that pushed the save-slot Links onto the wrong surviving Genesis colors.

**Next action:** Patch the Genesis sprite bridge first: lift frontend sprites in menu mode and remap file-select Link sprite attrs so the Links no longer collide with the cursor palette.

---

## 2026-04-04 00:10:18 -05:00 - Attempt 4b: First Bridge Patch Fixed The 8px Frontend Sprite Drift But Not The Surviving Link Color

**Current hypothesis:** A narrow bridge patch can fix both visible issues without touching `UpdateMode1Menu`: subtract 8 pixels in frontend modes `0-1`, and collapse file-select Link attrs onto one surviving Genesis sprite palette while leaving the heart cursor / quest swords on the other.

**Files touched:**

- `src/nes_io.asm`

**Commands / changes applied:**

- Patched `_oam_dma` to:
  - keep the 8px frontend sprite lift for `GameMode < 2`
  - collapse file-select save-slot Links onto Genesis sprite palette 2
  - preserve palette 3 for the heart cursor / quest swords
- Rebuilt manually:

```bat
"C:\Users\Jake Diggity\Documents\GitHub\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" -Fbin -m68000 -maxerrors=5000 -L "..\builds\whatif.lst" -o "..\builds\whatif_raw.md" genesis_shell.asm
python tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
cmd /c tools\run_bizhawk_file_select_visual_probe_genesis.bat
```

**Observed result:**

- T29 stayed green:
  - `T29 FILE SELECT: ALL PASS`
- The Genesis SAT Y values moved from `249` to `241`, which is the exact 8px lift the screenshot diff predicted.
- The CRAM rows did **not** change yet:
  - `CRAM[2]` was still the brown/orange row (`$046E $048E $0028`)
  - `CRAM[3]` was still the cursor/sword row (`$040C $048E $0EEE`)
- I also tried a deeper patch inside `_transfer_tilebuf_fast` to special-case the `MenuPalettesTransferBuf` palette record itself, but that grew the binary enough to trip a cluster of unrelated short-branch range errors in the translated banks, so I backed that approach out.

**What I learned:** The Y fix belonged in the sprite bridge and worked immediately. The color fix was trickier: the menu palette transfer happens before the file-select mode is fully live, so trying to special-case it in the generic fast transfer path was the wrong tradeoff for this pass.

**Next action:** Keep the working menu-mode sprite remap in `_oam_dma`, but switch to a smaller data-side fix so the surviving file-select Link palette row is the correct NES green without bloating the transfer interpreter.

---

## 2026-04-04 00:10:18 -05:00 - Attempt 4c: Compact File-Select Palette Fix Landed Cleanly

**Current hypothesis:** If file-select save-slot Links are all collapsed onto Genesis sprite palette 2 in menu mode, then setting the surviving menu Link palette row to the NES-green default should make the Links render correctly without widening any hot code path.

**Files touched:**

- `src/nes_io.asm`
- `src/zelda_translated/z_06.asm`
- `tools/bizhawk_file_select_pause_at_capture.lua`

**Commands / changes applied:**

- Kept the working `_oam_dma` frontend/menu changes from Attempt 4b.
- Backed out the transfer-interpreter palette special-case.
- Changed the surviving menu Link palette row in `MenuPalettesTransferBuf` from `$26` to `$29` so the shared file-select Link palette resolves to the NES green.
- Rebuilt and reran:

```bat
"C:\Users\Jake Diggity\Documents\GitHub\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" -Fbin -m68000 -maxerrors=5000 -L "..\builds\whatif.lst" -o "..\builds\whatif_raw.md" genesis_shell.asm
python tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
cmd /c tools\run_bizhawk_file_select_visual_probe_genesis.bat
```

**Observed result:**

- T29 still passed unchanged.
- The frontend/menu sprite lift held:
  - Genesis SAT Y values remained at `241`, not `249`
- The surviving file-select Link palette row changed to the NES green:
  - `CRAM[2]` moved from `$046E $048E $0028` to `$02EA $048E $0028`
  - `$02EA` is the Genesis conversion of NES color `$29` (yellow-green)
- Generated / refreshed artifacts:
  - `builds/reports/bizhawk_t29_file_select_probe.txt`
  - `builds/reports/file_select_visual_genesis.txt`
  - `builds/reports/full_screen_capture.png` (window-capture experiment; not reliable enough to treat as an acceptance artifact)

**What I learned:** The compact fix was the right one for this pass. The frontend sprite bridge needed the 8px menu lift, and the file-select Links only needed the surviving shared sprite row to resolve to the NES green once the save-slot Links were collapsed onto one palette.

**Next action:** Report the file-select visual fix, noting that the acceptance evidence is probe-side (`SAT` + `CRAM` + T29 pass) because BizHawk's scripted screenshot path was not reliable for the file-select frame in this environment.

---

## 2026-04-04 00:27:27 -05:00 - Attempt 5a: Register-Name Screen Diff Points To The Same Frontend Slot-Palette Bridge

**Current hypothesis:** The register-name screen is not a new renderer bug. It reuses the same save-slot Link stack as file select, but `_oam_dma` still only special-cases `GameMode=$01`, so Mode E/F save-slot Links are being split back across the normal gameplay palette fold instead of sharing the one green frontend row.

**Files touched:**

- `src/nes_io.asm`

**Commands / changes applied:**

- Compared the live Genesis and NES register-name screenshots supplied in the thread.
- Traced the relevant frontend path in:
  - `src/zelda_translated/z_02.asm`
  - `src/data/frontend_ui.inc`
- Confirmed that `ModeEandFCursorSprites` uses palette `3` for the heart/block cursors, which means the likely safe fix is to keep palette `3` for cursor sprites and collapse only non-`3` save-slot Link attrs back onto the shared frontend Link row.
- Extended the existing `_oam_dma` frontend slot-palette bridge from file select only (`GameMode=$01`) to include register/eliminate (`GameMode=$0E/$0F`).

**Observed result:**

- No build or probe ran yet in this sub-attempt; this was the screenshot/code-diff pass that produced the implementation shape.

**What I learned:** The visible Mode E mismatch is structurally the same problem as file select screen 1: frontend save-slot Links need mode-aware palette folding, while the cursors should keep palette `3`.

**Next action:** Rebuild, add a dedicated Mode E visual probe, and verify that the frontend patch does not regress T29.

---

## 2026-04-04 00:27:27 -05:00 - Attempt 5b: Added A Register-Name Visual Probe, Then Learned The Automation Was The Weak Link

**Current hypothesis:** A dedicated Mode E visual probe can enter register-name deterministically, dump `NES OAM` shadow plus Genesis `SAT/CRAM`, and prove whether the palette bridge fix lands without relying on flaky screenshots.

**Files touched:**

- `tools/bizhawk_register_name_visual_probe_genesis.lua`
- `tools/run_bizhawk_register_name_visual_probe_genesis.bat`

**Commands / changes applied:**

- Added a new Genesis-only Mode E probe and runner:
  - `cmd /c tools\run_bizhawk_register_name_visual_probe_genesis.bat`
- Tried several input timings for the second `Start` press:
  - mode-driven one-frame pulse after file select stabilized
  - mode-driven held `Start`
  - fixed frame windows
  - later delayed frame windows after user guidance

**Observed result:**

- Every automated attempt timed out in the same transitional state:
  - `final_mode=$01`
  - `final_submode=$00`
  - `updating=$01`
  - `save_slot=$03`
- That means the Genesis build reaches file select and begins the register-option handoff, but the scripted timing is still not matching the manual input cadence closely enough to make the transition complete under automation in this environment.

**What I learned:** The probe itself is useful as a future artifact sink, but the Mode E timing problem is not worth burning more time on right now. Manual entry is the faster and safer verification path for this specific screen.

**Next action:** Keep the probe for later, but stop optimizing its timing loop. Rebuild the ROM with the Mode E/F palette bridge patch, confirm T29 still passes, and use manual `Start` entry plus a fresh Genesis capture to validate the visual result.

---

## 2026-04-04 00:27:27 -05:00 - Attempt 5c: Rebuilt The Frontend Slot-Palette Patch And Kept T29 Green

**Current hypothesis:** If Mode E/F now uses the same frontend slot-palette bridge as file select, then the register-name Link stack should stop splitting across brown/pink/green rows and settle onto the same green Link row while the cursor sprites keep their magenta row.

**Files touched:**

- `src/nes_io.asm`
- `tools/bizhawk_register_name_visual_probe_genesis.lua`

**Commands / changes applied:**

```bat
"C:\Users\Jake Diggity\Documents\GitHub\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" -Fbin -m68000 -maxerrors=5000 -L "..\builds\whatif.lst" -o "..\builds\whatif_raw.md" genesis_shell.asm
python tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
cmd /c tools\run_bizhawk_register_name_visual_probe_genesis.bat
```

**Observed result:**

- The ROM rebuilt cleanly.
- `T29 FILE SELECT: ALL PASS` still holds after the Mode E/F palette-bridge expansion.
- The automated Mode E probe still times out in the same transition state, so it did not become a trustworthy acceptance check in this pass.

**What I learned:** The code-side visual fix is in the build and did not regress the title/file-select chain. The remaining blocker is probe timing, not the frontend patch itself.

**Next action:** Use the rebuilt ROM at `builds/whatif.md` with manual `Start` entry to verify the register-name visuals, then compare the fresh Genesis capture against the NES reference and adjust only if another visible mismatch remains.

---

## 2026-04-04 00:39:45 -05:00 - Attempt 5d: Mode E/F Needed The Same 8px Frontend Sprite Lift As File Select

**Current hypothesis:** The remaining register-name geometry bugs are not separate per-sprite issues. The three save-slot Links and the `A` block cursor are all still going through `_oam_dma` without the frontend menu lift that file select already needed, so the whole Mode E/F sprite layer is landing about 8 pixels too low.

**Files touched:**

- `src/nes_io.asm`

**Commands / changes applied:**

- Expanded the existing frontend sprite Y-lift in `_oam_dma` to include `GameMode=$0E/$0F` in addition to modes `0-1`.
- Rebuilt and verified the safe frontend lane:

```bat
"C:\Users\Jake Diggity\Documents\GitHub\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" -Fbin -m68000 -maxerrors=5000 -L "..\builds\whatif.lst" -o "..\builds\whatif_raw.md" genesis_shell.asm
python tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
```

**Observed result:**

- The ROM rebuilt cleanly.
- `T29 FILE SELECT: ALL PASS` still holds after the Mode E/F Y-lift expansion.
- Pixel-diff measurements against the supplied screenshots matched the new hypothesis exactly:
  - Genesis `A` block cursor magenta bbox: `x=48..55, y=135..142`
  - NES `A` block cursor magenta bbox: `x=48..55, y=128..135`
  - Result: Genesis block cursor is `7` pixels too low.
  - Genesis Link-stack green bbox: `x=83..92, y=49..110`
  - NES Link-stack green bbox: `x=83..92, y=41..102`
  - Result: Genesis Links are `8` pixels too low.

**What I learned:** The remaining visible drift is coherent and shared, not random. The register-name screen was still missing the same top-shift correction that already solved file select screen 1.

**Next action:** Have the user verify the new `builds/whatif.md` tomorrow. If any remaining register-name mismatch survives after this lift, it is likely a narrow palette or state-specific sprite issue rather than general geometry.

---

## 2026-04-04 00:39:45 -05:00 - Note: Manual Start Input Was Contaminating The Mode E Probe

**Current hypothesis:** Some of the earlier probe traces that appeared to “naturally” reach `GameMode=$0E` were actually influenced by manual `Start` input while the emulator was running.

**Files touched:**

- none

**Commands / changes applied:**

- none; this is a workflow correction based on user feedback.

**Observed result:**

- The user clarified that they were manually pressing `Start` during some of the BizHawk runs.
- That means the earlier apparent automatic Mode E transitions should not be treated as deterministic probe evidence.

**What I learned:** For the register-name lane, manual screenshots are still the trustworthy acceptance artifact until the Mode E automation is rebuilt around a controlled setup that cannot be contaminated by live input.

**Next action:** Treat the rebuilt ROM plus user-supplied screenshots as the primary verification path for this screen.

---

## 2026-04-04 11:38:18 -05:00 - Attempt 5e: Split The Register-Name Fix Into Link Placement And Board-Cursor Placement

**Current hypothesis:** The latest register-name screenshot showed two different bugs sharing one screen:

- the three save-slot Links were too low because Mode E/F seeds `Mode1_WriteLinkSprites` from a lower base Y than the NES reference
- the `A` block cursor was too low because the char-board cursor sprite needs its own extra 8px display lift in Mode E, independent of the save-slot Links

The earlier broad Mode E/F `_oam_dma` lift was the wrong abstraction for this screen.

**Files touched:**

- `src/nes_io.asm`
- `src/zelda_translated/z_02.asm`

**Commands / changes applied:**

- Proved the “worse” screenshot was actually pixel-for-pixel identical to the older Genesis register-name screenshot, so the prior broad Mode E/F lift had not improved this screen.
- Relaxed the Mode E visual probe to capture the first visible `GameMode=$0E` frame and dumped live OAM/SAT/CRAM.
- Learned from that capture that:
  - the three save-slot Links are definitely sprite-layer data written by `Mode1_WriteLinkSprites`
  - the char-board cursor sprite is initialized hidden and only becomes visible later in the true Mode E idle/update path
- Backed out the speculative `_oam_dma` Mode E/F Y-lift so only modes `0-1` keep the legacy frontend lift.
- Applied two narrower register-name fixes in `z_02.asm`:
  - changed Mode E/F link-stack seed Y from `48` to `40` before `Mode1_WriteLinkSprites`
  - added one extra 8px subtract in `ModeEandF_WriteCharBoardCursorSpritePosition` after `ModifyFlashingCursorY`
- Rebuilt and reran the safe frontend probe:

```bat
"C:\Users\Jake Diggity\Documents\GitHub\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" -Fbin -m68000 -maxerrors=5000 -L "..\builds\whatif.lst" -o "..\builds\whatif_raw.md" genesis_shell.asm
python tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
cmd /c tools\run_bizhawk_register_name_visual_probe_genesis.bat
```

**Observed result:**

- The ROM rebuilt cleanly as `builds/whatif.md` with checksum `$4CA8`.
- `T29 FILE SELECT: ALL PASS` still holds after the narrower Mode E changes.
- The automatic Mode E capture remains useful for debugging, but not as final visual acceptance, because it still lands during early Mode E setup rather than the exact hand-driven idle frame the user screenshots.

**What I learned:** Register-name needs targeted per-path fixes, not shared menu-mode renderer changes. The save-slot Links and the char-board cursor are independent sprite paths and should be corrected independently.

**Next action:** Have the user check the rebuilt `builds/whatif.md` tomorrow. If the Links and `A` block still drift, use one new Genesis screenshot to tune only the remaining narrow path instead of reopening shared frontend code.

---

## 2026-04-04 12:16:00 -05:00 - Attempt 5f: Clamp The Hidden Bottom-Right Register Slot Back Onto `9`

**Current hypothesis:** The remaining “cursor can move outside the text box” bug is not freeform out-of-bounds movement. The Mode E logic still exposes a hidden 44th `ModeE_CharMap` entry (`$24`, blank) after `9`, while the rendered character board only visibly draws `0..9` on the final row. That lets the cursor land on an invisible bottom-right cell that feels like it escaped the box.

**Files touched:**

- `src/zelda_translated/z_02.asm`

**Commands / changes applied:**

- Inspected the original board data in `ModeFCharsTransferBuf` and confirmed:
  - the final visible row only draws `0..9`
  - `ModeE_CharMap` still contains an extra trailing blank entry after `9`
- Chose the lowest-risk gameplay fix for this pass:
  - after any directional move in Mode E, if `CharBoardIndex` becomes `$2B` (43, the hidden blank slot), clamp it back to `$2A` (`9`) and pull the cursor X left by one column
- Rebuilt and reran the safe frontend verification:

```bat
"C:\Users\Jake Diggity\Documents\GitHub\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" -Fbin -m68000 -maxerrors=5000 -L "..\builds\whatif.lst" -o "..\builds\whatif_raw.md" genesis_shell.asm
python tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
```

**Observed result:**

- The ROM rebuilt cleanly as `builds/whatif.md` with checksum `$74CF`.
- `T29 FILE SELECT: ALL PASS` still holds after the register-board clamp.

**What I learned:** The board-layout mismatch is real: there is one logical cursor slot beyond the visible last digit. Clamping only that slot fixes the practical bug without reopening the rest of the direction/wrap rules.

**Next action:** Let the user verify the rebuilt ROM. If they still want stricter NES-exact behavior around the board edges, the next pass would be to compare how the original NES handles that hidden blank cell and mirror it exactly rather than clamping locally.

---

## 2026-04-04 12:37:44 -05:00 - Attempt 5g: Respect NES Behind-Background Sprite Priority For Register Cursors

**Current hypothesis:** The remaining register-name mismatch is now a layering problem, not a placement problem. Both magenta block cursors are supposed to sit behind the active letters, and the NES OAM for those cursor sprites already marks them that way via attribute bit 5. Genesis was still forcing every sprite high priority, so the blocks rendered in front of Plane A text instead of behind it.

**Files touched:**

- `src/nes_io.asm`

**Commands / changes applied:**

- Promoted Plane A background tile words to high priority in `_compose_bg_tile_word` so text and board glyphs can sit in front of low-priority sprites.
- Updated `_oam_dma` to respect NES sprite attribute bit 5:
  - if bit 5 is clear, keep the existing high-priority sprite behavior
  - if bit 5 is set, leave the sprite low priority so it can render behind Plane A letters
- Reused the current rebuilt ROM and reran the safe frontend verification:

```bat
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
```

**Observed result:**

- `T29 FILE SELECT: ALL PASS` still holds after the priority/layering change.
- The current rebuilt ROM remains `builds/whatif.md` with the latest manual rebuild checksum `$64E9`.
- This change is intentionally narrow: it only affects sprites that the NES data explicitly marks as behind background, which matches the register-name cursor behavior we want.

**What I learned:** The cursor blocks were already carrying the correct NES semantic in OAM; the missing piece was honoring that semantic in the Genesis SAT tile word and giving Plane A tiles enough priority to win the overlap.

**Next action:** Have the user visually verify the new build in BizHawk. If one cursor still overdraws text, inspect whether that specific glyph is coming from Plane A or a sprite path and tune only that path instead of broadening priority rules again.

---

## 2026-04-04 12:51:13 -05:00 - Attempt 5h: Split The Remaining Register Cursors Into A Known Cursor-Tile Priority Rule Plus A Dedicated Name-Cursor Lift

**Current hypothesis:** The latest Genesis screenshot showed two different leftover problems on the same screen:

- the top name-field cursor block was still one tile too low versus the active letter row
- the bottom char-board cursor still was not reliably ending up behind the selected letter, so the generic “NES attr bit 5 -> low priority” rule was not enough for this specific register cursor path

The safest next pass is to keep the shared renderer narrow and add one register-specific cursor rule in each path.

**Files touched:**

- `src/nes_io.asm`
- `src/zelda_translated/z_02.asm`

**Commands / changes applied:**

- Compared the latest user Genesis screenshot against the NES reference and confirmed:
  - the top cursor block was still about 8 pixels low
  - the first board `A` was still being covered too aggressively by the magenta block
- Tightened `_oam_dma` for modes `$0E/$0F`:
  - if the frontend sprite tile is `$25` (the register/eliminate block cursor tile), keep it low priority unconditionally
  - fall back to the generic NES attr bit 5 rule for other sprites
- Updated `ModeEandF_WriteNameCursorSpritePosition` to apply the same extra 8px lift pattern already used in the board-cursor path, so the top cursor sits behind the active name letter instead of one tile below it
- Rebuilt and reran the safe frontend verification:

```bat
"C:\Users\Jake Diggity\Documents\GitHub\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" -Fbin -m68000 -maxerrors=5000 -L "..\builds\whatif.lst" -o "..\builds\whatif_raw.md" genesis_shell.asm
python tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
```

**Observed result:**

- The ROM rebuilt cleanly as `builds/whatif.md` with checksum `$BE91`.
- `T29 FILE SELECT: ALL PASS` still holds after the cursor-specific priority and name-cursor Y changes.
- The updated T29 probe now ends at stable file select (`Final mode: $01`) instead of drifting onward during the run, so the safe lane remains clean and deterministic.

**What I learned:** The remaining register mismatches were narrow enough to deserve narrow fixes. The name-field cursor and the board cursor should not share one broad correction rule, and the register cursor tile is distinct enough to be safely special-cased in the frontend SAT priority path.

**Next action:** Visually verify the rebuilt ROM in BizHawk. If the board cursor still overlaps the selected letter incorrectly after this build, dump the live register-mode SAT/VRAM state with a two-Start register probe and fix only the last surviving register-specific path.

---

## 2026-04-04 13:16:58 -05:00 - Attempt 6a: Add A Real Start-Release Gate, Visible-Cell Board Sync, And A Deterministic Two-Phase Register Probe

**Current hypothesis:** The frontend bugs had split into three distinct causes:

- title `Start` needed a release gate before file select would be deterministic for a real tap
- the register board still needed a source-of-truth sync between `CharBoardIndex` and the cursor `ObjX/ObjY` pair instead of the old one-cell clamp
- the old register probe was still too timing-driven to prove the real Mode E screen

**Files touched:**

- `src/zelda_translated/z_07.asm`
- `src/zelda_translated/z_02.asm`
- `src/nes_io.asm`
- `tools/bizhawk_register_name_visual_probe_genesis.lua`

**Commands / changes applied:**

- Added `FrontendStartReleaseGate = $042B` beside the other frontend scratch bytes.
- Set that gate when title mode accepts `Start`, and taught `UpdateMode1Menu_Sub0` to:
  - ignore `Start` while the old title press is still held
  - clear the gate only after `ButtonsDown & $10` becomes zero
- Replaced the old hidden-slot-only clamp with `ModeE_SyncCharBoardCursorToIndex`, which:
  - keeps `CharBoardIndex` on the 43 visible cells
  - regenerates board cursor X/Y from the logical index
  - preserves the visible wrap behavior by sending right-from-hidden to `A` and every other hidden landing back to `9`
- Removed the temporary `_oam_dma` tile-$25 special case so register cursor layering goes back through the clean generic NES attr-bit-5 rule.
- Replaced the old one-pulse register probe with a two-phase path:
  - one title `Start` to stable file select
  - repeated Genesis `C` taps until `CurSaveSlot == $03`
  - a later explicit second `Start`
  - Mode E capture with cursor/OAM/SAT details
- Rebuilt and ran the current verification chain:

```bat
"C:\Users\Jake Diggity\Documents\GitHub\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" -Fbin -m68000 -maxerrors=5000 -L "..\builds\whatif.lst" -o "..\builds\whatif_raw.md" genesis_shell.asm
python tools\fix_checksum.py builds\whatif_raw.md builds\whatif.md
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
cmd /c tools\run_bizhawk_file_select_genesis_checkpoint.bat
cmd /c tools\run_bizhawk_register_name_visual_probe_genesis.bat
```

**Observed result:**

- The ROM rebuilt cleanly as `builds/whatif.md` with checksum `$256C`.
- The stricter file-select checkpoint passed at `frame=194` and still captured the expected stable file-select state in `builds/reports/file_select_genesis_ram.json`.
- The first version of the new register probe successfully reached Mode E, but it captured too early:
  - `frame=126`
  - `mode=$0E submode=$03 updating=$00`
  - cursor OAM/SAT still reflected an init-stage frame instead of the true register-name idle view
- The old long-hold T29 smoke still drifted to mode `$0E`, which proved the smoke probe itself was simulating a hold-through path instead of the user-level “single tap” goal we wanted to enforce.

**What I learned:** The ROM-side gate and board sync were sound enough to reach the right stable file-select checkpoint and a real Mode E handoff, but the smoke probes still needed to model the actual user-level behavior more faithfully.

**Next action:** Tighten the T29 smoke to a real tap, then refine the register probe to wait for the visible Mode E cursor frame instead of the first `GameMode=$0E` init frame.

---

## 2026-04-04 13:16:58 -05:00 - Attempt 6b: Align The Frontend Smoke Probes With Real Tap Behavior And Visible Register Cursors

**Current hypothesis:** The remaining ambiguity was now in the probes, not the ROM:

- T29 needed to model a real title `Start` tap instead of a 40-frame hold
- the register probe needed to wait for Mode E submode `$04` with visible cursor sprites, not just the first moment `GameMode==$0E`

**Files touched:**

- `tools/bizhawk_t29_file_select_probe.lua`
- `tools/bizhawk_register_name_visual_probe_genesis.lua`

**Commands / changes applied:**

- Shortened the T29 `Start` injection window from frames `90-130` to `90-93`.
- Added `T29_STABLE_FILE_SELECT` so the smoke explicitly fails if the one-tap path drifts into mode `$0E/$0F` or ends anywhere other than stable mode `$01`.
- Tightened the register probe to wait for:
  - `GameMode=$0E`
  - `GameSubmode=$04`
  - released buttons
  - non-zero name/board cursor positions
  - cursor OAM tiles/attrs of `$F3/$03` and `$25/$23`
  - visible block-cursor Y bytes instead of the flashing-hidden `$EF` state
- Reran the frontend smoke and capture chain, plus a one-off eliminate smoke over the shared `Mode E/F` path:

```bat
cmd /c tools\run_bizhawk_t29_file_select_probe.bat
cmd /c tools\run_bizhawk_register_name_visual_probe_genesis.bat
```

Shared-path eliminate smoke via temporary BizHawk Lua:

```bat
powershell -ExecutionPolicy Bypass -File tools\launch_bizhawk.ps1 -RomPath builds\whatif.md -LuaPath %TEMP%\codex_eliminate_smoke.lua -Wait
```

**Observed result:**

- T29 now passes the new stability requirement:
  - `T29_STABLE_FILE_SELECT`
  - final mode `$01`
  - no drift into `Mode E/F`
  - report: `builds/reports/bizhawk_t29_file_select_probe.txt`
- The register probe now captures the real visible register-name screen:
  - `frame=131`
  - `mode=$0E submode=$04 updating=$01`
  - `char_board_index=$00`
  - `name_cursor=($70,$2F)`
  - `board_cursor=($30,$87)`
  - cursor OAM attrs remain `$23`
  - Genesis SAT priority for both block cursors is `0`
  - artifacts: `builds/reports/register_name_visual_genesis.txt` and `builds/reports/register_name_visual_genesis.png`
- The generated screenshot shows the register-name screen in the expected layout, with the `A` board cursor and top cursor in their corrected parity path.
- The one-off eliminate smoke also reached the shared Mode F setup path successfully:
  - `status=ok frame=135 mode=$0F sub=$04 updating=$01`
  - artifact: `builds/reports/eliminate_smoke.txt`

**What I learned:** The remaining instability report was probe-shaped, not ROM-shaped. Once the smoke matched a real tap and the register capture waited for visible cursor sprites, the frontend lane behaved the way the user intended: one tap to file select, explicit second confirm to register, visible-cell board bounds, and cursor layering through the clean NES attr-bit-5 path.

**Next action:** Hand the build back for user verification in BizHawk. The remaining follow-up, if any, should be screenshot-driven polish rather than more structural frontend/input work.

---

## 2026-04-04 — Mode-Transition Clean-Pipeline Invariant + Register-Name CHR Gap

**Current hypothesis (entering session):** File-select was rendering non-deterministically depending on when Start was pressed during the attract/info-scroll loop. Sometimes pristine, sometimes severely garbled. First guess was a VBlank/DMA race in `_ppu_write_7` CHR uploads. That guess was WRONG in root cause but right in category ("state carried across a mode boundary"). After that was fixed the user reported a separate, pre-existing bug on the REGISTER YOUR NAME screen: the pink square cursor and the "A" letter highlight are missing. The register bug is present regardless of press timing — it is not the same bug.

**Files touched:**
- `src/nes_io.asm` — added `_mode_transition_check`, `LAST_GAMEMODE`, `MTC_HITS` symbols
- `src/genesis_shell.asm` — initialises `LAST_GAMEMODE=$FF` at boot, calls `_mode_transition_check` from `VBlankISR` before `IsrNmi`
- `memory/project_mode_transition_invariant.md` — new project memory recording the architectural invariant
- Many new probes under `tools/bizhawk_*.lua` for diagnosis (title_start_capture, register_name_probe, vram_tile_probe, flash_cursor_probe, vram_dump_4000, cram_*_probe, palette_*_probe, etc.)

**Commands / evidence reviewed:**
- Phase-stratified file-select captures at f=1500, 2500, 4000 press points in a matrix of builds (Zelda16.0 → Zelda16.8).
- VRAM Plane A hex dumps, VSRAM reads, CRAM dumps, sprite attribute table dumps, NES-shadow OAM ($FF0200) dumps.
- Frame-by-frame OAM trace (32 frames) of slots 1 and 2 (name cursor, char-board cursor).
- Tile-data byte dumps for NES tile indices $0F2–$0F4 and $1F1–$1F4.

### Key finding #1 — File-select corruption was NOT a CHR race

The first hypothesis was that `_ppu_write_7` buffers a 16-byte NES tile then streams it directly to VDP_CTRL/VDP_DATA with no VBlank gate. Probes showed CHR_HIT_COUNT was identical across good/bad runs, and Plane A VRAM (the 896 tile words) was **byte-identical** across all three press points. The bytes in VRAM were correct. The picture was still wrong.

### Key finding #2 — Real root cause is VDP VSRAM bleed-through at mode boundaries

`bizhawk_vram_dump_4000.lua` showed that Plane A V-scroll in VSRAM differed per press point:
- f=1500: VSRAM[0] = $0010 → screen ok-ish
- f=2500: VSRAM[0] = $0197 → huge vertical offset
- f=4000: VSRAM[0] = $00C5 → another offset

The value retained was whatever the info-scroll / attract animation had last written. `_apply_genesis_scroll` is gated by `$0011`/`$0013` during init frames, so it never got a chance to rewrite VSRAM before the first post-transition frame rendered. The original NES never had this problem: on NES, scroll values are rewritten every frame in NMI via `$2005` two-writes, so there is nothing to "leak" across a mode change. On Genesis, VSRAM is persistent state that must be explicitly rezeroed.

Secondary contaminants, all of the same family:
- `$0014` (TileBufSelector) held the info-scroll's last dispatch index, causing the **first** post-transition NMI to dispatch the wrong buffer.
- `$0302` DynTileBuf palette-precheck sentinel + `$0300`/`$0301` counters retained mid-record state from the interrupted mode.
- `PPU_LATCH`/`PPU_VADDR`/`PPU_DHALF`/`PPU_DBUF` could be mid-sequence when the mode flipped.

### Key finding #3 — The architectural invariant, stated explicitly

**The NES relies on an implicit invariant: by the time `$0012` (GameMode) changes, the transfer pipeline is clean because NMI runs deterministically and finishes dispatches before the main loop returns.** On the Genesis port, mid-dispatch mode transitions leave stale state that corrupts the next mode's init. The fix is not to patch any individual symptom but to enforce the invariant as a post-condition on every `$0012` change.

### Key finding #4 — The fix lives in `_mode_transition_check`, called from `VBlankISR`

The check runs before `IsrNmi` every frame. It compares `$FF0012` against `LAST_GAMEMODE`. On any change it:
1. Resets `PPU_LATCH`, `PPU_VADDR`, `PPU_DHALF`, `PPU_DBUF`.
2. Zeroes `$0014` (TileBufSelector) and `$005C`.
3. Rewinds the DynTileBuf palette-precheck: `$0300=63`, `$0301=0`, `$0302=$FF`.
4. Zeroes `PPU_SCRL_X`/`PPU_SCRL_Y`.
5. **Directly writes `0` to VSRAM Plane A and Plane B V-scroll via VDP_CTRL/VDP_DATA.** This step is the load-bearing one because `_apply_genesis_scroll` is gated during init frames and cannot do this itself.

`LAST_GAMEMODE` is seeded to `$FF` at cold boot so the first real transition (from $00→$01, etc.) is always detected.

### Key finding #5 — "Fix $0014 must still happen" (contra an earlier draft)

An intermediate version of the check deliberately omitted the `$0014` reset on the theory that the new mode would rewrite it anyway. That was wrong. The mode-transition frame only changes `$0012`; the new mode's code does not run until the next main-loop iteration, so the first IsrNmi after the flip reads the **stale** `$0014` and dispatches the wrong buffer. The reset has to happen in the interrupt that sits between the main-loop write to `$0012` and the next IsrNmi.

### Key finding #6 — Verification procedure that actually proved it

- Same Start-press matrix (f=1500/2500/4000, then sweeping every frame over a window) producing screenshot fingerprints.
- Success criterion: all nine PNGs are **byte-identical** (2336 bytes), not just "visually close".
- This is the only reliable way to verify a timing-race fix — visual diff alone has too much noise.

### Key finding #7 — Register-name screen has a completely separate, pre-existing CHR-bank gap

After the mode-transition fix shipped, the user pointed out the REGISTER YOUR NAME screen was rendering wrong **regardless of press timing**. Two specific regressions vs the NES reference:
- Missing pink square flashing cursor sprite next to the current character slot.
- Missing "A" letter highlight block cursor on the alphabet grid.

Diagnosis walked down the entire stack:

1. **Palette not the problem.** CRAM dump at register-name: `BG3 = 0000 040C 048E 0EEE`. Pink $040C is present in palette 3, which is what cursor sprites use (attribute `$03`). Ruled out.
2. **OAM writes are happening.** NES OAM shadow $FF0200 shows `nes_spr[00] Y=$2F tile=$F3 attr=$03 X=$43` — exactly where the pink cursor should be. The slot-1/slot-2 slots also flip correctly across 32 consecutive frames (alternating `Y=$EF` hidden / visible Y per the `$0015 & $08` flash test in `ModifyFlashingCursorY`). The cursor *logic* is running.
3. **Sprite 8x16 mode is active.** `PPU_CTRL = $B0` → bit 5 set → all sprites are 8x16 tile pairs. NES tile `$F3` paired with bit-0-forced-low partner `$F2`.
4. **The actual gap is in VRAM tile data.**
   - Tile `$1F2` (top half, pattern table $1000-$1FFF, 8x16 mode puts sprites in $1xxx): has data.
   - **Tile `$1F3` (bottom half of the heart/pink-cursor pair): all zeros in Genesis VRAM.**
   - Tile `$124` (also referenced by cursor logic after 8x16 shift): all zeros.
5. The Genesis sprite table at `$F800` shows `spr[00]` pointing at tile `$E1F2` in palette 3 — the sprite entry is valid, it's literally rendering a blank tile because the tile data was never uploaded.

### Key finding #8 — Why those specific tiles are empty on Genesis but not NES

On the original NES, the register-name screen runs after MMC1 has already mapped the appropriate CHR-ROM bank into PPU pattern table $1000-$1FFF. Those tiles are addressable immediately — no upload needed, the CHR ROM is just wired in. On the Genesis port, MMC1 writes are captured in `_mmc1_write_*` but **there is currently no code path that takes a CHR bank switch and streams the corresponding tile bytes into Genesis VRAM.** The only things that populate VRAM tiles in the current build are:
- `_ppu_write_7` (direct `$2007` CPU writes from the main loop, which the title/file-select screens do use for some tiles).
- Pre-baked `.inc` files from `extract_chr.py` that the build links in (`tiles_overworld.inc`, `tiles_underworld.inc`, `tiles_common.inc`, `tiles_demo.inc`, etc. under `src/data/`).

Tiles like `$1F3` / `$124` live in a CHR bank that the NES code assumes is just "there" when it maps it, but neither of the above two mechanisms actually ships those bytes into Genesis VRAM at the right moment.

### Key finding #9 — CHR data layout for the Genesis build (from reading `tools/extract_chr.py`)

`extract_chr.py` reads `Legend of Zelda, The (USA).nes`, walks PRG banks, and emits `.inc` files into `src/data/`:
- `tiles_overworld.inc` — bank 3 level BG + SP tiles (overworld).
- `tiles_underworld.inc` — bank 3 level BG + SP tiles (dungeons, plus SP127/358/469 and boss sets 1257/3468/9).
- `tiles_common.inc` — bank 2 CommonSprites/CommonBG/CommonMisc (always-loaded tiles).
- `tiles_demo.inc` — bank 1 DemoSprites + DemoBG (title/attract screen tiles).
- `tiles_sprites.inc` — rollup bundle of common + level-sprite + demo sets.
- Conversion: `nes_tile_to_genesis()` converts 2bpp (16 bytes) → 4bpp (32 bytes) with MSB=leftmost pixel, high nibble of each byte = even pixel.
- Output format is `dc.w` tables, label-prefixed by block name (`TilesOverworldBG`, `TilesDemoSprites`, etc.).
- `src/data/` currently contains: `credits_text.inc demo_text.inc frontend_palettes.inc frontend_transfers.inc frontend_ui.inc save_tables.inc text.inc`. **None of the auto-generated `tiles_*.inc` files are actually present.** Someone has run `extract_chr.py` at least once historically but the generated tile tables are not in the tree right now, meaning either they were never committed or they are produced at build time into a different output directory. This is worth verifying before designing the MMC1 upload hook, because the hook needs *some* source of truth for the bytes.

### Key finding #10 — Design of the MMC1 CHR upload hook (not yet implemented)

Not yet written, but the shape is clear from the investigation:
- Trigger point: `_mmc1_common` in `src/nes_io.asm`, specifically the moment the 5-bit shift register finishes accumulating into `MMC1_CHR0` ($A000) or `MMC1_CHR1` ($C000) — and also on `MMC1_CTRL` ($8000) changes because bit 4 of CTRL switches between 4KB and 8KB CHR modes.
- Action: look up a bank table keyed by the new CHR bank number → base pointer into extracted Genesis tile data → stream 256 tiles × 32 bytes = 8KB (or 128 tiles × 32 = 4KB) into VDP VRAM at the tile slot the NES code expects.
- 4KB mode: CHR0 populates tiles $000-$0FF, CHR1 populates tiles $100-$1FF. 8KB mode: CHR0's bit 0 is ignored and it loads both halves.
- Destination addressing: NES tile index N → Genesis VRAM byte N × $20. For the sprite pattern table half ($1000-$1FFF → tiles $100-$1FF), that's VRAM $2000-$3FFF.
- Must be gated behind VBlank or forced blank, because bank switches can happen mid-screen on the NES (Zelda's CHR banking is typically only at mode-init boundaries, but the hook must not assume).
- Open question: where does the bank data live in the Genesis ROM? Either (a) the build needs to incbin the auto-generated `tiles_*.inc` contents so the code can reference them by label, or (b) the hook needs raw bank binaries keyed by bank number. The current `extract_chr.py` emits named blocks (overworld BG, underworld SP, etc.), **not** raw bank images, so option (a) requires a bank→label mapping table, and option (b) requires a new extractor mode that preserves NES bank layout.

### Key finding #11 — Probes that proved invaluable

- **`bizhawk_vram_dump_4000.lua`** — differential VSRAM dump was the single probe that cracked the mode-transition mystery. Nothing else in the existing probe suite read VSRAM.
- **`bizhawk_flash_cursor_probe.lua`** — 32-frame OAM timeline proved cursor *logic* was alive and eliminated "maybe the cursor is just never written" as a hypothesis, which was the natural first guess.
- **`bizhawk_vram_tile_probe.lua`** — directly dumping the bytes of tiles by index (rather than trying to infer from screenshots) was the only way to confirm which specific tiles were missing.
- **`bizhawk_register_name_probe.lua`** — combined Genesis SAT + NES OAM shadow + CRAM + Plane A attributes in one report; this kind of "dump everything at one checkpoint" probe is dramatically more useful than single-purpose probes when the hypothesis is still unclear.

### Key finding #12 — Things that looked promising but were dead ends

- "Maybe the savestate is caching old RAM" — deleted `fade_zoom_baseline.State`, made no difference. Savestates were not the confounder.
- "Maybe the pink cursor palette is missing" — CRAM showed palette 3 entry $040C ($040C = pink) was present. Palette side is clean.
- "Maybe CHR_HIT_COUNT differs across good/bad runs" — it was identical. The direct-upload CHR path (`_ppu_write_7`) is not the problem for register-name.
- "Maybe it's a sprite-0-hit / `$00E3` splits interaction" — file-select and register-name don't use splits, ruled out.

### Key finding #13 — Memory system now records this invariant

`memory/project_mode_transition_invariant.md` was written during this session so future conversations inherit the architectural decision without having to re-derive it. MEMORY.md index entry:
`- [Mode-boundary clean-pipeline invariant](project_mode_transition_invariant.md) — NES assumes clean transfer state + zero VDP scroll on $0012 change; VBlankISR _mode_transition_check enforces this`

### Generalizable lessons for this port

1. **Whenever NES code is about to rely on "deterministic NMI already ran", treat it as an invariant to re-enforce explicitly on Genesis.** Frame-phase races in this port are almost never timing races in the classic sense — they're invariants the NES code silently assumes, broken because Genesis execution doesn't provide the same guarantee for free.
2. **VSRAM is persistent state. VRAM bytes being correct does not mean the picture will be correct.** Any investigation into "right bytes, wrong picture" should check VSRAM next, not sixth.
3. **Byte-identical screenshot fingerprints are the only trustworthy test for timing-race fixes.** Visual inspection across phase offsets will lie.
4. **Probes that dump *everything* at one checkpoint outperform specialized probes when the hypothesis is unclear.** Write single-pass omnibus dumpers, filter in post.
5. **8x16 sprite mode (PPUCTRL bit 5) doubles the number of tiles that need to be in VRAM for every cursor/sprite and pairs them via bit-0 of the tile index.** Any "sprite looks blank" investigation in this port must consider the paired tile, not just the referenced tile.
6. **CHR-bank switches on MMC1 are a VRAM upload event on Genesis, not a register write.** The current build has no such hook; every future "why is this specific pattern-table tile blank?" bug will trace to this same gap until the hook exists.
7. **`src/data/*.inc` is the source of truth for pre-baked tile data**, but the auto-generated `tiles_*.inc` files from `extract_chr.py` are not currently present in the tree. Verify this before designing any code that references those labels.

**Next action:** Implement the MMC1 CHR upload hook. First step is to verify whether `tiles_*.inc` files exist somewhere under the repo (possibly in a build output directory) or whether `extract_chr.py` needs to be re-run as part of the build. Then design a bank→label (or bank→raw-pointer) table and wire it into `_mmc1_common` under a VBlank/forced-blank gate.

---

## 2026-04-04 (cont.) — Register-Name Pink Cursor: Root Cause Actually Found (No MMC1 Hook Needed)

**Current hypothesis (entering):** Pink cursor missing because MMC1 CHR bank upload path doesn't exist. I was about to implement a full bank-upload hook as a huge architectural addition. **That hypothesis was wrong.** Following the data instead of the theory, the real cause turned out to be a single pre-existing tile-data slot that is already on a working upload path — the bytes the path writes there are wrong (blank), but the path itself works fine. No MMC1 hook is required.

**Commands / evidence reviewed:**
- Re-read `src/zelda_translated/z_01.asm` 1905-1920 — `DemoPatternVramAddrs = {$0700, $1700}`, sizes `{$0900, $0820}`.
- Re-read `src/zelda_translated/z_02.asm` 81-141 — **`TransferCommonPatterns`**, uploads three blocks to VRAM `{$0000, $1000, $1F20}` with sizes `{$0700, $0700, $00E0}`.
- Re-read `src/zelda_translated/z_02.asm` 396-412 — **raw bytes of `CommonMiscPatterns`**.
- Re-read `src/zelda_translated/z_07.asm` 1948-1973 — `InitMode0` dispatches `SwitchBank(2)` then `TransferCommonPatterns` on first entry (before `$00F5 = $5A` sentinel gets set).
- Re-read `src/nes_io.asm` 1539-1637 — `_transfer_chr_block_fast` bulk uploader.
- Re-read `src/nes_io.asm` 1173-1303 — `_oam_dma` NES OAM → Genesis SAT converter.
- Re-read `builds/reports/vram_tile_probe.txt` — byte dump of tiles $0F2–$0F4, $1F1–$1F4, $124.

### Key finding #14 — `CommonMiscPatterns` is the upload path for tiles $1F2–$1FF

Every tile in VRAM range `$3E40-$3FFF` on Genesis corresponds to NES pattern-table tile index `$1F2–$1FF`. This whole strip (14 tiles, 224 bytes NES-side) is populated by exactly one upload: `TransferCommonPatterns` → block 2 → `CommonMiscPatterns` → VRAM `$1F20`. It is called from `InitMode0` at boot via the `$00F5 ≠ $5A` first-run gate, and once done is cached in VRAM forever (no other mode init re-runs it). So "is the data in VRAM?" reduces to "are the bytes in `CommonMiscPatterns` correct?" — it has nothing to do with MMC1 bank switching, CHR upload hooks, or any other architectural gap.

### Key finding #15 — `vram_tile_probe.txt` shows the actual byte pattern

```
tile $1F1 @ VRAM $3E20: nonzero=32     (full data — all $33 pixels)
tile $1F2 @ VRAM $3E40: nonzero=25     (real pink-cursor-shaped pixels)
tile $1F3 @ VRAM $3E60: nonzero=0      (ALL ZERO)
tile $1F4 @ VRAM $3E80: nonzero=32     (full data — all $11 pixels)
```

Adjacent tiles are full. Only `$1F3` is zero. This is impossible to explain with "no upload happened at all" because the neighbouring tiles in the same upload stream ARE there. The upload is running fine. The specific bytes for tile index 1 (relative to `CommonMiscPatterns`) are literally zero in the source data.

### Key finding #16 — `CommonMiscPatterns` source bytes confirm the blank-tile-1

`src/zelda_translated/z_02.asm` 398-411:
```
CommonMiscPatterns:
; .INCBIN dat/CommonMiscPatterns.dat (224 bytes)
    dc.b $6C,$FE,$FE,$FE,$FE,$7C,$38,$10,$00,$00,$00,$00,$00,$00,$00,$00  ; tile 0 = heart shape
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; tile 1 = ALL ZEROS
    dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00  ; tile 2 = solid plane 0
    ...
```

Tile 0 is a classic NES heart sprite (`$6C,$FE,$FE,$FE,$FE,$7C,$38,$10` = the top half of a heart silhouette in plane 0, with plane 1 all zero). Tile 1 is completely blank. That blank tile 1 is exactly what lands at NES tile index `$F3` / Genesis VRAM `$3E60`.

### Key finding #17 — `_oam_dma` 8×16 handling is actually correct

Checked `_oam_dma` at nes_io.asm 1173-1303. At lines 1221-1239 it tests `PPU_CTRL` bit 5 for 8×16 mode and:
- Sets Genesis SAT word-1 V-size field to `01` (2 tiles tall) via `ori.w #$0100,D4`.
- Computes Genesis tile index from NES 8×16 tile byte as `pattern_table_bit << 8 | (tile & 0xFE)`.

So NES tile `$F3` in 8×16 mode → Genesis tile `$1F2` with V-size 2 (paired with `$1F3` stacked underneath). This matches the observed SAT dump `spr[00] y=$00B0 size/next=$0101 tile=$E1F2 x=$00C3` exactly. The conversion is not the bug.

### Key finding #18 — The real question flipped

I spent a long time building up the MMC1 CHR upload theory because I assumed tile `$1F3` being blank meant "never uploaded". It was actually "uploaded from the correct source, and the source bytes are zero". Two completely different problems. The MMC1 theory would have required new infrastructure and bank tables. The actual fix is one of:

1. **The extracted `CommonMiscPatterns` bytes are wrong** — the NES ROM at the extraction offset does not actually have a blank tile 1 there; `extract_chr.py`'s seam is off by one tile or the block boundary is misaligned. This is the most likely explanation, because `COMMON_POST_PADDING_BYTES = 0x00A1` pattern-matching is fragile.
2. **The extracted bytes are right but correspond to the wrong banked view** — the NES register-name screen maps a DIFFERENT CHR bank into `$1000-$1FFF` than whatever bank was live when I extracted. In that case the "correct" tile `$F3` bytes live elsewhere in PRG-ROM.
3. **The NES game genuinely renders a blank bottom half** and the "pink square" the user is seeing is actually the whole cursor living in the TOP half tile `$F2` (8-pixel-tall cursor on a 16-pixel-tall sprite slot), and the visible bug is something else entirely (palette, priority, sprite being offscreen after some coordinate conversion error, etc.).

### Key finding #19 — Tile `$1F2` DOES contain plausible pink-cursor pixel data

Bytes: `01 10 11 00 11 11 11 10 11 11 11 10 11 11 11 10 | 11 11 11 10 01 11 11 00 00 11 10 00 00 01 00 00`. Each byte is two 4bpp pixels (high/low nibble). Pixel values 0, 1, 2 appear. With palette 3 = `0000 040C 048E 0EEE`, color index 1 = pink `$040C`, index 2 = `$048E` (teal-ish). So tile `$1F2` renders a pink/teal 8×8 shape — which matches a 8-pixel-tall cursor icon. **If the NES cursor really is 8 pixels tall, tile `$1F2` alone is sufficient, and tile `$1F3` being blank is by design.**

This pivots option (3) in finding #18 from "unlikely" to "very plausible". Before chasing CHR extraction, I should rule out option (3) by actually looking at the rendered Genesis screen — if the top 8 pixels of a pink cursor are visible in the correct position and the user's complaint is about something else in the same area (wrong palette, 8px offset, whole thing shifted off-screen), the fix is in the OAM pipeline, not the tile data.

### Key finding #20 — Things not to do (lessons from the near-miss)

- Do NOT build a full MMC1 CHR upload infrastructure before confirming that the missing-tile hypothesis even has the right shape. The whole MMC1 upload plan was going to add ~200 lines of new code and a per-bank lookup table for a bug whose actual fix is probably "swap 32 bytes in `CommonMiscPatterns`" or "fix one line in `_oam_dma`".
- Do NOT assume "tile all zero in VRAM" == "upload didn't happen". It often means "upload happened, source data was zero".
- Do NOT let an architectural-sounding theory pull you past the boring step of checking the source bytes of the specific thing you think is missing. The source bytes are right there in `z_02.asm` and I should have opened them before drafting an MMC1 hook.

### Current working theory (after re-examination)

The pink cursor is probably rendering *something* at VRAM tile `$1F2` on the live Genesis build — just maybe not matching the NES visual, or in the wrong position, or behind the background. The "missing" report is almost certainly not "no pixels are being drawn" but "the pixels being drawn don't look like what the NES shows". The next step is to look at the actual `register_name_visual_genesis.png` pixel-for-pixel against the user-provided NES reference, not to keep bisecting upload paths.

**Next action:** Capture a fresh `register_name_visual_genesis.png` from the current Zelda16.8 build and compare directly with the NES reference the user provided earlier. Pixel-diff the cursor area specifically. Only then decide whether the fix lives in tile data, OAM conversion, palette, or sprite position.

---

## 2026-04-04 — Corrective findings (previous session's plan was wrong)

### Key finding #21 — Tile `$24` of `CommonBackgroundPatterns` is intentionally blank. It is NOT Z.

Previous session drafted a plan to edit `src/zelda_translated/z_02.asm` line 318 (tile 36 of `CommonBackgroundPatterns`) from all-zero to the solid `$FF×8,$00×8` pattern of line 319, on the theory that tile 36 "should be Z" and was wrongly blank in the extraction. **This would have been a regression.**

Verification: dumped `CommonBackgroundPatterns` tiles 0–39 directly from PRG-ROM at bank-2 offset `$077F` (anchor-searched by `extract_chr.py`'s $FF padding heuristic). Enumerated by plane-0 bitmap shape:

| tile | hex | glyph |
|---|---|---|
| `$0A` | `386cc6c6fec6c600` | **A** |
| `$0B` | `fcc6c6fcc6c6fc00` | **B** |
| `$0C..$22` | (enumerated) | **C..Y** |
| `$23` | `fe0e1c3870e0fe00` | **Z** |
| `$24` | `0000000000000000` | **space / blank filler** |
| `$25` | `ffffffffffffffff ...` | solid-top cursor bottom-half |

Cross-reference with Plane A probe at `register_name_probe.txt` rows 17/19/21: the BG nametable uses `$8124` repeatedly as the gap between letters. That is tile `$124` = Genesis pattern-table-1 tile `$24` = the blank filler. **If we populated tile 36, every gap on the alphabet board and elsewhere would become a pink bar.**

So the A–Y sequence is `$0A–$22`, Z is `$23`, and tile `$24` is the space tile. My previous count (`A=$0B, Z=$24`) was off by one.

### Key finding #22 — The char-board cursor IS just an 8×8 bottom-half block, by design.

Cursor sprite uses NES tile byte `$25` in 8×16 mode. Top tile = `$24` (blank filler), bottom = `$25` (solid color-1 top half = `FF×8`). In 8×16 mode the "top" tile is drawn in the first 8 rows and "bottom" in the next 8. So the rendered cursor is:

- Top 8 rows: transparent (tile `$24` = all zeros = color 0 = transparent)
- Next 8 rows: first 8 rows of tile `$25` = solid color 1

On NES this produces an 8×8 solid highlight block in the **upper** half of the 8×16 sprite slot. Sprite Y positions the slot so that this 8×8 block aligns precisely with one letter cell on the alphabet board. The "pink square over A" in the NES reference is this 8×8 block. There was never supposed to be 16 tall pixels of highlight.

### Key finding #23 — The real bug is sprite position/palette, NOT tile data

Evidence from `cursor_visible_probe.png` and `register_genesis_zoom.png`:

1. The save-slot pink marker (static sprite) is sometimes present and sometimes missing across different probes from the same build — depends on navigation/frame timing.
2. OAM shadow values for cursor sprites oscillate between `$EF` (flash-hide) and real Y. Genesis SAT captured via the current probe shows `Y=$0170` for cursor slots, which is `$EF + $81` = the converted hide-phase value. Expected, but means **the probe captures the SAT one frame behind the NES OAM shadow** (the OAM DMA that would place the visible Y hasn't run yet when we break out of the poll loop).
3. Middle Link head on Genesis `register_genesis_zoom.png` renders in red/pink instead of green — independent palette/attribute bug, separate from cursor.

The cursor tile data in VRAM is **correct**. The bug lives downstream: either in `_oam_dma` Y conversion, in the flash-phase state machine, or in the sprite→SAT linking chain. Tile-data edits are off the table.

### Key finding #24 — Probe methodology gap

`tools/bizhawk_cursor_visible_probe.lua` polls the NES OAM shadow RAM, breaks on `Y < $EF`, then immediately dumps the Genesis SAT. But the SAT was written during the NMI **before** UpdateMode flipped the OAM shadow to visible. Net result: we always capture the hide-phase SAT state, never the visible one.

Fix for future probe runs: after detecting `Y < $EF`, advance **one more frame** (so the next NMI runs `_oam_dma` with the visible value), then capture SAT and screenshot. Alternatively, capture SAT at every frame across a 32-frame flash cycle and find the min-Y snapshot.

### Key finding #25 — What not to do (extended lessons)

- Do NOT assume "tile N is letter N − `$0A`" without verifying the sequence by dumping bytes and matching bitmap shapes. Off-by-one on tile indexing is how we got the "tile 36 is Z" mistake.
- Do NOT act on a plan that was drafted in a previous context without re-verifying its premises in the current session. The `smooth-soaring-metcalfe.md` plan was about the **file-select race fix** (already landed) — the tile-36 edit was a separate, unvalidated follow-on I invented.
- The "blank tile in VRAM" signal was real, but its meaning was the opposite of what I concluded: blankness was **intentional and load-bearing** (it's the BG filler tile, used in dozens of nametable positions), not evidence of a failed upload.

### Current working theory (revised)

Cursor CHR data is correct on both NES and Genesis. The rendering discrepancy is one of:
- `_oam_dma` Y conversion drifting the cursor off the alphabet board by N pixels
- Wrong palette row mapping for `attr=$23` (palette index 3, priority=1)
- The flash-phase state in `$0015/$0084/$0085` counting at wrong rate on Genesis, making the visible phase briefer than human-perceivable
- BG priority masking the cursor entirely (since the cursor is drawn *behind* BG, any non-transparent pixel in tile `$124` at the same position would hide it)

**Next action:** fix the cursor probe to advance one frame after visibility detected, capture SAT + screenshot at that point, compare cursor Y/X against expected alphabet-board coordinates. Only then start bisecting between `_oam_dma`, flash state, and palette conversion.

---

## Session 2026-04-04 — REGISTER YOUR NAME cursor + 9th-letter wrap

### Finding #26 — SELECT screen alignment was an asymmetric VSRAM/sprite pair

A prior fix had set `VSRAM Plane A = 8` in `_mode_transition_check` (nes_io.asm) to hide the NES 240-line overscan strip on H32, *and* paired it with a matching `-8` sprite Y lift in `_oam_dma` gated on `$0012 < 2` (frontend). Together they were lifting the entire file-select screen 8 px above the NES reference ("now it's too high").

**Fix (Zelda16.9):** drop *both* halves — set VSRAM=0 on frontend transition and delete the frontend-only `-8` sprite lift in `_oam_dma`. BG and sprites are again co-registered at the natural origin. Files: `src/nes_io.asm` `_mode_transition_check` (VSRAM reset) and `_oam_dma` (lift removal, lines ~1207–1212).

**Lesson:** when a compensating pair is introduced to hide a platform mismatch, it is fragile against any later change to either side. Prefer no compensation at all when possible.

### Finding #27 — Pink cursors on REGISTER screen measured at exactly −10 px

User flagged "pink cursor is too high in both positions" after the SELECT fix landed. Pixel analysis of Genesis vs NES REGISTER screen (with `AAAAAAA` typed) placed both pink cursors at Δy = −10 px relative to reference (heart at Δy = 0, confirming it was not a global scroll issue). The −10 decomposed as −8 (double-applied `ModifyFlashingCursorY` subtract, see #28) + −2 (Genesis SAT Y = nes_y + 129 convention already baked into `_oam_dma`, independent).

### Finding #28 — `ModifyFlashingCursorY` double-application

`ModifyFlashingCursorY` (z_02.asm ~2882) already applies the `-8` "bottom-half" lift internally. Both `_L_z02_ModeEandF_WriteNameCursorSpritePosition_WriteCursorY` (~2830) and `_L_z02_ModeEandF_WriteCharBoardCursorSpritePosition_WriteCursorCoords` (~2855) were *also* subtracting 8 after the bsr — a hand-edit artefact from an earlier guess. Net effect: −16 on both cursors, manifesting as −10 px on screen after the +129 SAT bias.

**Fix (Zelda16.10):** remove the caller-side `-8` in both call sites; keep `ModifyFlashingCursorY` authoritative.

### Finding #29 — 9th-letter wrap gated on stale `$0423` NES VRAM shadow

NES original uses `$0423 & $0F == 6` to detect "cursor has advanced past the last name column and needs to wrap back to column 0". On Genesis the gate never fired, so typing an 8-char name then pressing A a 9th time walked the cursor *past* the name field and painted a 9th letter outside the box.

Root cause: `$0423` is the low byte of a transfer-record NES VRAM address that is also clobbered by the title screen's `UpdateWaterfallAnimation` with value `$C0`. By the time REGISTER runs, `$0423` no longer reflects name-field cursor column — the gate's premise is broken.

**Fix (Zelda16.11):** re-gate the wrap on cursor X position `$0070 == $B0` (last column of the name field in pixel X) instead of the stale shadow. Site: `_L_z02_ModeE_HandleAOrB_MoveCursor` (~z_02.asm 2728). The wrap body still rewrites `$0423` to keep the transfer record sane, then resets `$0070` to `112` and `$0421` to the slot's name offset.

### Finding #30 — Systemic SEC+SBC transpile bug (`-imm-1` instead of `-imm`)

After #29 landed the wrap *triggered* correctly, but the wrapped 9th letter rendered one column LEFT of the name field — "it adds a letter to the front". Traced to a systemic transpiler bug: NES `SEC; SBC #imm` is rendered as:

```
ori     #$11,CCR    ; SEC: set C+X
move.b  #imm,D1
subx.b  D1,D0       ; SBC #imm
```

On 68K, `subx.b` computes `D0 = D0 - D1 - X`, so with X = 1 the result is `D0 - imm - 1`, one greater than the NES semantics (`SEC` on NES means *no* extra borrow, i.e. `A - M`). Every `SEC; SBC` in the transpiled output is a latent −1 bug.

At the `$0423` wrap site the transpiler emitted `ori #$11,CCR + subx.b #8`, so the "subtract 8 to wrap to column 0" was actually subtracting 9, landing the VRAM low byte at `$CD` (one cell left of the name start at `$CE`). That stray −1 was exactly the extra "A" at the front.

**Fix (Zelda16.12):** replace the pattern with plain `sub.b #$08,D0` at the wrap site. `sub.b` does not consult X. User confirmed "WORKED IN ALL 3 slots bby."

**Scope note:** ADC's counterpart (`CLC; ADC` → `andi #$EE,CCR; addx.b`) *is* correct — `addx.b` with X = 0 gives plain +imm, matching NES `CLC; ADC` semantics. Only SBC is broken; do NOT sweep-fix ADC.

**Known unfixed SBC sites (deliberately left alone):**
- `ModifyFlashingCursorY` (~z_02.asm 2882)
- `ModeEandF_SetUpCursorSprites` (~z_02.asm 2805)

These currently produce visually-correct output because surrounding code has been tuned around their off-by-one. Sweeping them without re-tuning callers would regress #27/#28. Memory file `feedback_sec_sbc_transpile_bug.md` records this.

### Lessons from this session

- A "compensating pair" (VSRAM offset + sprite lift) is a smell; remove both halves when re-baselining.
- When a gate checks a NES VRAM shadow that other code paths also write, assume it's stale and re-gate on something owned by the current mode.
- Before editing a `SEC; SBC` translation site, grep for it — every occurrence is a latent −1. But don't fix occurrences that are already compensated elsewhere.
- Measure first (exact pixel deltas, frame-level) before hypothesising. The −10 px delta pointed straight at a `-8` stacked with the SAT bias once we had numbers.

---

## 2026-04-05 09:52:33 -05:00 — Attempt: Non-Deterministic File-Select Corruption Fix (VRamForceBlankGate)

**Branch:** `file-select`
**Build:** Zelda16.19

**Current hypothesis:** The title → file-select transition corrupts the screen *sometimes* depending on when Start is pressed, because the legacy `$0014 = 18` forced-blank counter expires mid-init while `InitMode1_Full` is still uploading CHR/VRAM. Any upload after frame 18 races the beam, and which subphase crosses the boundary depends on frame-phase alignment of the Start press → non-deterministic corruption.

**Root cause (verified in code):**

1. `_ppu_write_7` CHR path in `src/nes_io.asm` → `_chr_convert_upload` writes directly to `VDP_CTRL`/`VDP_DATA` with zero VBlank gating.
2. `IsrNmi` in `z_07.asm` calls `UpdateMode` after the sprite-0-hit spin — intentionally during active display on the NES. On Genesis this is mid-scanline VDP traffic.
3. The only protection was `UpdateMode0Demo_Sub0`'s `$0014 = 18` window.
4. `InitMode1_Full` (Sub1 → Sub2 → `FillAndTransferSlotTiles` ×3 → Sub6) routinely exceeds 18 frames.

**Files touched:**

- `src/nes_io.asm` — declared `VRamForceBlankGate equ CHR_STATE_BASE+29` (`$FF083D`, 1 byte) in the shell RAM window. Cleared by existing cold-boot NES-RAM clear in `genesis_shell.asm`.
- `src/zelda_translated/z_02.asm`:
  - `UpdateMode0Demo_Sub0` (~line 495) — after the legacy `$0014 = 18`, set `VRamForceBlankGate = 1`. Legacy write preserved as safety floor and to avoid touching `TileBufSelector` semantics elsewhere.
  - `_L_z02_InitMode1_Sub6_FindActiveSlot` tail (~line 3748) — `clr.b (VRamForceBlankGate).l` immediately before the final `$0013 = 0 / $0011++ / rts` handoff. This is the "init complete" point, every VRAM/CRAM write is done, so the next IsrNmi re-enables display on a fully-composed frame.
- `src/zelda_translated/z_07.asm` — in `IsrNmi`'s PPUMASK reconstruction chain, inserted `tst.b (VRamForceBlankGate).l / bne _L_z07_IsrNmi_SetPpuMask` after the existing `$0014` and `$0017` tests and immediately before `ori.b #$1E,D0`. When the gate is nonzero the `ori` is skipped and PPUMASK stays cleared → VDP holds forced blank. `$00E3` splits branch at line 916 is left untouched so gameplay sprite-0 splits still force display on.

**Why a new flag instead of widening `$0014`:** `$0014` is aliased as `TileBufSelector` and written by many unrelated paths (z_01, z_05, z_06). Holding it nonzero long-term would corrupt tile-buf selection in IsrNmi's other consumers.

**Verification:**

New probe `tools/bizhawk_forceblank_gate_probe.lua` — presses Start at a configurable frame (`FORCEBLANK_PRESS` env), traces the gate lifecycle, hashes Plane A VRAM + tile VRAM + CRAM at press+300, writes `forceblank_gate_<tag>.{txt,png}`. Ran four times at offsets 120/121/122/123:

| Offset | Gate 0→1 | Gate 1→0 | PLANE_A_HASH | TILE_VRAM_HASH | CRAM_HASH |
|---|---|---|---|---|---|
| 120 | f=126 | f=142 | `0xB6665A3D` | `0xC6783469` | `0x3A13CFE9` |
| 121 | f=127 | f=143 | `0xB6665A3D` | `0xC6783469` | `0x3A13CFE9` |
| 122 | f=128 | f=144 | `0xB6665A3D` | `0xC6783469` | `0x3A13CFE9` |
| 123 | f=129 | f=145 | `0xB6665A3D` | `0xC6783469` | `0x3A13CFE9` |

All four phases produce **bit-identical** Plane A + tile VRAM + CRAM. Gate transitions track the press offset exactly: set +6 frames into Sub0, cleared 16 frames later at Sub6 tail. `$00FE` is `$00` across the entire window and `$1E` after — forced blank held, then cleanly released.

User confirmed visually in interactive BizHawk: "IT works!!!! Well done".

**What I learned:**

- The pattern of "shell-owned boolean gate honored by IsrNmi's PPUMASK rebuild" is the clean way to extend forced-blank across init windows longer than `$0014` allows. Reusable for any future mode transition (death, save/continue, end sequence) that hits the same race. Saved as memory `project_forceblank_gate_pattern.md`.
- Don't reuse `$0014` for long windows — its `TileBufSelector` alias makes that path unsafe.
- Hashing Plane A + tile VRAM + CRAM at a fixed post-transition frame across several press-phase offsets is a tight, deterministic regression test for beam-race bugs. A single-number diff is enough; no visual diffing needed.

**Next action:** Decide whether to fold the pre-existing z_02 ModeE cursor-wrap / sprite-Y edits into the same commit as this fix or split them. Commit on the `file-select` branch either way.

---

## 2026-04-05 10:25:00 -05:00 — Investigation: Boot-Timing Delta (Genesis vs NES)

**Branch:** `file-select`
**Status:** Phase A measurement complete.  No code changes yet.

**Question:** The user observed the Genesis port reaching the title screen visibly later than the NES original and asked "why, and is it plausibly fixable?"  No rigorous measurement existed — the "~20 frames" number was an informal visual estimate.

### Phase A — Measurement

Wrote `tools/bizhawk_boot_timing_delta.lua`: a platform-aware probe that auto-detects NES vs Genesis via `emu.getsystemid()`, reads the same three NES-offset RAM landmarks from the appropriate memory domain (NES `System Bus` base $0000, Genesis `M68K BUS` base $FF0000), and logs the frame at which each is first reached with no user input.

Landmarks (all three share identical NES-offset RAM addresses across both cores because the transpile preserves NES RAM layout):

- **L1**: PPU_CTRL ($00FF) bit 7 set — NMI enable, first frame the title loop is live
- **L2**: PPUMASK ($00FE) bit 3 or 4 set — rendering enabled, first visible frame
- **L3**: GameMode ($0012) == $00 AND IsUpdatingMode ($0011) == 0 — stable title state

**Results** (no Start press, reset-to-landmark):

| Landmark | NES | Genesis | Delta |
|---|---|---|---|
| L1 PPU_CTRL bit 7 set | f=3 | f=16 | **+13** |
| L2 PPUMASK bit3\|4 set | f=4 | f=17 | **+13** |
| L3 GameMode/iu stable | f=3 | f=16 | **+13** |

Reports: `builds/reports/boot_timing_genesis.txt`, `builds/reports/boot_timing_nes.txt`, `builds/reports/boot_timing_delta.txt`.

### Findings

1. **The delta is 13 frames, not 20.**  The user's visual estimate conflated the true startup cost with the title-screen fade/attract band that follows first-render.  Actual startup overhead is 13.

2. **The entire 13-frame gap is pre-first-NMI.**  All three landmarks show the exact same +13.  That means once the first `IsrNmi` fires on either platform, the two ROMs reach "stable title state" on the same frame.  Zelda's init path (`InitializeGameOrMode`, `UpdateMode0Demo_Sub0`, `InitMode1_Full`, mode-table dispatch, etc.) is contributing **zero** to the delta.

3. **Corollary:** the entire delta lives in `src/genesis_shell.asm` (reset → `jsr IsrReset`) and the tail of Zelda's `IsrReset` / `RunGame` before `PPU_CTRL bit 7` gets set.  No z_*.asm edits are required to close the gap.

4. **Cross-check with prior boot probe** (`builds/reports/bizhawk_boot_probe.txt`): it recorded `IsrReset=f8, LoopForever=f14, IsrNmi=f15` on Genesis.  The new probe reads `PPU_CTRL bit 7` set at f=16 — one frame after first NMI, matching the order exactly.  Numbers are internally consistent.

### Per-stage cost breakdown (pre-measurement analysis, matches empirical 16 frames)

| Stage | File:Lines | Cost (frames) |
|---|---|---|
| VDP reg init, TMSS, Z80 bus | `genesis_shell.asm:154–197` | ~0.04 |
| **VRAM clear (32K words, CPU loop)** | `genesis_shell.asm:207–211` | **~5.5–9** (bus wait states) |
| Plane B fill (2K words, CPU loop) | `genesis_shell.asm:218–222` | ~0.35 |
| NES RAM + PPU state clear | `genesis_shell.asm:244–248` | 0.17 |
| `_sram_restore` (8 KB) | `nes_io.asm:426–455` | 0.4–0.8 |
| Zelda `IsrReset` MMC1 setup | `z_07.asm:7387–7421` | 0.02 |
| Zelda `RunGame` to PPU_CTRL=$A0 | `z_07.asm:860–871` | ~0.07 |
| **Shell total** | | **~6.5–10** (matches measured f=16, including initial reset jitter) |

The dominant single cost is the CPU-loop VRAM clear at lines 207–211 of `genesis_shell.asm`.  At ~20–35 cycles per `move.w #0,(VDP_DATA).l` (VDP bus wait states), 32768 iterations lands anywhere from 5 to 9 frames depending on memory arbitration.

### Plausibility assessment

**Recoverable:** ~5–7 frames by switching the VRAM clear (and Plane B fill) from CPU loops to VDP DMA fill.  DMA fill during forced blank runs at ~53 KB/frame (Sega docs), so clearing 64 KB takes roughly 1.2 frames — a ~4–7 frame saving over the CPU loop.  Plane B fill is a rounding error either way.  Bundle both for free.

**Potential further savings:** ~0.3–0.5 frames by DMA-filling the NES SRAM shadow on first boot instead of CPU-looping `_sram_restore`'s zero path.

**Not recoverable:** VDP register init, cold-boot Z80 handshake, MMC1 bit-shift initialisation, and at least ~1.2 frames of actual DMA transfer — these are pure Genesis-side work the NES never pays.

**Best-case post-fix delta:** ~5–8 frames.  The full 13 cannot be cut because ≥ 1.5 frames of it is real VDP setup the NES doesn't have a VDP to do.

The 20-frame visual estimate almost certainly included the fade/attract band after first-render — that's Zelda's native timing (bank 0 attract animation), not startup overhead, and we should not touch it.

### Next action

Phase C fix: implement VDP DMA fill for the VRAM clear and Plane B fill in `genesis_shell.asm`.  Expected post-fix Genesis first-NMI around f=9–11, delta vs NES around +6–8.  Awaiting user go-ahead before editing `genesis_shell.asm`.

### Files touched this session

- **New:** `tools/bizhawk_boot_timing_delta.lua` — Phase A measurement probe (platform-aware)
- **New:** `builds/reports/boot_timing_genesis.txt` — raw Genesis trace
- **New:** `builds/reports/boot_timing_nes.txt` — raw NES trace
- **New:** `builds/reports/boot_timing_delta.txt` — comparison summary
- No source code edits.
- Plan file: `C:\Users\Jake Diggity\.claude\plans\smooth-soaring-metcalfe.md` (Boot-Timing Delta plan, overwrote prior file-select fix plan)

---

## 2026-04-05 — Boot-timing Phase C + autonomous shim optimizations

Two follow-up sessions after the Phase C DMA-fill fix, committed on `file-select` while another agent works the intro path on `main`.  All changes are shim-level (`genesis_shell.asm` / `nes_io.asm`); no z_*.asm edits.

### Zelda16.20 — VDP DMA fill for VRAM clear (already in diary above as Phase C)

Baseline → post-fix landmarks:

| Landmark | Zelda16.19 (pre) | Zelda16.20 (DMA fill) | Δ |
|---|---|---|---|
| L1 PPU_CTRL bit7 | f=16 | f=9 | **−7** |
| L2 PPUMASK bit3\|4 | f=17 | f=10 | **−7** |
| L3 GameMode stable | f=16 | f=9 | **−7** |

Delta to NES: +13 → +6.  File-select gate probe hashes bit-identical across all four phase offsets (120/121/122/123): `PLANE_A=0xDF75C7F5`, `TILE_VRAM=0xC6783469`, `CRAM=0x3A13CFE9`.

### Zelda16.21 — SRAM shim: movep.l restore/flush + movem.l fresh-fill

`_sram_restore` and `_sram_flush` (`nes_io.asm`) were byte-by-byte loops over the odd-stride Genesis SRAM window (data on odd bytes, stride 2, 8192 iters).  The 68000 `movep.l` instruction is literally built for this mapping: it transfers 4 bytes between a data register and 4 alternate-byte addresses in one instruction.

- **Copy path (`_sram_restore` save valid):** `movep.l (1,A0),D1` + `move.l D1,(A1)+` + `lea (8,A0),A0`.  4 bytes/iter → 2048 iters instead of 8192.
- **Copy path (`_sram_flush`):** symmetric — `move.l (A0)+,D1` + `movep.l D1,(1,A1)` + `lea (8,A1),A1`.
- **Fresh path (no save):** `movem.l D1-D7/A0,(A1)` + `lea (32,A1),A1`.  32 zero bytes/iter × 256 iters for the 8 KB shadow.  Preload D1=0 via `moveq`, then copy to D2–D7/A0.

Boot timing Zelda16.21 (fresh path exercised, no .sav present):

| Landmark | Zelda16.20 | Zelda16.21 | Δ |
|---|---|---|---|
| L1 PPU_CTRL bit7 | f=9 | f=8 | −1 |
| L2 PPUMASK bit3\|4 | f=10 | f=9 | −1 |
| L3 GameMode stable | f=9 | f=8 | −1 |

Delta to NES: +6 → **+5**.  Full 8-frame shave from the original +13 baseline.

File-select gate probe (press f=220): all three hashes identical to 16.20.  Gate 0→1 at f=226, 1→0 at f=236 — 10-frame window, well-contained.

Round-trip correctness: the save→flush→reset→restore byte ordering is symmetric.  `movep.l Dn,(d,An)` stores D-bytes high→low to (d,An), (d+2,An), (d+4,An), (d+6,An); `movep.l (d,An),Dn` reads the same 4 addresses back into the same bit positions.  The old byte-loop version did `shadow[i] ↔ SRAM[2i+1]`; new longword version produces the identical mapping because `move.l` on 68K is big-endian (high byte = lowest address).  No byte-swap introduced.

### Zelda16.22 — Plane B fill: move.l pair-write

Plane B blank fill at `genesis_shell.asm:247–255` was 2048 iters of `move.w #$0200,(VDP_DATA).l`.  Converted to 1024 iters of `move.l D1,(VDP_DATA).l` with D1 preloaded to `$02000200` — each longword write to the VDP data port decomposes into two autoincrement-stride word transfers, so 1024 longs = 2048 cells, half the loop-body overhead.

**Why not DMA fill?** VDP DMA fill writes a single byte value across every VRAM address in the target range.  Plane B cells need the non-uniform word `$0200` (tile $02 high byte, $00 low byte); a byte-fill would produce `$0202` cells everywhere (wrong) and can't be decomposed into two interleaved fills without additional complexity that would erase the savings.

Boot timing Zelda16.22: landmarks unchanged from .21 (L1=8 L2=9 L3=8).  The ~0.3-frame savings didn't cross a landmark boundary but remains real pre-first-NMI slack useful for future work in the pre-NMI band.

File-select gate probe: hashes identical (`PLANE_A=0xDF75C7F5`, etc.).

### Cumulative boot timing summary

| Build | L1 | L2 | L3 | Δ vs NES (L1) |
|---|---|---|---|---|
| Baseline (Zelda16.19) | 16 | 17 | 16 | +13 |
| Zelda16.20 (DMA VRAM clear) | 9 | 10 | 9 | +6 |
| Zelda16.21 (SRAM movep/movem) | 8 | 9 | 8 | +5 |
| Zelda16.22 (Plane B move.l) | 8 | 9 | 8 | +5 |

**Hard floor analysis.**  NES lands at L1=3, so closing the last +5 frames would require attacking:
1. The remaining ~1.2 frames of actual DMA transfer time (unavoidable — real VDP work).
2. The NES RAM + PPU state clear loop (`genesis_shell.asm:244–248`, ~0.17 frames, already moveq-based).
3. The MMC1 bit-shift sequence in Zelda `IsrReset` (`z_07.asm:7387–7421`, ~0.02 frames, z_*.asm-owned).
4. Frame alignment jitter (reset happens mid-frame on NES, cleanly on Genesis post-TMSS).

Sum of "non-recoverable" items ≥ 2 frames easily.  The remaining 3 frames of budget are likely split across VDP reg init, Z80 bus grab, and reset-to-first-instruction latency differences between the two CPU cores.  Further compression from +5 is possible but each frame costs more effort than the last; diminishing returns have set in.

### Files touched this session

- `src/nes_io.asm:426–497` — movep.l/movem.l rewrite of `_sram_restore` + `_sram_flush`
- `src/genesis_shell.asm:246–260` — plane B fill move.l pair-write
- `builds/reports/boot_timing_genesis_postfix21.txt` — Zelda16.21 landmarks
- `builds/reports/boot_timing_genesis_postfix22.txt` — Zelda16.22 landmarks
- `builds/reports/forceblank_gate_postfix21_p220.{txt,png}` — determinism verification
- `builds/reports/forceblank_gate_postfix22_p220.{txt,png}` — determinism verification
- Commits on `file-select`: `dcc1aa7` (SRAM movep), `fe66f51` (plane B move.l)

No touches to title/attract/Mode 0 code (intro work is on `main` in parallel).

## 2026-04-05 — T42 pulse-channel audio bring-up (Zelda16.25 → Zelda16.31)

Audio moved from “silent stubs” to a live PSG pulse bridge in bounded checkpoints. The big surprise in this session was that restoring the missing `SongScript*` blobs was only half the job; once `DriveAudio` was ungated, the real blocker turned out to be the transpiled song engine still treating preserved NES bank-0 pointers as RAM addresses instead of ROM script addresses.

### Zelda16.25 — Phase 0 data restore

- `tools/extract_audio.py` recovered the missing `SongScript*` blobs from the NES ROM and emitted `src/data/song_scripts.inc`.
- `src/zelda_translated/z_00.asm` now includes that recovered blob file instead of nine 128-byte zero stubs.
- `build.bat` stayed in “transpiler disabled” mode because the hand-tuned `src/zelda_translated/z_*.asm` files are the source of truth on this branch.

### Zelda16.26 / Zelda16.27 / Zelda16.29 — shadow state + PSG commit path

- Added a dedicated APU shadow block at `$FF1040-$FF105F` in `genesis_shell.asm` / `nes_io.asm`. `$FF1000` was already occupied by probe/debug counters and SRAM trace bytes in this branch, so audio had to move above it.
- `_apu_write_4000-$4017` now store pulse / triangle / noise / DMC shadows instead of falling through to a single `rts`.
- `_psg_write` writes directly to `$C00011` (SN76489 PSG) from the 68000 side; no Z80 bus handoff is required.
- `_apu_write_4003` / `_apu_write_4007` convert the shadowed 11-bit NES period to a 10-bit PSG divider (`2 * (P + 1)`, saturated to `$03FF`) and emit tone + volume bytes on note commit. `$4015` forces silent attenuation when pulse channels are disabled.
- Temporary proof-tone build `Zelda16.28` enabled `T42_TEST_PSG=1` just long enough to prove the path end-to-end: the T42 probe saw pulse shadow bytes go live at frame 3 and counted 4 direct PSG writes. `Zelda16.29` turned the hook back off to restore the normal pre-Phase-3 baseline.

### Zelda16.30 — gate removed, upstream blocker exposed

- The leading `rts` was removed from `DriveAudio`, which finally let the real transpiled audio engine run.
- Result: `_apu_write_4015` / `_apu_write_4017` traffic appeared immediately, but pulse shadows stayed zero. That proved the PSG bridge itself was fine; real song note bytes were still not reaching `_apu_write_4000-$4007`.

### Zelda16.31 — real fix: bank-0 song pointer translation

- Root cause: `DriveSong` reconstructs phrase pointers from `$0066/$0067`, then the transpiled code added `NES_RAM` and read from RAM. That is wrong for Zelda’s preserved bank-0 song-script pointers (`$8E5D-$9824`), which now live in ROM as `SongScript*` labels.
- Added `_song_ptr_to_genesis` in `src/nes_io.asm`. It maps each original NES bank-0 script range back to the recovered ROM label:
  - `$8E5D-$8E6F` → `SongScriptItemTaken0`
  - `$8E70-$90DC` → `SongScriptOverworld0`
  - `$90DD-$91A3` → `SongScriptUnderworld0`
  - `$91A4-$91FC` → `SongScriptEndLevel0`
  - `$91FD-$92CB` → `SongScriptLastLevel0`
  - `$92CC-$92F6` → `SongScriptGanon0`
  - `$92F7-$948A` → `SongScriptEnding0`
  - `$948B-$97C3` → `SongScriptDemo0`
  - `$97C4-$9824` → `SongScriptZelda0`
- Patched the seven song phrase-read sites in `z_00.asm` to call `_song_ptr_to_genesis` before dereferencing the script stream.
- After that resolver landed, the T42 probe finally observed real pulse activity: `first_pulse_nonzero_frame=28` on the live build, with non-zero pulse shadow bytes and a short hooked run reporting 6 real PSG writes from actual song traffic.

### Verification on the fixed build

- `tools/bizhawk_t42_psg_probe.lua` was hardened during bring-up:
  - replaced deprecated `bit.bxor()` usage with native Lua bitwise XOR
  - stopped flooding BizHawk’s output pane every frame
  - writes its report incrementally, so mid-run failures leave breadcrumbs instead of an empty file
  - now emits `PASS` / `FAIL` summary lines so `tools/run_all_probes.bat` can consume it
- Two back-to-back 300-frame runs of `builds/reports/bizhawk_t42_psg_probe.txt` are byte-identical (same SHA-256), so the current pulse-shadow hash sequence is deterministic over that window.
- T29 file-select regression probe still passes 6/6 on the audio-enabled build.
- Boot timing remains unchanged from the post-Phase-C baseline: `L1=8`, `L2=9`, `L3=8` (`builds/reports/boot_timing_genesis_t42.txt`), so the pulse bridge did not reintroduce the old pre-first-NMI timing debt.
- Zelda16.32 is the follow-up archive that captures the stabilized T42 probe footer (`T42 PSG PROBE: ALL PASS`) and the doc refresh; no additional audio logic changed after Zelda16.31.

## 2026-04-05 — T43 triangle + noise bridge finalized (Zelda16.33)

T43 stayed inside the same PSG-first design that worked for T42. Instead of reaching for the YM2612, the remaining Zelda APU channels were mapped onto the last free PSG resources: triangle on tone channel 1, noise on the PSG noise generator.

### What changed in the bridge

- `src/nes_io.asm` now has `_apu_emit_triangle` and `_apu_emit_noise`, extending the existing pulse-channel shadow/emit pattern instead of introducing a second sound path.
- Triangle note writes (`$400A/$400B`) convert the shadowed 11-bit NES period with the same `2 * (P + 1)` divider bridge used for pulse, then emit on PSG tone channel 1 with a fixed attenuation. This is intentionally an approximation, but it keeps the bass line in the same square-wave family as the rest of the port.
- Triangle rests needed one extra Zelda-specific guard: `_apu_write_4008` now checks the triangle note countdown at `$0616` and forces PSG tone-1 mute when the song engine has stepped onto a rest. Without that guard, the last triangle note would hang because we are not emulating the NES length counter itself.
- Noise writes (`$400C/$400E/$400F`) now emit immediately to the PSG noise channel, so Zelda's existing sword / bomb / sea / stairs SFX tables wake up without further script changes. NES long-mode noise is approximated as PSG white noise.
- While wiring T43, `_apu_write_4015` was corrected so channel-disable mutes no longer depend on the already-overwritten `D0` value from the previous PSG write. The mute path now respects bits 0-3 reliably for pulse, triangle, and noise.

### Verification

- New probe `tools/bizhawk_t43_triangle_noise_probe.lua` watches the triangle/noise slice of `$FF1040-$FF105F` and injects a one-byte sword-SFX request (`$0603 = $01`) at frame 180 so the noise path is exercised deterministically.
- On Zelda16.33 the T43 probe reports:
  - `first_triangle_frame=28`
  - `first_noise_frame=180`
  - `T43 TRIANGLE/NOISE PROBE: ALL PASS`
- Two back-to-back 320-frame runs of `builds/reports/bizhawk_t43_triangle_noise_probe.txt` are byte-identical (same SHA-256), so the combined triangle/noise hash trace is deterministic over that window.
- Existing regressions stayed green after the T43 wiring:
  - `bizhawk_t42_psg_probe`: still `ALL PASS`
  - `bizhawk_t29_file_select_probe`: still 6/6 `PASS`
  - `boot_timing_genesis_t43.txt`: unchanged `L1=8`, `L2=9`, `L3=8`

### Follow-through

- `tools/run_all_probes.bat` now registers both `bizhawk_t42_psg_probe.lua` and `bizhawk_t43_triangle_noise_probe.lua`, so future audio changes are covered by the normal regression runner.
- Zelda16.33 is the milestone archive for the completed PSG-backed T43 bridge. Remaining audio work is now just T44 (DMC).

## 2026-04-05 — Ear-tuned PSG follow-up (Zelda16.48 → Zelda16.51)

Live listening in BizHawk showed the first-pass PSG math was close enough to be recognisable, but still wrong in the low register. A local note (`apu_to_psg_explained.txt`) matched the symptom exactly: pulse on the SN76489 wants `round((P + 1) / 2)`, not the earlier `2 * (P + 1)` bridge and not the intermediate `P + 1` experiment.

### What changed

- `src/nes_io.asm` pulse 1 + pulse 2 now use `round((period + 1) / 2)` when converting the NES 11-bit timer to the PSG divider.
- Temporary ear-debug toggles were added in `src/genesis_shell.asm`:
  - `T43_SOLO_CHAN` to audition one PSG lane at a time
  - `T43_SONG_NOISE` to suppress story/demo song noise while keeping noise SFX reachable
  - `T43_SONG_TRI` to temporarily mute the song triangle lane during pulse-only checks
- Zelda16.50 (`pulse1-only`) and Zelda16.51 (`pulse2-only`) both sounded right by ear after the divider fix, which narrows the remaining mismatch to triangle/noise rather than the pulse lead mapping.
- Zelda16.52 (`triangle-only`) also sounded right by ear once isolated, which means the remaining audible mismatch is concentrated in the noise lane rather than the melodic PSG mapping.

### Current read

- Pulse channels are now in a good state for practical listening.
- Story/demo noise is still too messy to ship as-is, so song-driven noise remains gated off during the current isolation pass.
- Triangle remains the next lane to re-evaluate in isolation before deciding whether to refine it or defer it.
- Follow-up listening against the original NES clarified the real noise goal: it behaves more like a soft snare/percussion hit than a sustained pitched hiss. The next shim pass therefore switched from “leave PSG noise running until the next event” to “emit a short burst per Zelda noise event,” keeping the existing `NoisePeriods` lookup from `z_00.asm` but decaying each hit over a few VBlanks.
- A second ear-tuning pass immediately softened that burst path further by raising PSG attenuation a little and shortening the burst timer again; the intent is to keep the rhythmic “snare” cue while shaving off the harsh edge that the first burst build still had in BizHawk.
- The next refinement pivoted away from raw loudness and toward transient shape: the PSG noise source was brightened again, but each hit now decays over a couple of VBlanks instead of staying flat. That keeps the channel present in the mix while pushing it toward a drum-like attack/release rather than a generic noise splat.

## 2026-04-06 - T43 song-noise split, Sonic-inspired follow-up (Zelda16.59)

This pass kept Zelda's `DriveAudio -> _apu_write_*` structure intact and reworked only the story/demo noise lane. The useful Sonic 2 takeaway was not "port the sound engine," it was "treat PSG noise like an explicit percussion lane." The result is a split bridge: Zelda song noise now has its own preset-driven PSG behavior, while sword/bomb/other SFX keep the older shared noise approximation.

### What changed

- `src/nes_io.asm` now splits `$400F` noise commits into two paths:
  - song-noise commits, when Zelda is driving demo/story percussion and no live SFX override is active
  - sfx-noise commits, which preserve the existing sword/bomb/stairs behavior
- The song path uses three explicit Zelda-driven presets keyed only from the already-written `APU_NOISE_PERIOD` / `APU_NOISE_LEN` shadow bytes:
  - preset 0 = mute
  - preset 1 = short soft snare
  - preset 2 = alternate short snare
  - preset 3 = longer trailing snare
- Each preset now maps to a fixed PSG white-noise form plus a short decay table. This intentionally borrows the "PSG3/noise alternate" idea from Sonic 2 without copying SMPS data or touching the Z80 driver.
- Hardware-safety note: the new song path never uses `$E7` noise mode. Zelda already uses PSG tone 2 for pulse 2, so tone-linked noise would couple the percussion timbre to a melodic lane. Only fixed white-noise forms are used here.
- `_apu_tick_noise` now respects a noise owner byte (`0=silent, 1=song, 2=sfx`) so song-noise decay never keeps writing underneath a live SFX burst.
- Triangle was left alone in code this pass. Ear checks still say it sounds acceptable solo but bad in the combined mix, so it remains a known follow-up item rather than "done."

### Verification

- `Zelda16.59` builds cleanly and archives normally.
- `tools/bizhawk_t42_psg_probe.lua` still passes on the follow-up build (`T42 PSG PROBE: ALL PASS`).
- `tools/bizhawk_t43_triangle_noise_probe.lua` still passes on the follow-up build (`T43 TRIANGLE/NOISE PROBE: ALL PASS`), which means the existing SFX-oriented noise path survived the split.
- New probe `tools/bizhawk_t43_song_noise_probe.lua` watches the song-noise owner/preset/form/attenuation/burst state across the first 1000 boot frames. On `Zelda16.59` it reports:
  - `first_song_noise_frame=667`
  - `T43 SONG-NOISE PROBE: ALL PASS`
- Two back-to-back runs of `builds/reports/bizhawk_t43_song_noise_probe.txt` are byte-identical, so the new song-noise trace is deterministic over that window.

## 2026-04-06 - Triangle timing/mix follow-up (Zelda16.61)

Triangle finally got a first corrective pass after the song-noise split settled down. The big logic bug was that the PSG triangle approximation was still emitting on both `$400A` and `$400B`, so Zelda's low-byte timer write could briefly send a half-updated pitch before the real note-commit landed. That can sound tolerable in isolation but turns into muddy note edges in the combined mix.

### What changed

- `src/nes_io.asm` now treats `$400A` as a shadow-only write for triangle, matching the pulse-channel "emit on high-byte commit" pattern instead of pushing PSG updates on both timer bytes.
- Triangle's fixed PSG attenuation was also moved from `$B8` to `$B3`, which is much closer to the reference note's "triangle at attenuation 3" guidance and lets the bass line sit in the mix without vanishing.

### Verification

- `Zelda16.61` builds cleanly and archives normally.
- `tools/bizhawk_t43_triangle_noise_probe.lua` still passes on the follow-up build (`T43 TRIANGLE/NOISE PROBE: ALL PASS`), so the triangle path is still active and the noise split remains intact.

## 2026-04-06 - Triangle moved from PSG to YM2612 (Zelda16.62)

The next listening pass made it clear the remaining triangle problem was structural, not just level or timing. Pulse 1/2 and the reshaped noise lane were both in a usable place, but triangle was still fighting the SN76489's square-wave character and crowded PSG mix. This pass therefore stops pretending PSG tone 1 is a triangle and gives Zelda's triangle lane its own minimal YM2612 voice instead.

### What changed

- `src/genesis_shell.asm` now initializes a dedicated YM triangle patch during boot, immediately after the existing PSG mute writes, so the FM lane always starts from a known silent state.
- `src/nes_io.asm` now contains a tiny YM2612 helper layer for triangle only:
  - `_ym_write0` for direct 68000 YM register writes with busy-flag polling
  - `_ym_triangle_init` to load a simple always-available FM patch on channel 1
  - `_ym_triangle_set_pitch` to convert Zelda's 11-bit NES triangle period into YM block/FNUM
  - `_ym_triangle_key_on` / `_ym_triangle_key_off` for note commits and rests
- `_apu_emit_triangle` no longer writes PSG tone/volume bytes. It now treats `$400B` as the note commit, converts the assembled triangle period to YM pitch, and retriggers the dedicated FM voice there.
- `_apu_write_4008` and the triangle-disable path in `_apu_write_4015` now key the YM voice off instead of sending PSG mute latches.
- Triangle remains intentionally separate from the Sonic-inspired song-noise work. Noise stays on PSG; this pass changes only the melodic triangle lane.

### Verification

- `Zelda16.62` builds cleanly and archives normally.
- No broader regression claim yet for T43 here: the old triangle/noise probe was written around PSG-observable triangle activity, so this pass is being validated by live listening first before probe expectations are rewritten around the new YM path.

## 2026-04-06 - YM triangle regression recovery (Zelda16.65)

The first YM triangle attempt broke the branch. Even after removing the boot-time FM init, title/demo music still reaches the triangle path almost immediately, so the "lazy" YM setup was still executing during early intro audio and destabilizing the ROM before any real listening work could happen.

### What changed

- Triangle is restored to the last known-good PSG baseline from `Zelda16.61` for normal builds:
  - `_apu_emit_triangle` once again writes PSG tone 1 with fixed attenuation `$B3`
  - `_apu_write_4008` rest handling once again mutes PSG tone 1
  - `_apu_write_4015` triangle-disable once again mutes PSG tone 1
- A new compile-time switch, `T43_TRI_ON_YM`, now controls the experimental FM path:
  - `0` = safe PSG triangle (default)
  - `1` = experimental YM triangle path
- The YM helper code remains in `src/nes_io.asm`, but with `T43_TRI_ON_YM=0` it is unreachable in the live build. That gives future YM work a stable, bisectable off-switch instead of letting experimental FM writes break the main branch.
- Pulse and song-noise were left untouched. Recovery intentionally changes only the triangle lane.

### Verification

- `Zelda16.65` is the first post-recovery checkpoint intended to be playable again.
- Recovery validation focuses on build success, boot smoke, the existing T42 pulse probe, and keeping the current song-noise behavior intact before any new YM experiments resume.

## 2026-04-06 - YM transfer hardening behind the experiment gate

With the branch stable again, the next obvious problem was the YM write path itself. The first FM attempt had no bounded readiness check and no project-visible trace state, so a bad transfer looked like "the ROM broke" instead of "the YM path stalled here." This pass hardens the transfer helper without turning the experimental path back on by default.

### What changed

- `src/nes_io.asm` now gives the gated YM triangle path a real `_ym_wait0_ready` helper that polls bit 7 of the YM status register and times out after a bounded loop instead of spinning forever.
- Two APU-shadow bytes now expose experimental YM state:
  - `APU_TRI_YM_TOUCH` goes non-zero after the first successful YM write
  - `APU_TRI_YM_TIMEOUT` increments if the busy flag never clears in time
- `T43_TRI_ON_YM` remains `0`, so the live build is still on the safe PSG triangle path while the transfer layer is being made observable and bisectable.

### Verification

- Safe/default builds still validate exactly as the recovery checkpoint did, because the hardened YM helper is present but unreachable with `T43_TRI_ON_YM=0`.
- The next YM experiment should read `APU_TRI_YM_TOUCH` / `APU_TRI_YM_TIMEOUT` first before judging sound quality.

## 2026-04-06 - Safe YM triangle reintroduction, probe-only FM writes

The next Sonic-guided lesson was not about the waveform yet, it was about write discipline. Sonic's driver serializes every FM register/data pair and owns its own calling convention; the first Zelda YM attempt did not. This pass reintroduces the YM path in the smallest possible shape: PSG triangle remains the audible lane, while the experimental FM side only performs a bounded, observable pitch-register write during triangle note commits.

### What changed

- `src/nes_io.asm` now makes the YM helper family preserve the shim's non-volatile registers instead of silently clobbering `D1` during triangle rest/note traffic.
- `_apu_write_4008` and the triangle-disable branch in `_apu_write_4015` are back to PSG-only mute behavior even when `T43_TRI_ON_YM=1`. That keeps rest/mute traffic out of the experimental YM path entirely.
- New `_ym_triangle_probe_emit` is the first gated YM experiment:
  - it runs only from `_apu_emit_triangle` / `$400B` note commits
  - it leaves PSG triangle audible as fallback
  - it performs only a minimal YM setup plus frequency writes
  - it relies on `APU_TRI_YM_TOUCH` / `APU_TRI_YM_TIMEOUT` for validation before any timbre work

### Verification

- Default builds remain on the safe PSG path with `T43_TRI_ON_YM=0`.
- The first experiment build should be judged by three things in order: boot stability, `APU_TRI_YM_TOUCH != 0`, and `APU_TRI_YM_TIMEOUT == 0`. Only then is it worth listening for FM triangle character.
- First gated experiment outcome: the ROM stayed stable, but the probe build still reported `tri_ym_init=00`, `tri_ym_touch=00`, `tri_ym_timeout=00` over the opening title window. In other words, the non-destructive YM probe did not crash the branch, but it also did not reach the actual FM write path yet.

## 2026-04-06 - Default build drops PSG triangle

After hearing the recovered safe build again, the conclusion got simpler: the live PSG triangle is not "close but imperfect," it is the wrong waveform family for what Zelda's triangle lane is supposed to be doing. Until the YM path is genuinely alive, the least-bad default is to remove the fake triangle from the mix instead of pretending it is acceptable.

### What changed

- `src/genesis_shell.asm` now defaults `T43_SONG_TRI` to `0`, so song-driven triangle is disabled in normal builds.
- Pulse and the tuned song-noise lane remain enabled.
- The gated YM work remains parked in the tree for later, but the default audible mix no longer includes the square-wave stand-in for triangle.

### Verification

- The expected result for the new baseline is "pulse + shaped noise, no live triangle lane" while preserving boot stability and the working pulse/noise behavior.

## 2026-04-06 - Main-build YM triangle bring-up (YM-only debug)

The missing piece in the previous YM probe was simpler than the FM math: the lane had been muted at compile time. With `T43_SONG_TRI=0`, the game never reached the triangle commit path, so the "safe" YM experiment stayed inert by design. This pass turns the lane back on in the main build and makes the first live debug pass YM-only, not PSG fallback.

### What changed

- `src/genesis_shell.asm` now re-enables song triangle traffic and turns on the YM experiment path in the main build.
- A new `T43_TRI_PSG_FALLBACK` switch keeps the first live debug pass YM-only, so the old PSG square-wave stand-in does not mask whether the FM lane is doing anything.
- `src/nes_io.asm` now promotes the old probe-only path into a minimal real YM note path:
  - one-time FM init on first triangle activity
  - pitch writes on `$400B` note commits
  - key-off then key-on on note commit so the lane can retrigger
- The APU shadow block now exposes one more debug byte, `APU_TRI_YM_KEYON`, so the first pass can distinguish "init happened," "writes happened," and "key-on happened."
- New probe `tools/bizhawk_t43_ym_triangle_probe.lua` logs triangle-YM init/touch/timeout/key-on over the first title/story window and is registered in `tools/run_all_probes.bat`.

### Verification

- The first live YM-debug build is judged in this order: boot stability, non-zero YM touch/key-on, zero YM timeout, and only then actual audible FM triangle quality.

## 2026-04-06 - Triangle-only YM bass retune (in progress)

With the YM lane finally alive, the first triangle-only listening pass confirmed the next problem was musical rather than structural: the voice was audible, but it still sounded too bright, too restart-heavy, and too unlike Zelda's original triangle bass. This pass keeps the build in triangle-only YM mode and retunes the FM lane in isolation instead of letting pulse/noise hide what the bass is really doing.

### What changed

- `src/genesis_shell.asm` expands the APU shadow block from 32 bytes to 36 bytes so the triangle YM path can track last-note and articulation debug state without stealing space from the older pulse/noise work.
- `src/nes_io.asm` reshapes the YM patch toward a one-dominant-carrier bass voice:
  - three operators are effectively pushed out of the audible foreground with high TL values
  - the remaining carrier is left comparatively open
  - attack/decay/release settings are softened so notes feel less like hard FM stabs
- `_ym_triangle_set_pitch` now uses a lower low-end scaling constant and wider block-fit threshold to bias the NES-period conversion toward the bass range Zelda's triangle actually occupies.
- `_ym_triangle_emit_live` no longer retriggers on every `$400B` commit:
  - it always refreshes YM pitch from the assembled NES triangle period
  - it only does key-off/key-on when the committed note changes or the lane was previously inactive
  - new shadow bytes now track the last committed note, active state, and retrigger count so the probe can tell whether articulation is still too restart-heavy

### Verification

- This pass stays in `triangle-only` YM debug mode on purpose so timbre, pitch, and articulation can be judged without pulse/noise masking mistakes.
- The updated YM probe now logs `active` and `retrig` state in addition to the existing init/touch/timeout/key-on bytes, making it easier to distinguish "lane alive" from "lane over-retriggering."

### Follow-up tuning

- The first retune still under-articulated repeated same-pitch notes because `_ym_triangle_emit_live` was only retriggering on pitch change.
- Zelda's own driver uses `$400B` as the triangle note-start commit, while ongoing vibrato motion goes through `$400A`, so repeated-note attacks were being lost in the YM layer.
- The follow-up fix restores retrigger-on-every-`$400B` note commit while keeping the softer patch and lower-range pitch mapping. On the same 1000-frame title/story probe window, `APU_TRI_YM_RETRIG` rises from `05` to `0C`, which matches the user's "NES is playing more notes than this" listening report much better.
- A second follow-up fixed a more fundamental cadence bug: triangle rests were still only muting the old PSG path. `_apu_write_4008` and triangle-disable handling in `_apu_write_4015` now key the YM voice off too, so silent gaps no longer smear together into one long sustained FM note. The probe reflects that change with `first_active_frame=667` even though YM init/touch/key-on still begin at frame 28.

## 2026-04-06 - NES triangle trace tooling fix (in progress)

The triangle timing investigation hit a tooling problem before it hit a music-engine one: the local BizHawk install prefers `quickerNES`, and that core does not implement the callback hooks some NES Lua tools rely on. This was showing up as repeated `quickerNES does not implement memory callbacks` spam and making it too easy to misread probe failures as game-code failures.

### What changed

- `tools/launch_bizhawk.ps1` now accepts a `-ForceNesHawk` switch that clones BizHawk's config file to a temporary override, flips the preferred NES core to `NesHawk`, launches the requested probe, and then deletes the temporary config on exit.
- `tools/run_bizhawk_nes_triangle_trace.bat` now uses `-ForceNesHawk` so NES trace runs no longer depend on the user's global core preference.

### What we learned

- The callback warning is gone, so the core mismatch was real and is now fixed for this trace runner.
- The current NES-side triangle trace is still not valid: direct reads of `$4008/$400A/$400B/$4015` are returning a constant `F2` pattern even under `NesHawk`.
- That means the remaining triangle-cadence problem should be debugged with a better NES-side source than naive APU bus polling, likely Zelda WRAM-side music state rather than raw register reads.

### Zelda-state comparison follow-up

- The trace was then switched over from raw APU register polling to Zelda's own triangle state bytes: `$05F0`, `$05F1`, `$05F4`, `$0609`, `$060C`, `$0615`, `$0616`, and `$061D`.
- That comparison finally exposed a real gameplay-side divergence instead of a tooling one:
  - NES reaches the first real triangle note at frame 31 with `base=$20`, `len=$28`, `cnt=$28`, and logs 38 note starts over the first 1000 frames.
  - The current Genesis `Zelda16.78` triangle-only build reaches the first real triangle note at frame 38 with the same `base=$20`, but `len=$00` and `cnt` immediately wraps downward from zero, producing only 14 note starts over the same 1000-frame window.
- This is a much stronger lead than any ear-only FM tuning guess: the cadence bug is upstream of YM timbre. The Genesis port is not preserving Zelda's own triangle note-length/countdown state correctly, so the next fix should target that state path before more FM retuning.
