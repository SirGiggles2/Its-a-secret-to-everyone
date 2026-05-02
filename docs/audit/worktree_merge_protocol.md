# Worktree Merge Protocol

**Status:** Canonical — required before Phase 12  
**Memory rule:** `feedback_check_worktree_first`  
**Master plan ref:** Task 0.6 (2026-05-02-title-roomrom-full-port-master-plan.md)

---

## Purpose

RoomRom dev lives in the `roomrom-s1` branch, checked out at
`C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`.
The main worktree (`main` branch) lacks RoomRom S2+ features.

Without a written protocol, Phase 12 promotion risks silently merging stale
main-branch RoomRom code instead of the actual working worktree state.
This document is the single authoritative source for how changes flow
between the two worktrees.

The hard memory rule `feedback_check_worktree_first` states: **always run
`git worktree list` before building, editing, or copying any RoomRom file.**
This document is the implementation of that rule.

---

## Worktree Map

| Role       | Path                                                                 | Branch       |
|------------|----------------------------------------------------------------------|--------------|
| Main       | `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY`                  | `main`       |
| RoomRom    | `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`       | `roomrom-s1` |

Verify at any time:

```
git worktree list
```

---

## Step 0: Always Run This First

Before any RoomRom edit, build, or file copy, run:

```
git worktree list
```

Confirm the RoomRom worktree path and branch before proceeding.
If the worktree is missing, do not attempt to edit RoomRom files from the
main worktree. Re-add the worktree:

```
git worktree add "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1" roomrom-s1
```

---

## Canonical Promotion Sequence: RoomRom → main → src/game/

This is the only approved path for promoting RoomRom changes into main.

```
# 1. Confirm both worktrees are registered
git worktree list

# 2. Enter the RoomRom worktree
cd "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1"

# 3. Confirm RoomRom worktree is clean
git status --porcelain

# 4. Build RoomRom in its own worktree — must pass
cmd.exe /c ".\RoomRom\build.bat"

# 5. Rebase roomrom-s1 clean on main
git fetch origin main
git rebase origin/main

# 6. Confirm rebase succeeded with no conflicts
git log --oneline origin/main..HEAD

# 7. Switch to main worktree
cd "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY"

# 8. Confirm main worktree is clean
git status --porcelain

# 9. Merge roomrom-s1 into main (fast-forward only; reject diverged merges)
git merge --ff-only roomrom-s1

# 10. Build in main worktree — must pass
cmd.exe /c ".\RoomRom\build.bat"

# 11. If build passes, promote RoomRom outputs into src/game/ as needed
#     (copy only files that changed; do not bulk-overwrite)

# 12. Commit promotion
git add -p
git commit -m "feat: promote RoomRom <feature> to src/game/"
```

---

## Rebase Rule

`roomrom-s1` **must rebase clean on `main`** before any promotion.

- No merge commits from roomrom-s1 → main are permitted.
- If `git rebase origin/main` produces conflicts, resolve them in the RoomRom
  worktree before promotion. Never resolve rebase conflicts in the main
  worktree.
- After rebase, run `RoomRom/build.bat` again from the RoomRom worktree to
  confirm the rebased state still builds.

---

## Build Rule

`RoomRom/build.bat` **must pass in BOTH worktrees** before any promotion is
considered complete.

| Worktree | Command                              | Must Pass |
|----------|--------------------------------------|-----------|
| RoomRom  | `cmd.exe /c ".\RoomRom\build.bat"`   | YES       |
| Main     | `cmd.exe /c ".\RoomRom\build.bat"`   | YES       |

A green build in RoomRom but a red build in main means the promotion is
broken. Do not commit the promotion until both are green.

---

## Cherry-Pick Fallback (Hot-Fix Promotions)

For urgent single-commit fixes that do not warrant a full promotion cycle:

```
# 1. In the RoomRom worktree, identify the commit SHA
cd "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1"
git log --oneline -10

# 2. In the main worktree, cherry-pick that commit
cd "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY"
git cherry-pick <sha>

# 3. Build in main worktree — must pass
cmd.exe /c ".\RoomRom\build.bat"

# 4. If build fails, drop the cherry-pick and use the full promotion sequence
git cherry-pick --abort
```

Cherry-pick fallback is for hot fixes only. The full promotion sequence
(rebase + ff-merge) is the default path.

---

## Forbidden Patterns

The following actions are explicitly forbidden:

1. **Editing RoomRom files in the main worktree.**  
   `RoomRom/src/`, `RoomRom/data/`, and `RoomRom/tools/` are owned by the
   `roomrom-s1` branch. Editing them in `main` creates divergence that
   corrupts the next rebase.

2. **Copying generated files cross-worktree without rebuild.**  
   Never copy `RoomRom/out/*` or any build artifact from one worktree to
   another. Always rebuild in the destination worktree after any promotion.

3. **Phase 12 promotion without a clean rebase.**  
   Attempting Phase 12 (final src/game/ integration) before `roomrom-s1`
   has rebased cleanly on `main` is forbidden. The verifier (see below) will
   report red and block this.

4. **Claiming RoomRom state from main worktree.**  
   Do not read `RoomRom/` files from the main worktree and claim that is the
   current RoomRom implementation. The authoritative state is the RoomRom
   worktree.

5. **Skipping `git worktree list`.**  
   Every RoomRom session begins with `git worktree list`. No exceptions.

---

## Running the Verifier

```
python tools/verify_worktree_state.py
```

Exit codes:
- `0` — WORKTREE STATE: GREEN (both worktrees clean, roomrom-s1 up-to-date with main)
- `1` — WORKTREE STATE: RED (reason printed to stdout)

Run the verifier as the first step of any Phase 12 promotion attempt.
Phase 12 cannot start if the verifier exits 1.

---

## Phase 12 Gate

Phase 12 (final RoomRom → src/game/ promotion) **cannot start** until:

1. This file (`docs/audit/worktree_merge_protocol.md`) is committed to main.
2. `tools/verify_worktree_state.py` exists and exits 0.
3. The verifier is run and prints GREEN immediately before Phase 12 work begins.

These conditions are checked in master plan Task 0.6.
