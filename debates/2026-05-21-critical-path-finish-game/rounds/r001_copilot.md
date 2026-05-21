I'll use the custom instruction framework to analyze this adversarial ordering problem.

● Create blocker dependency graph (sql)
  │
  └ Executed 3 statement(s)

## ORDERING RATIONALE

**Tier-0 Unblock (Q4):** **(a) GameMode $0C unpark**  
Without it, music dispatch fails, FS routing stalls, Mode 5 Play won't engage. Non-negotiable.

**Critical Path to Playable L1–L9×Q1/Q2:**

1. **(d) T5.0 debug** → locate DMC address, verify $0C park root cause. Parallel-safe (no substrate touch). Unblocks (a) with concrete fix.  
2. **(a) Unpark GameMode** → restore music + FS routing + Mode 5 entry. Substrate edit (src/state/); main-only.  
3. **(b) OW PlayAreaTiles** → populate $06A0+ ROM table. Parallel-safe if data-only; unblocks cave-entry oracle verification (T0.1).  
4. **(c) Mode 5 Play port** → collision + game loop. Depends on (a) + (b) gates green. Substrate (src/sgdk_adapter). Main-only.  
5. **(e) Audio dispatch** → Phase 6 audio systems. Deferred post-quest (blocked on MIDI-FS fix outside scope).  
6. **(f) Regression matrix** → re-run after all 14 REPLACE tasks land.

**Q2 — Parallel Execution:**
- **(d)** runs in worktree-A (Lua probe only).  
- **(b)** runs in worktree-B (data ROM table populate).  
- **(a), (c)** land sequentially in main (substrate gate).

**Q3 — Hidden Blast Radius If Last:**  
**(a) GameMode $0C unpark** — if deferred until after Mode 5 Play dev, will force revert + full integration re-sync. *Worst timing.*

**Q5 — Worst-Case Failure Modes:**

| Order Step | Failure | Mitigation |
|---|---|---|
| (d) → (a) | DMC address wrong, $0C remains parked | Bizhawk probe must dump live RAM + NES asm cross-check |
| (a) lands | Breaks collision_get_collidable_tile (music clobbers mode flag) | Oracle trace before gate; diff vs NES trampolines |
| (b) + (c) in parallel | Tiles corrupt VRAM during collision port | Strict ROM offset verification; no data bleeding |
| (f) runs early | False negatives mask real regressions | Run only after all REPLACE tasks in main + (a–c) green |

---

## MY ORDERING:  
**(d) debug $0C** → **(a) unpark GameMode** → **(b) populate OW tiles** → **(c) Mode 5 Play port** → **(f) regression re-run** → **(e) Phase 6 audio** (post-quest).

## CUT: 
**(e) Phase 6 audio dispatch** because audio delivery post-quest (L1–L9 beats music) + MIDI-FS blocker is external. Land with 14xREPLACE + Phase 18 rework.


Changes   +0 -0
Requests  1 Premium (26s)
Tokens    ↑ 52.5k • ↓ 1.9k • 25.6k (cached)
