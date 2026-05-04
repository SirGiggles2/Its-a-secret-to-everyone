Warning: True color (24-bit) support not detected. Using a terminal with true color enabled will result in a better visual experience.
Ripgrep is not available. Falling back to GrepTool.
## Debate 009: /primedirective Mega-Skill Design — Round 2 (GEMINI)

### 1. Critique of Codex
*   **Concrete Flaw:** Their `templates/` directory (`tracker.initial.json`) creates a "reset" hazard. An autonomous agent, when faced with a `STALE` tracker or a tool failure, might attempt to overwrite the authoritative `docs/superpowers/` tracker with a blank template to "fix" the error, destroying the project's audit trail.
*   **One thing they got right:** The **"Operating Protocol"** in their SKILL.md body. By framing the skill as a sequence of mandatory tool calls (`run status` -> `if stale run refresh` -> `run guard`), they ensure the agent treats the directive as a mechanical workflow rather than a set of abstract guidelines. This is superior to my R1 "Oracle" description.
*   **The change I will make:** I am adopting their **dedicated script architecture** (`prime_status.py`, `prime_refresh.py`, `prime_guard.py`). Moving logic into Python scripts is more reliable than asking the model to perform complex regex or state-machine logic in its head.

### 2. Critique of Sonnet
*   **Concrete Flaw:** The **"Auto-derived, not hand-maintained"** approach is too fragile for this project's 11-step Phase Close Gate. Relying on `git log` grep to determine phase state is vulnerable to non-standard commit messages or squashed history. We need a persistent JSON "state machine" to track granular progress (e.g., "Step 7 of 11 verified") that isn't captured in git metadata.
*   **One thing they got right:** The **"Abbreviated Trigger Form."** Their one-line status block (`[PD] Phase 2 | RoomRom worktree | ...`) is the perfect solution for maintaining context efficiency. It confirms the guardrails are active without burning thousands of tokens on every load.
*   **The change I will make:** I will adopt their **threshold-trigger system**. The skill will now emit an abbreviated one-line status on the first phase-relevant tool call of a session, reserving the full status block for explicit `/primedirective` calls or phase transitions.

### 3. Critique of Opus
*   **Concrete Flaw:** Their **"Operating Contract"** mandates running `prime_guard.py` *before every action*. This is a prohibitive **"Turn Tax."** In a session requiring dozens of surgical edits, doubling the tool calls for validation is a massive efficiency loss. Enforcement should be "Pre-flight" (at session start) and "Post-flight" (during the Phase Gate), not "In-flight" for every single `replace` call.
*   **One thing they got right:** **"Progressive References."** By moving the 18-phase ladder, hard rules, and target definitions into a `references/` subdirectory, they keep the main SKILL.md lean and ensure only the relevant technical debt is loaded into the prompt context at any given time.
*   **The change I will make:** I will adopt their **`references/` folder structure**. My R1 design was too monolithic; splitting the knowledge base from the behavioral script is a cleaner architectural move.

---

### REVISED GEMINI POSITION (Delta only)

My revised design synthesizes the **Rigor of Codex**, the **Efficiency of Sonnet**, and the **Structure of Opus**.

1.  **State Logic:** Move from "Manual Tracking" to a **Hybrid Derived Cache**. 
    *   The canonical state is derived from `docs/audit/active_scope.md` and `tools/audit/drain_coverage.json`.
    *   This state is cached in `docs/audit/master_plan_tracker.json` to handle the **Phase Close Gate** state machine (which requires persistent booleans for the 11 steps).
2.  **Three-Tool Core:**
    *   `prime_status.py`: Merges `active_scope.md` and the JSON cache to report state.
    *   `prime_refresh.py`: Re-syncs the JSON cache if `active_scope.md` or the Master Plan has changed.
    *   `gatekeeper.py`: A dedicated script for the 11-step Phase Close Gate (replacing the generic `prime_guard.py` for this specific high-stakes task).
3.  **Two-Tier Surfacing:**
    *   **Full:** Emitted on `/primedirective`, first session start, or Phase transition. (~15-20 lines).
    *   **Brief:** Emitted as a one-line prefix on the first phase-relevant tool call (e.g., `[PD: Phase 1.5 | Task 1.5.2 | WT: main]`).
4.  **Optimized Enforcement:** 
    *   Eliminate the "Guard every edit" turn tax. 
    *   Instead, `prime_status.py` performs a **Worktree Lock check** at the start of the session. If the worktree is invalid for the active phase, the agent is blocked *immediately* before starting work.
    *   The 4-line D1 header is validated by the agent itself as a "Core Mandate," with `gatekeeper.py` performing the final audit during the Phase Close Gate.
5.  **Reference Decoupling:** The `SKILL.md` is now purely an operational contract. Detailed Phase and Rule definitions are moved to `.claude/skills/primedirective/references/*.md` and are only read when the agent needs specific context for a task.

This design maximizes **Validation Rigor** without sacrificing **Context Efficiency**, ensuring the Prime Directive remains a hard reality throughout the 18-phase journey.
