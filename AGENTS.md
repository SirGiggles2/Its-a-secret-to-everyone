# AGENTS.md — every agent (Astra, Claude, others) starts here

1. **Work queue + handoffs:** `docs/TRACKER.md`. Read it first. Claim a task there before touching code;
   log a handoff there before you stop. It is the only live task list.
2. **Project rules:** `CLAUDE.md` (NES-first capture, drain rules, RoomRom freeze, sole build target `Debug.bat`).
   They bind every agent, not just Claude.
3. **Task definitions + evidence rules:** `docs/plans/2026-09-10-project-completion.md` (P#.# IDs).
4. **Commit per task, never leave work uncommitted.** Prefix commits `[T-###]`.
5. Before claiming "builds": `Debug.bat` on Windows. Without Windows: `python tools/audit/host_link_check.py
   --baseline tools/audit/host_link_baseline.txt` (pre-check only, not a build).
