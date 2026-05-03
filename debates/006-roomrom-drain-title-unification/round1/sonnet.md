# SONNET ADVISOR — Round 1

## Verdict: PATH A (Unify NOW: RoomRom -> src/game/)

Caveman: A4-pinned bridge is technical debt walking. RoomRom is the future.
Drain stays as ORACLE not as runtime. Move RoomRom into src/game/, delete
RoomRom/ tree, debug-boot skips title crash. Cave drain becomes reference
material we port piecemeal.

## 1. A/B/C + defense

**A.** Prime Directive #1 (best long-term) and #2 (best practice) BOTH
pick A. Path B perpetuates `register volatile unsigned char *nes_ram
asm("a4")` and `-ffixed-a4` across the entire codebase forever. That is
not Genesis-native — that is "transpiled NES with extra steps." Memory
`feedback_full_native_rewrite` is explicit: "don't patch transpiled code
for visual sequences; rewrite natively from NES reference data." Cave is
exactly a visual sequence. Path C punts to Phase 12 with a doubled merge
cost and continued substrate rot (`project_midi_fs_integration`).

Drain has VALUE — Gate 1 verified MATCH proves it as oracle. But oracle
!= runtime. Keep `src/game/cave/cave_runtime.c` as `src/oracle/cave/`
read-only reference, port behavior natively per `project_active_scope_roomrom`
which already names RoomRom the active scaffold.

## 2. Step-by-step plan

1. **Commit current state** (`feedback_commit_first`).
2. **Worktree check** (`feedback_check_worktree_first`) — confirm
   roomrom-s1 worktree state, rebase if drift.
3. **C1**: `git mv src/game -> src/oracle` (rename drain to oracle role).
   Update `build.bat` to compile oracle/ as reference-only library or
   exclude from default build behind `-DORACLE_REF=0`.
4. **C2**: `git mv RoomRom/src/* src/game/`, `git mv RoomRom/data/*
   data/roomrom/`, `git mv RoomRom/tools/* tools/roomrom/`. Delete
   RoomRom/ root.
5. **C3**: Update build.bat — drop `-ffixed-a4` from new src/game/ object
   list, keep it ONLY for src/oracle/ if we still link it. Add
   `-DDEBUG_BOOT=1` path that jumps src/game/ entry skipping
   intro/title/FS (sidesteps `project_title_story_crash`).
6. **C4**: Wire `src/state/` typed structs as the canonical RAM layout
   for src/game/ (substrate already landed this session).
7. **C5**: Port `cavert_init_cave + update_cave_person + draw_*` natively
   from oracle reference using `feedback_check_dont_guess` + NES Z_01.asm.
   Verify via `/spritefix` byte-match against NES capture.
8. **C6**: Build, /bizhawkScript probe, screenshot proves cave room
   renders.

## 3. Top 3 risks + mitigation

- **R1 Lost drain coverage of 433 funcs**: Mitigation = oracle/ stays
  buildable as separate ELF for diff testing. Parity oracle harness from
  commit b476a2a5 is exactly this pattern.
- **R2 Debug-boot diverges from real boot**: Mitigation = scheduled
  Phase 11 task to fix `project_title_story_crash` natively (full
  rewrite per `feedback_full_native_rewrite`); debug-boot is bridge not
  destination.
- **R3 src/state/ struct layout mismatch with NES RAM offsets**:
  Mitigation = `feedback_check_dont_guess` — dump $FF0000-$FF07FF live,
  verify struct offsets match NES $0000-$07FF byte-for-byte before
  cutover.

## 4. Reconcile w/ Debate 005 Rule D1 (drain-first)

D1 says drain BEFORE writing parallel native code. A doesn't violate it —
drain is DONE for cave (393 LOC + Gate 1 MATCH). Oracle/ preserves the
drain artifact. Future subsystems still drain-first INTO oracle/, then
port natively into src/game/. Rule survives, role splits: oracle =
research, game = ship.

## 5. Reconcile w/ feedback_full_native_rewrite

Direct match. Drain is patched transpiled code by definition. Memory says
rewrite natively. A executes that. B betrays it.

## 6. Phase 12 gate

**SIMPLIFIES MASSIVELY.** Phase 12 was "merge two trees with incompatible
substrates." After A, Phase 12 becomes "delete oracle/ once all
subsystems ported." One-line gate: `find src/oracle -name '*.c' | wc -l
== 0`.

## 7. RoomRom fast-iteration value

**PRESERVE.** No nes_ram, no A4, no shims = fast iteration is structural
not locational. Moving the files into src/game/ keeps the property as
long as build.bat doesn't reapply -ffixed-a4 to them. Tag in build:
`SRCGAME_CFLAGS = $(SGDK_CFLAGS)` (no fixed-a4), `ORACLE_CFLAGS =
$(SGDK_CFLAGS) -ffixed-a4`.

## 8. Time estimate

- First commit (rename + move + build green): **4-6 hours**.
- Cave end-to-end native in src/game/ rendering in BizHawk: **1.5-2
  days** (port + spritefix verify + commit).
- Total Path A: **2-3 days as briefed**, matches.

## 9. Master plan changes

- Rename Phase 12 from "merge" to "oracle retirement."
- Add Phase 0.5: oracle/ split + debug-boot harness.
- Per-subsystem GREEN gate becomes: native impl in src/game/ + byte
  match vs oracle/ on parity oracle harness.
- Drop "port drain into RoomRom" from ever appearing on master plan.

## 10. GREEN/YELLOW/RED autonomous achievability

**GREEN.** Mechanical moves (git mv, build.bat edits, debug-boot flag)
are 100% scriptable. Cave native port is bounded by drained reference +
NES Z_01.asm + Gate 1 evidence already in repo. /chuckle + /spritefix
cover the stuck cases. No external deps, no user gating, no destructive
ops on shared state. Memories `feedback_work_autonomously` +
`feedback_automate_not_ask` explicitly bless this mode.
