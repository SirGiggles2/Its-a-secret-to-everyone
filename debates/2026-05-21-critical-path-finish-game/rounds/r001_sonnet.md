# Sonnet (Pragmatic Implementer) Analysis — Round 1

## What the code actually says

I read the sources. This matters.

`mode_dispatch.c:55` — `case 0x0C: mode_stub(); break; /* Mode C Play variant */`.
Mode $0C IS in the dispatch table. It hits `mode_stub()` — a no-op. Nothing advances
GameMode. That is the park. No mystery. T5.0.1 investigation is already answered:
the mode transition code that should write $0C→$05 (or $0C→$0D Save) was never ported.

`audio_dispatch.c:131` — `gm = nes_ram[0x0012u]`. The dispatcher checks live RAM at
$0012 every tick. If $0C never leaves, `resolve_song` falls into `default: return
s_last_song` — silence. Audio dispatcher is structurally correct; it is *waiting* for
(a) to fire.

`ow_render.c:602` — `roomrom_ow_room_render_publish_play_area_tiles()` exists and is
implemented. The question is whether it is called from the active scene-load path or
just defined. The comment says "required so HandleWarpOW sees cave/stairs tiles". If
(a) unparks GameMode so Mode 5 runs, but this function is not called before the first
collision check, cave entry will still return $00.

## Tier-0 reality check

Everyone agrees (a) is the unblock. I agree too. But the other advisors assume T5.0.1
requires investigation. It does not. The root cause is already in the code: no body
implements the $0C→next-mode transition. Two candidates from NES Z_07.asm:
- `UpdateModeC_*` (Play variant) transitions to $0D on save-trigger, stays $0C
  otherwise, ticks the play sub-state machine. Nobody ported this body.
- The startup path that forces $0C may be `InitMode2Load` setting GameMode=$0C as a
  "waiting-for-room-load" sentinel before handing off. If the handoff never fires,
  we deadlock.

**Probe before code** (Rule Zero): one BizHawk probe watching `nes_ram[0x0012]` over
300 frames on real NES OW room will show which transition moves it off $0C. Then port
that transition. T5.0.1 is a 30-minute probe + 2-hour drain, not a week of
archaeology.

## Adversarial pushback on other orderings

**Gemini (f first):** Wrong. The 14 REPLACE tasks have `regression_matrix_run=None`.
Running (f) before (a) means the matrix exercises Mode $0C park behavior — most of
those 14 tasks involve enemy/collision code that only runs when GameMode=$05 Play. You
get false-green results on tasks that were never exercised. Run (f) AFTER (a), not
before. You are cleaning a house that's still on fire.

**Copilot ((d) before (a)):** T5.0.1 IS the $0C investigation. Treating (d) as
pre-work to (a) adds a handoff seam where there is none. Merge them: (a) subsumes
T5.0.1. T5.0.2 (dmc_last_idx) and T5.0.3 (m_song mirror) are independent and can
parallel-track on a separate worktree.

**Claude-Opus ((f) second, lock baseline before parallelism):** Philosophically
correct but practically expensive. (f) is a full regression run against 14 tasks.
Each task needs a per-scenario oracle. If we block (b)+(c)+(d) behind (f), we add
1-2 weeks of wall-clock waiting on matrix completion. Better: run (f) in parallel
with (b)+(d), since those do not depend on regression results.

## Parallelization map

Main-worktree-only (substrate touches):
- (a) + T5.0.1 — nes_ram state, mode_dispatch.c, possibly src/state/

Parallel worktrees (no substrate):
- WT-1: (b) OW PlayAreaTiles call-site wiring — pure call-site addition in
  scene_load.c or ow_render.c; no substrate path.
- WT-2: T5.0.2 (dmc_last_idx probe) + T5.0.3 (m_song decision) — Lua probes only,
  no C edits until decision made.
- WT-3: (f) regression matrix re-run — read-only oracle run against existing code.

(c) Mode 5 Play port is main-worktree only: it touches mode_dispatch.c (adding the
real body to case 0x05) and will need src/sgdk_adapter/audio_adapter.c for music
handoff. Cannot parallelize with (a).

## Highest hidden blast radius if landed last

(b) OW PlayAreaTiles. The function exists (`ow_render.c:602`) but the call-site may
be missing from scene_load. If we ship (a)+(c) Mode 5 Play, run all L1-L9 parity
probes, and THEN find PlayAreaTiles was never being published, every cave-entry probe
result from L1-L9 testing is invalid. We re-probe everything. That is a 3-session
setback, not a 1-session fix.

## Item to cut

(e) 6.10.11 audio dispatch is already structurally blocked by MIDI-FS per
`project_midi_fs_integration.md`. The audio_dispatch.c code is wired and correct;
the blocker is the native FS rewrite which is a separate project. Cutting 6.10.11
costs nothing for L1-L9 playability — music plays via the existing dispatcher once
(a) fires. 6.10.6 StatusBarTransferBuf is a HUD gap; keep it.

---

MY ORDERING: a → b ∥ d(T5.0.2+T5.0.3) ∥ f → c → e(6.10.6 only)

CUT: (e) 6.10.11 audio dispatch because the MIDI-FS substrate blocker is a
multi-month rewrite orthogonal to quest completion; the existing audio_dispatch.c
is sufficient for OW/UW/cave music once GameMode unparks.
