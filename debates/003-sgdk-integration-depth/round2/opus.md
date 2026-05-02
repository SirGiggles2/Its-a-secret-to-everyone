# OPUS ADVISOR — Round 2: Architecture-First Cross-Critique

## Convergence (the easy 80%)

All four of us land in the same room: hard adapter boundary, pin SGDK at `ef9292c0` (v2.11), both-greps gate (`<genesis.h>` AND raw `$C00000`), refactor `intro_title.c` BEFORE locking the rule, manifest-recorded SHA with build-time drift check, three checker scripts under `tools/`. Codex, Sonnet, and I all stamp YELLOW; Gemini stamps YELLOW pending the `intro_title.c` fix. This is not a debate over direction — it is a debate over two thresholds and one commitment.

## Divergence 1: Audio (Gemini = XGM2; Codex/Sonnet/Opus = custom + trigger)

Gemini argues XGM2 wins on LLM-training-data surface area, with a CPU>15% escape hatch. From an **architecture lens** that is the wrong axis. The custom driver is the *spec carrier* — frame counter, sweep, length-load, envelope cadence are NES-accuracy invariants that XGM2 cannot express without a translation layer that re-introduces every bug it claims to remove. Migrating audio is a one-way door (parity oracle baselines, MIDI pipeline, F3 audit work all rebase). Sonnet's two-of-three trigger (3 unfixable bugs/90d, >8KB footprint, >10% CPU) is the right *shape* but I refine the threshold downward: **>10% audio_tick CPU OR any parity-oracle song failure that survives one debug cycle.** Reproducibility argument: custom driver is in-tree, deterministic, version-controlled. XGM2 is dependency-coupled — every SGDK bump can shift sample timing. **Hold custom. Document the trigger. Do not prematurely migrate.**

## Divergence 2: VDP hand-roll threshold (Sonnet=15%, Opus r1=20%)

I revise to **Sonnet's 15%**. Rationale: 20% was a gut number; 15% matches the same threshold I'm proposing for audio CPU and gives one consistent "material perf" bar across the codebase. Lower threshold also better honors Prime Directive #6 (LLM accuracy at 2am) — the bar to escape SGDK ergonomics should be *hard to clear*, not comfortable. Add Sonnet's two-AND clauses: inline citation of the SGDK call replaced + entry in `docs/handrolled_vdp.md`. Codex's "boot/shim/measured-hot-path" carve-out is compatible.

## Convergence locks (confirm)

Yes to all three: (a) `intro_title.c` refactor through `render_adapter` lands BEFORE the rule is committed — otherwise we ship a CI gate that fails on day one; (b) both-greps in Phase 12 (Sonnet's "belt + suspenders" framing is correct — include grep is cheap, raw-VDP grep is the real test); (c) v2.11 SHA pin in `tools/sgdk_pin.json` + manifest line + `--accept-sgdk-bump` flag for intentional bumps.

## Architecture lens (supply chain / boundary / reproducibility)

SGDK is **vendored runtime**, not owned code. Three properties matter:
1. **Supply chain:** pinned SHA + audit doc + ADR-on-bump. No rolling. Fork only if upstream rejects a needed patch.
2. **Dependency boundary:** adapter is the *only* import surface. Game code links against NES-semantic primitives, not SGDK types. This makes SGDK swappable in principle (mockable for tests, replaceable if abandoned).
3. **Reproducibility:** Final.md byte-identity requires deterministic toolchain. SGDK SHA is part of the toolchain — manifest must record it, build must refuse drift, bump must regen baselines in the same commit.

## Refined Top 5 plan changes

1. **Pin SGDK SHA + manifest record + drift gate** (Phase 17 hole, near-zero risk).
2. **Three checker scripts wired to `build.bat` + Phase 12** (`check_adapter_boundary.py`, `check_raw_vdp.py`, `check_sgdk_pin.py`).
3. **Refactor `intro_title.c` raw VDP → `render_adapter`** BEFORE rule lock.
4. **Codify SGDK-1/2/3 rules + audio migration trigger (>10% CPU OR parity-oracle survival failure) + 15% VDP hand-roll threshold** in master plan.
5. **Update `project_what_if` memory v2.00 → v2.11 + write SGDK ADR**.

## Final Stance

**YELLOW** — substrate is sound, plan needs codification + one refactor + one memory correction. Three small tools and three rules close the gap. No redesign required.
