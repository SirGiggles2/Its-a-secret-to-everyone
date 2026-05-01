# FINAL TRY — Claude operating rules

## Decisions

Don't ask. Always pick the option with:
1. Best long-term outcome
2. Best coding practice
3. Maximal efficiency
4. **NES accuracy** as the spec; Genesis-native as the implementation

Then execute. No multi-choice prompts. No "OK to proceed?". User will
interrupt if wrong — that's faster than gating every step.

## NES accuracy

Behavior, layout, palettes, timing, scroll, sprite priority, RAM offsets,
animation cadence — all should match NES Zelda 1 exactly unless explicitly
told otherwise. When in doubt, dump from the NES ROM (CHR, OAM, NT, PALRAM,
RAM tables) to confirm ground truth before changing anything. See memory:
`feedback_check_dont_guess`, `feedback_long_term_fix`,
`feedback_full_native_rewrite`.

## Worktree rule (HARD)

`git worktree list` BEFORE:
- building any RoomRom ROM
- copying any `RoomRom.md` into the BizHawk dir
- editing any file under `RoomRom/src/`, `RoomRom/data/`, or `RoomRom/tools/`
- claiming what RoomRom code currently does

Main worktree lacks RoomRom S2+ features. Real RoomRom dev lives at
`C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1` (branch
`roomrom-s1`). Build, edit, copy from there. See memory:
`feedback_check_worktree_first`.

## Build / verify

- I build, I launch BizHawk, I screenshot. Never ask user to do those.
- One probe per BizHawk launch — bundle screenshot + plane + SAT + CRAM
  in a single Lua.
- Always commit working state before starting next task.

## Exceptions (these still require user input)

- Destructive ops on shared state (force-push, branch deletion, dropping a
  database, rm -rf outside the repo)
- Anything publishing to GitHub or external services (PR, push, comment)
- Genuinely unrecoverable ambiguity — but try memory + manifests + git log
  + NES ROM dump FIRST
