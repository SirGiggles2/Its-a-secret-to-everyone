# Debate 006 — RoomRom + Drain + Title.md Unification: Synthesis

**Date:** 2026-05-03
**Participants:** Codex (CLI), Gemini (CLI), Sonnet (Agent), Opus (architecture lens)
**Mode:** thorough cross-critique, 2 rounds, ~400 words/advisor
**Caveman mode:** active
**Stakes:** most architecturally consequential decision of the project to date

---

## TL;DR

**Pick: Path D3 (one `platform_abi.h` with `#ifdef ROOMROM_BUILD` dropping A4 register pinning).**

- Both ROMs survive permanently (per user clarification: "I still want them to be separate roms. This makes testing WAY WAY EASIER, but structurally they need to be combined at the end")
- Shared `src/game/` source tree compiled twice with different ABI flag
- Drain becomes oracle (`src/oracle/`), not runtime
- Phase 12 = "src/oracle/ empty AND both ROMs pass parity on shared src/game/"

D3 is REVERSIBLE — drop the ifdef later → become D2 (Codex/Gemini's pick) if Title.md is rewritten or perf testing shows A4 doesn't matter. D2 → D3 reverse is harder (re-adding register pinning). **D3 = D2's safer ramp.**

---

## Round 1 → Round 2 evolution

| Advisor | R1 vote | R2 vote (post user-clarification) |
|---------|---------|----------------------------------|
| Codex   | A (delete RoomRom) | **D2** (drop A4 everywhere; D2 > D3 > D1) |
| Gemini  | A (delete RoomRom) | **D2** (kill A4 pinning; "transpile-era radiation") |
| Sonnet  | A (delete RoomRom) | **D3** (single header w/ ifdef; D3 > D1 > D2) |
| Opus    | B (port drain INTO RoomRom; retire Title) | **D3** (single header w/ ifdef; matches SGDK pattern) |

User clarification mid-debate REJECTED Path A entirely (3/4 r1 votes invalidated). Reframe to Path D = both ROMs permanent + shared src/.

R2 vote 2-2 between D2 and D3. **Synthesis breaks tie for D3** on reversibility + autonomy + perf-conservatism.

---

## Path D3 — concrete plan

### Phase D0 — substrate (1 commit, ~2 hours)

1. **Edit `src/abi/platform_abi.h`:** wrap A4 register binding in `#ifndef ROOMROM_BUILD`:
   ```c
   #ifdef ROOMROM_BUILD
   extern volatile unsigned char *nes_ram;  /* regular global pointer */
   #else
   register volatile unsigned char *nes_ram asm("a4");  /* Title.md A4 pin */
   #endif
   #define RAM(off)         (nes_ram[(off)])
   #define OBJ(off, slot)   (nes_ram[(off) + (slot)])
   ```
2. **Edit `RoomRom/build.bat`:** add `-DROOMROM_BUILD` to CFLAGS, drop `-ffixed-a4` if present.
3. **Edit `src/genesis_shell.asm` boot OR add `RoomRom/src/boot/nes_ram_init.c`:** allocate `static unsigned char roomrom_nes_ram[0x800]; volatile unsigned char *nes_ram = roomrom_nes_ram;` at boot, before any C runs.
4. **`build_all.bat`** at repo root: invokes `build.bat` (Title.md) THEN `RoomRom/build.bat` (RoomRom.md). Single command builds both ROMs. Required to prevent build-matrix drift.
5. **Verify both build green:** Title.md unchanged behavior, RoomRom.md links empty cave dispatch (no callers yet).

Commit: `abi: D3 substrate — non-A4 nes_ram for ROOMROM_BUILD; build_all.bat dual-target`

### Phase D1 — drain becomes oracle (1 commit, ~1 hour)

1. `git mv src/game src/oracle` — drained C tree becomes reference role.
2. Update master plan Rule D1 + state_contract.md + memory `feedback_drain_primary_nes_secondary` to reference `src/oracle/`.
3. Existing transpile-bridge consumers (`src/gen/z_01.c`) keep importing from `src/oracle/` paths via include path update — no behavior change for Title.md.
4. **Create empty `src/game/`** as the new native rewrite destination.

Commit: `state: rename src/game/ → src/oracle/ (drain reference role); create src/game/ for native impls`

### Phase D2 — Cave subsystem first leaf (1-2 days)

1. **`src/game/cave/cave_dispatch.c`** — native gameplay entry. Reads `src/state/cave_state.h` typed structs (substrate already landed this session). Implements: `cave_init(cave_id)`, `cave_tick()`, `cave_render()`. NES-accurate per `src/oracle/cave/cave_runtime.c` reference + `reference/aldonunez/Z_01.asm` spec.
2. Wire into RoomRom: `RoomRom/src/main.c` adds `SCENE_CAVE` enum. Direct boot to cave for fast iteration.
3. Wire into Title.md: replace `src/gen/z_01.c` cavert_* callsites with `cave_*` (native) calls, gated by `#ifdef NATIVE_CAVE`. Allows incremental cutover per cave function.
4. Verify both ROMs still pass per-function diff (Gate 1) against `src/oracle/cave/`.

Commits:
- `game: src/game/cave/cave_dispatch.c — native cave entry (Gate 1 verified vs oracle)`
- `roomrom: SCENE_CAVE direct boot using src/game/cave/`
- `title: cutover src/gen/z_01.c cavert_* → src/game/cave/ (parity verified)`

### Phase D3 — Title.md debug boot mode (1 commit, ~3 hours)

Add `-DDEBUG_BOOT_GAMEPLAY=1` flag to `build.bat`. When set, Title.md's main loop skips intro/title/file-select and jumps directly to a gameplay scene (configurable via `DEBUG_BOOT_SCENE=cave_77`). Sidesteps `project_title_story_crash` for Title.md gameplay testing without waiting for the story-scroll crash fix.

Commit: `title: debug boot mode skips intro/title/FS for fast gameplay iteration`

### Phase D4 — Per-leaf port loop (ongoing, weeks)

For each subsystem (room → world → items → combat → enemies → hud → frontend):
1. Read `src/oracle/<subsystem>/*_runtime.c` end-to-end. Gate 1 finding doc.
2. Write `src/game/<subsystem>/*.c` native impl. Use typed `src/state/` structs.
3. Wire into both ROMs (RoomRom direct, Title.md cutover from src/gen/).
4. Per-RAM-cell trace (Gate 2). Per-scenario oracle (Gate 3) at family close.
5. Phase 12 close-gate criterion: zero `*_runtime.c` files remain in `src/oracle/`.

---

## Risk mitigation (panel-merged)

| # | Risk | Mitigation |
|---|------|-----------|
| 1 | Build-matrix drift (one ROM rots) | `build_all.bat` runs both per commit; CI gate fails on either |
| 2 | A4-flag mishap breaks Title hot paths | `#ifdef ROOMROM_BUILD` is build-time; Title path unchanged unless flag set |
| 3 | nes_ram pointer initialization gap | Init in `RoomRom/src/boot/nes_ram_init.c` BEFORE any C runs; assertion that points at non-NULL |
| 4 | Behavior drift between ROMs | Per-function Gate 1 diff stays mandatory; both ROMs link same `src/game/` source |
| 5 | Worktree confusion | CLAUDE.md HARD rule already covers worktree check; `feedback_check_worktree_first` |

---

## Convergences (4/4)

| Item | Resolution |
|------|-----------|
| Drain role | **Oracle**, not runtime. Move `src/game/` → `src/oracle/`. Native rewrite destination = new `src/game/`. |
| Both ROMs permanent | Yes. Title.md = full game. RoomRom.md = direct-boot test cartridge. |
| Debug boot mode | Mandatory. RoomRom IS the debug boot for gameplay. Title.md gets `DEBUG_BOOT_GAMEPLAY` flag for frontend-bypass testing. |
| Phase 12 deliverable | Redefined: "src/oracle/ empty AND both ROMs pass parity oracle harness on shared src/game/". Combine = packaging concern, not source concern. |

## Divergences resolved

| Issue | Resolution |
|-------|-----------|
| D2 vs D3 | **D3** — reversible to D2 anytime; D2→D3 reverse is harder; D3 preserves Title perf today |
| First commit | **D0 substrate + build_all.bat** (Opus's call); enables every other step |
| Drain location naming | `src/oracle/` (Sonnet's term, all converged) |

## Maintainability ranking (panel-merged)

- **D3**: one header, two builds, zero drift surface — ✅
- **D2**: one header, no perf compromise long-term, but Title perf cost today
- **D1**: two headers, manual sync, drift guaranteed within 3 commits — rejected

---

## Master plan changes

1. **Rule D1 (debate 005)** — update reference path: `src/game/` → `src/oracle/`. Drain stays oracle. New `src/game/` is the native rewrite destination.
2. **Phase 12 close-gate (Phase 12.0)** — change criterion from "merge RoomRom into Title" to **"`src/oracle/` empty AND both ROMs pass parity on shared src/game/"**.
3. **New Phase 0.5: D3 substrate** — `platform_abi.h` ifdef + `build_all.bat` + `src/oracle/` rename + Title.md debug-boot flag. BLOCKING all gameplay phases.
4. **Phase 3 task list** — already drain-aware per debate 005; now also acknowledges shared-source target. Tasks 3.2-3.10 implement in `src/game/cave/`, both ROMs link it.
5. **Workstream H (new)** — substrate maintenance: keep `platform_abi.h` ifdef clean, build_all.bat green, oracle/ retirement progress.

---

## Time estimate

| Step | Time |
|------|------|
| D0 substrate (platform_abi ifdef + build_all.bat + boot init) | 2-4 hours |
| D1 oracle rename + new src/game/ skeleton | 1 hour |
| D2 cave native impl + wire both ROMs + Gate 1 verify | 1-2 days |
| D3 Title debug boot flag | 3 hours |
| First end-to-end Cave running in BOTH ROMs | 2-3 days total |
| Full oracle retirement (all 433 drain funcs ported) | weeks (per-family cadence) |

---

## Final stance

| Vote | R2 verdict |
|------|-----------|
| Codex   | D2 (D3 acceptable) |
| Gemini  | D2 (D3 acceptable) |
| Sonnet  | **D3** + oracle/ split |
| Opus    | **D3** + oracle/ split + build_all.bat |

**Synthesis: D3.** Tiebreaker: reversibility + autonomy + Title perf preservation. D3 is the path that preserves all options while moving forward. If Title.md gets fully rewritten in Phase 11 (story crash fix + native frontend), D3 → D2 is one ifdef removal away.

**Stance: GREEN** on autonomous achievability for D0 + D1 + D2 (cave). YELLOW on D4 enemies (CHR extraction blocker per memory `project_chr_extraction_items_blocker`).

---

## Cost / artifacts

- 4 advisors × 2 rounds = 8 advisor outputs (~24KB)
- Round files: `debates/006-roomrom-drain-title-unification/round{1,2}/{codex,gemini,sonnet,opus}.md`
- Synthesis: this file
- Architectural impact: **highest of any debate this session**. Resets Phase 3-12 task model + introduces oracle role + permanent dual-ROM build matrix.
