# OPUS ADVISOR — Round 1 (architecture-first lens)

## 1. Pick: **B (port drain INTO RoomRom)** with explicit Phase-0 prep.

Architecture rationale: RoomRom is the only scaffold whose **dependency graph
is acyclic and SGDK-native** (no A4 pin, no nes_ram global, no transpile
bridge). src/game/ drain is correct *behavior* but its substrate (A4-pinned
nes_ram + z01_/z07_/c_/progrt_ shims + Title.md transpile output) is the
exact substrate the project keeps trying to escape (`feedback_full_native_rewrite`,
`project_active_scope_roomrom`, `project_title_story_crash`).

Path A inverts source-of-truth: it drags RoomRom *back* into the rotting
substrate to chase a frontend (Title.md) that **crashes before reaching
drain anyway**. Path C is what got us here — Phase 12 mass-merge across
two incompatible substrates is a guaranteed drift event.

Path B preserves the **clean dependency root** (RoomRom/SGDK) and treats
drain as **reference behavior** to re-host, not code to relocate. Fits
Prime Directive items 1 (long-term) and 2 (best practice: one substrate,
not two).

## 2. Step-by-step plan.

**Phase B0 — substrate adapter (1 commit)**
- `RoomRom/src/compat/nes_ram.{h,c}`: non-A4 pointer, `static u8 nes_ram[0x800]`, inline accessors.
- `RoomRom/src/compat/shim_decl.h`: typedef-compatible z01_/z07_/c_/progrt_ prototypes.
- build.bat: add `RoomRom/src/compat/` to CFLAGS include path.
- Commit: `roomrom: add non-A4 nes_ram + shim decl substrate`.

**Phase B1 — port cave_runtime.c (the smallest verified-MATCH leaf, 1 commit)**
- Copy `src/game/cave/cave_runtime.c` → `RoomRom/src/game/cave/`.
- Rewrite A4 references to `nes_ram[]` macros.
- Stub upstream callers; wire into existing RoomRom test boot.
- Build, RoomRom debug-boot probe, screenshot.
- Commit: `roomrom: port cave_runtime.c (drain leaf 1/433)`.

**Phase B2 — port leaf-by-family in dependency order**
- Order: cave → static rooms → dynamic objects → enemies → items → UI.
- One commit per family (~7 commits). Each: copy, A4-rewrite, link, probe, screenshot.
- Drain in `src/game/` becomes **reference**: `git mv src/game/ reference/drain_substrate/`.

**Phase B3 — Title.md retire**
- After cave + UW + first dungeon room render in RoomRom, mark Title.md
  `legacy/`. Delete `src/gen/z_01.c` wiring. Drop transpile bridge.
- build.bat: drop whatif.elf target, RoomRom becomes default.

## 3. Top 3 risks.

1. **Hidden A4 dependency** in "verified MATCH" drain (transpile may have
   inlined A4-relative addressing). *Mitigation*: per-leaf grep for A4
   register + nes_ram absolute offsets, port adapter macros first.
2. **Shim graph wider than 4 prefixes** (z01_/z07_/c_/progrt_). *Mitigation*:
   `nm builds/whatif.o | rg '^[A-Z_]+_'` — enumerate ALL undefineds before B0.
3. **RoomRom S2+ features lost via worktree confusion** (`feedback_check_worktree_first`).
   *Mitigation*: HARD — Phase B0 starts in `FINAL TRY-roomrom-s1` worktree,
   not main. Document in CLAUDE.md.

## 4. Reconcile with debate 005 Rule D1 (drain-first).

D1 says "drain before adding new". B respects D1 — drain stays the
behavioral spec. What changes: **drain target is RoomRom, not src/game/**.
Drain-first becomes "drain INTO the surviving substrate."

## 5. Reconcile with feedback_full_native_rewrite.

Perfect alignment. Memory says don't patch transpiled visual sequences;
rewrite native. B does exactly that — drain leaves transpile-substrate,
re-hosts in SGDK-native RoomRom. A violates this memory.

## 6. Phase 12 gate.

**Simplifies** under B: Phase 12 stops being "merge two trees" and becomes
"close the leaf-port checklist." Each B-phase commit IS a Phase-12 micro-gate.

## 7. RoomRom fast-iteration value.

**Preserve and elevate.** Debug-boot bypassing title is the only reason we
catch regressions today (`project_title_story_crash` blocks everything else).
B keeps it as the *default* boot; Title.md becomes opt-in legacy.

## 8. Time estimate.

- B0 commit: 2 hours.
- B1 cave end-to-end (port + probe + screenshot + commit): 4-6 hours.
- Full B2 sweep (7 families): 3-5 sessions.

## 9. Master plan changes.

- Workstream F (drain) retargets to RoomRom.
- Phase 0.4 doc updates: rename "whatif" survivors to "Title (legacy)."
- New Workstream H: substrate-adapter maintenance.
- Retire src/game/ as `reference/`.

## 10. GREEN.

Autonomous achievability is GREEN for B0+B1 (clear leaves, existing
worktree, verified-MATCH source). YELLOW for B2 enemies/items (CHR
extraction blocker `project_chr_extraction_items_blocker`). Prime Directive
item 4 (NES accuracy) is satisfied because drain IS NES behavior — only
substrate changes.
