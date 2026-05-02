# Debate 003 — SGDK Integration Depth & Guardrails: Synthesis (v2 — post-Round 3)

**Date:** 2026-05-02
**Participants:** Codex (CLI), Gemini (CLI), Sonnet (Agent), Opus (architecture lens)
**Mode:** thorough cross-critique, **3 rounds**, ~400 words/advisor
**Caveman mode:** active

---

## TL;DR

**Final stance: GREEN** (3 of 4 — Sonnet, Opus, Gemini; Codex YELLOW conditional on codification).

Substrate is good (zero `<genesis.h>` leaks, SGDK accidentally pinned at v2.11). All four R3 contention points resolved with measurable triggers, named owners, concrete tooling. Three checker tools + three codified rules + one refactor (`intro_title.c`) + one memory correction (v2.00 → v2.11) + per-directory gate matrix closes the gap. **No redesign required.**

---

## Verified facts (measured before debate)

| Item | Value |
|------|-------|
| SGDK submodule HEAD | `ef9292c03fe33a2f8af3a2589ab856a53dcef35c` |
| SGDK tag | `v2.11` (memory `project_what_if` says v2.00 — **stale**) |
| `<genesis.h>` includes anywhere in `src/` | **0** |
| Raw VDP sites | 4 — adapter ✓, genesis_shell.asm ✓, nes_io.asm ✓, **`src/frontend/intro/intro_title.c` ✗ (LEAK)** |
| Adapter modules | render (12K), audio XGM-wired (1.4K), joy compile-only (3K), sram compile-only (4.6K) |

---

## Panel decisions (10 asks + 4 R3 resolutions)

### 1. Adapter boundary — **HARD RULE** (4-0)
Owned `src/game/` + `src/frontend/` MUST NOT `#include <genesis.h>` and MUST NOT write VDP registers directly. All Genesis hardware access routes through `src/sgdk_adapter/`. Per-directory enforcement matrix in §11.

### 2. SGDK version policy — **PIN SHA + AUDIT DOC** (4-0)
Pin `ef9292c0` (v2.11) in `tools/sgdk_pin.json` (machine) + `docs/sgdk_audit.md` (reasoning). No rolling. Bumps require `--accept-sgdk-bump` flag, regenerated parity baselines, regenerated `Final.md` checksum, ADR entry — all in the same commit. **Memory `project_what_if` v2.00 → v2.11 update.**

### 3. Audio trigger formula — **2-of-N within 90-day window** (Codex+Opus formulation; 4-0 after R3)
Migrate audio subsystem (or escalate to ADR) when ANY 2 of the following fire within a rolling 90-day window:

| Signal | Threshold | Tool / cadence |
|--------|-----------|----------------|
| `audio_tick` CPU | > 10% of frame budget | `tools/cycle_envelope.py` against regression matrix; nightly + every audio commit |
| Parity-oracle song failure | survives 1 full debug cycle | `tools/parity_oracle_diff.py`; nightly CI |
| Driver footprint | > 8 KB `.bss + .data` | `tools/check_audio_footprint.py` from `builds/Title.lst` symbol map; weekly |
| Unfixable parity bugs | ≥ 3 issues with `audio-parity` label, open >30d, accumulated in 90d | manual sweep on the 1st of each month |

Custom driver remains the default until trigger fires. Migration is an ADR-gated one-way door, not an automatic flip. Gemini's "frozen legacy + new=XGM2" rejected by 3-of-4 (Codex/Sonnet/Opus) — bifurcates audio runtime, doubles surface area to keep NES-accurate. Opus's r2 single-signal proposal withdrawn by Opus in r3.

### 4. Phase 15 hand-rolled VDP — **HYBRID, ≥15% THRESHOLD** (4-0)
Default = SGDK API. Hand-rolled VDP outside boot/shim/adapter requires ALL of: profiled hot path, ≥15% measured cycle/frame or bandwidth improvement, inline citation of the SGDK call replaced, entry in `docs/handrolled_vdp.md`, adapter test coverage.

### 5. Phase 12 promotion gate — **BOTH GREPS** (4-0)
- `<genesis.h>` (and `<sprite.h>`, `<vdp.h>`, `<dma.h>`, `<sound/xgm.h>`, `<sound/xgm2.h>`) include grep
- raw VDP literal grep (`$C00000`, `0xC00000`, `0x00C00000`, `VDP_DATA_PORT`, `VDP_CTRL_PORT`, `VDP_DATA`, `VDP_CTRL`)

`intro_title.c` is the canary: zero `<genesis.h>` includes but raw `$C00000` writes — include-only gate would have passed it falsely.

### 6. Phase 17 reproducibility — **YES, RECORD + ENFORCE** (4-0)
`MANIFEST.sha256` gains `SGDK_COMMIT=ef9292c...` line. `build.bat` reads `git -C sgdk rev-parse HEAD`, hard-fails on drift. Bumps require `--accept-sgdk-bump` flag and same-commit baseline regen.

### 7. Fork policy — **OWNER-DECIDED, NARROW CRITERIA** (3-1, Gemini softened)
- **WHO decides:** *project owner only*. Solo+LLM team cannot afford ADR-by-committee for supply-chain commitments. Any contributor may *propose* via ADR draft; owner ratifies. Gemini's "ADR vote + LLM consensus" rejected — single point of accountability beats LLM groupthink for forks-as-permanent-debt.
- **QUALIFIES as fork-worthy:** ANY of:
  1. Security CVE with no upstream patch in 14 days
  2. Parity blocker that fails the parity oracle, upstream PR rejected/stalled >30 days
  3. Reproducibility break (toolchain non-determinism) upstream refuses to fix
  4. Build-breaking SGDK bug blocking a milestone gate, upstream PR open >14 days with no maintainer response
  - Patch must be **<200 LOC** AND **touch no SGDK public ABI**. Anything bigger = wrong dependency, escalate not fork.
  - **Performance alone is NOT fork-worthy.** Hand-roll behind the adapter (see Rule SGDK-3) instead.
- **DOWNGRADE path:** fork lives at `vendor/sgdk-fork/` with a `PATCHES/*.patch` directory rebased on the pinned upstream SHA. Every release attempts clean `git am` against the latest upstream tag. First clean apply auto-opens a PR to drop the fork, abandon within one release cycle, ADR records the un-fork. No silent perma-forks.

### 8. Per-directory gate scope (Opus's matrix — 4-0 after refinement)

| Directory / file | `<genesis.h>` check | Raw-VDP check | Rationale |
|------------------|---------------------|---------------|-----------|
| `src/sgdk_adapter/` | WHITELIST | WHITELIST | The adapter itself |
| `src/genesis_shell.asm` | WHITELIST | WHITELIST | Boot |
| `src/nes_io.asm` | WHITELIST | WHITELIST | NES I/O shim |
| `src/c_shims.asm` | WHITELIST | WHITELIST | Boot/IO/hot per north star |
| `src/audio_driver.asm` | WHITELIST | WHITELIST | Audio spec carrier |
| `src/zelda_translated/` | WHITELIST | **ENFORCE** | Transpiler output is not owned, but it must NOT invent raw VDP writes; gate the transpiler if it emits VDP |
| `src/gen/` | WHITELIST | WHITELIST | Passive generated data per `project_best_practices` (gate the *generator* in `tools/`) |
| `src/game/` | **ENFORCE** | **ENFORCE** | Owned game code |
| `src/frontend/` | **ENFORCE** | **ENFORCE** | Owned frontend code |

Gemini's "HARD GATE on zelda_translated/gen" rejected — transpiler emits mechanically; forcing adapter calls in transpiled output either (a) requires transpiler rewrite (massive scope creep, breaks determinism) or (b) hand-edits generated files (violates "gen/ passive" north star). Gate the *generator*, not the output.

### 9. Adapter signature style — **OPTION C (HYBRID)** (3-1, Gemini's pure-A outvoted)

| Subsystem | Signature style | Example |
|-----------|-----------------|---------|
| Audio (APU regs) | NES-semantic | `audio_write_apu_reg(reg, val)` |
| Input (joypad latch) | NES-semantic | `joy_read_nes_latch()` |
| OAM / sprite slots | NES-semantic | `oam_write_nes(slot, y, tile, attr, x)` |
| Palette (NES color indices) | NES-semantic | `palram_write(idx, nes_color)` |
| Sprite engine (Genesis-native) | Thin SGDK wrapper | `render_sprite(x, y, tile, attr)` → `SPR_addSprite` |
| DMA queue | Thin SGDK wrapper | `dma_queue_tiles(src, dst, len)` |
| Tile cache | Thin SGDK wrapper | adapter forwards to SGDK tile API |
| Scroll | Thin SGDK wrapper | `scroll_set(plane, x, y)` |

Per Prime Directive: NES accuracy is spec → NES-semantic primitives where parity is the contract. Genesis-native is impl → thin wrappers where SGDK already nails it. LLM-friendly is the tiebreaker — pure-A (NES-semantic everywhere) over-abstracts Genesis-native paths and burns LLM-debug clarity for swappability we'll never exercise; pure-B (thin everywhere) leaks SGDK semantics into game code and defeats the boundary's purpose.

### 10. Final stance — **GREEN** (3 of 4)
Sonnet, Opus, Gemini stamp GREEN. Codex stamps YELLOW conditional on these criteria being written into gates/ADR/allowlists — i.e., GREEN-once-codified. Substrate is clean, plan is now fully specified.

---

## Copy-pasteable rule additions

**Master Plan / Execution Rules — append:**

> **Rule SGDK-1 (Adapter Boundary).** Code under `src/game/` and `src/frontend/` MUST NOT `#include <genesis.h>` (or any SGDK public header) and MUST NOT write Genesis hardware registers directly. All Genesis hardware access routes through `src/sgdk_adapter/`. Per-directory whitelist defined in `tools/check_adapter_boundary.py`. CI fails on violation.
>
> **Rule SGDK-2 (Version Pin).** SGDK submodule SHA is pinned in `tools/sgdk_pin.json` and recorded in `MANIFEST.sha256` (`SGDK_COMMIT=...`). The reasoning lives in `docs/sgdk_audit.md`. `build.bat` hard-fails when submodule HEAD ≠ pinned SHA. Bumps require: (a) `--accept-sgdk-bump` flag, (b) updated audit doc, (c) regenerated parity oracle baselines, (d) regenerated `Final.md` checksum — all in one commit.
>
> **Rule SGDK-3 (Hand-Rolled VDP).** Default to SGDK API. Raw VDP register writes outside boot/shim/adapter require: profiled hot path, ≥15% measured cycle/frame or bandwidth improvement, inline citation of the SGDK call replaced, entry in `docs/handrolled_vdp.md`, adapter unit-test coverage.
>
> **Rule SGDK-4 (Audio Migration Trigger).** Custom driver is default. XGM2 migration of any audio subsystem (or whole-driver flip) requires ADR approval triggered by ANY 2 of the following within a rolling 90-day window: (a) `audio_tick` >10% frame budget, (b) parity-oracle song failure surviving 1 debug cycle, (c) driver footprint >8KB, (d) ≥3 unfixable `audio-parity` issues open >30d. Documented in `docs/audio_migration_trigger.md`.
>
> **Rule SGDK-5 (Fork Policy).** Project owner is the sole decision-maker for forking SGDK. Qualifying conditions: security CVE (no upstream patch 14d), parity blocker (upstream rejected/stalled 30d), reproducibility break (upstream refuses fix), build-breaker (no upstream response 14d). Patch must be <200 LOC and touch no SGDK public ABI. Performance alone is not fork-worthy — hand-roll behind adapter under SGDK-3 instead. Fork lives at `vendor/sgdk-fork/` with `PATCHES/` directory; every release attempts clean rebase against upstream and auto-PRs un-fork on success.

**Roadmap / Development Rules — append:**

> Genesis hardware is accessed through `src/sgdk_adapter/` only. SGDK is a vendored runtime dependency at SHA `ef9292c0` (v2.11), pinned. Adapter signatures are hybrid: NES-semantic primitives (audio APU regs, OAM, palette, joypad latch) where NES parity is spec; thin SGDK wrappers (sprite engine, DMA queue, scroll, tile cache) where Genesis-native is impl. Audio defaults to in-tree custom driver per Rule SGDK-4. Phase 12 promotion checks both `<genesis.h>` includes and raw VDP literals (per-directory matrix). Phase 17 reproducibility builds refuse SGDK SHA drift.

---

## Tooling — three checker scripts + audio probes

| Script | Purpose |
|--------|---------|
| `tools/check_adapter_boundary.py` | Grep `src/game/`, `src/frontend/` for `#include <genesis.h>` (and other SGDK headers). Per-directory matrix in §8. Exit 1 on hit. |
| `tools/check_raw_vdp.py` | Grep for VDP literals: `$C00000`, `0xC00000`, `0x00C00000`, `VDP_DATA_PORT`, `VDP_CTRL_PORT`, `VDP_DATA`, `VDP_CTRL`. Per-directory matrix in §8. **Catches `intro_title.c` today.** |
| `tools/check_sgdk_pin.py` | Read pinned SHA from `tools/sgdk_pin.json`, compare to `git -C sgdk rev-parse HEAD`. Verify `MANIFEST.sha256` has matching `SGDK_COMMIT=` line. Exit 1 on drift unless `--accept-sgdk-bump` is set. |
| `tools/cycle_envelope.py` | Audio: PC-sample `audio_tick` per frame against regression matrix; emit % of frame budget. Nightly CI. |
| `tools/parity_oracle_diff.py` | Audio: run parity matrix (overworld, dungeon, item-get, death, intro, item-scroll); diff vs golden. |
| `tools/check_audio_footprint.py` | Audio: parse `builds/Title.lst` symbol map; sum driver `.bss + .data` bytes; gate at 8KB. Weekly. |

All three boundary checkers wired into `build.bat` pre-link, Phase 12 promotion gate, and Phase 17 reproducibility gate.

---

## Recommended execution order

1. Refactor `src/frontend/intro/intro_title.c` raw `$C00000` writes through `src/sgdk_adapter/render_adapter.c` API. Build + smoke-test.
2. Write `tools/sgdk_pin.json` (SHA `ef9292c0`, tag `v2.11`).
3. Write `tools/check_adapter_boundary.py`, `tools/check_raw_vdp.py`, `tools/check_sgdk_pin.py` with the per-directory matrix from §8. Run locally — all three should pass after step 1.
4. Wire all three checkers into `build.bat` (pre-link).
5. Add `SGDK_COMMIT=ef9292c...` line to `MANIFEST.sha256`.
6. Write `docs/sgdk_audit.md` (SHA + tag + date + why + tested + drift policy).
7. Write `docs/handrolled_vdp.md` (empty allowlist; gate doc).
8. Write `docs/audio_migration_trigger.md` (2-of-N within 90d criteria).
9. Append Rules SGDK-1..5 to master plan Execution Rules.
10. Append Genesis-hardware paragraph to roadmap Development Rules.
11. Update memory `project_what_if`: v2.00 → v2.11; reference `docs/sgdk_audit.md`.
12. Commit working state per CLAUDE.md "always commit first".

---

## Top 5 ranked plan changes (panel-merged, R3-final)

| # | Change | Impact | Risk |
|---|--------|--------|------|
| 1 | **Refactor `intro_title.c`** raw VDP → adapter, BEFORE any gate is enabled. Step 0. | High | Low |
| 2 | **Pin SGDK SHA** in `tools/sgdk_pin.json` + `MANIFEST.sha256`, write `docs/sgdk_audit.md`, wire `tools/check_sgdk_pin.py` into `build.bat`. Closes Phase 17 hole. | High | Near-zero |
| 3 | **Three boundary-checker scripts** wired to `build.bat` + Phase 12 gate, with the per-directory whitelist matrix from §8. | High | Low |
| 4 | **Codify Rules SGDK-1..5** in master plan + roadmap, including audio migration trigger (Rule SGDK-4) and fork policy (Rule SGDK-5). | Medium | Zero |
| 5 | **Update memory `project_what_if` v2.00 → v2.11** + add reference to `docs/sgdk_audit.md`. | Low | Zero |

---

## Round summary

- **Round 1:** independent answers; all 4 = YELLOW; convergence on hard boundary, SHA pin, both-greps, `intro_title.c` canary.
- **Round 2:** cross-critique; 4-0 on `intro_title.c`-before-lock-in, both-greps, v2.11 update; 15% VDP threshold settled; pin location settled (machine + manifest + audit doc).
- **Round 3:** four contention points resolved — audio trigger = 2-of-N/90d window; fork policy = owner-decides/narrow criteria/auto-rebase; gate scope = per-directory matrix (transpiled allowed `<genesis.h>` whitelist but raw-VDP enforced); adapter signature = hybrid (NES-semantic for parity, thin for Genesis-native). 3 GREEN + 1 YELLOW-conditional.

## Cost / artifacts

- 4 advisors × 3 rounds = 12 advisor outputs (~30KB)
- Round files in `debates/003-sgdk-integration-depth/round{1,2,3}/{codex,gemini,sonnet,opus}.md`
- Synthesis: this file
