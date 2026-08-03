# Design — Completion Tracker + System Re-Audit

**Date:** 2026-08-03
**Revision:** v2 — supersedes `9347be98`. Four `/octo:review` passes
(Codex gpt-5.6-sol + Claude) produced 24 raw findings; nine confirmed
defects are fixed here. Two were disqualifying: evidence could be
fabricated without running anything (§4.1), and evidence artifacts could
have imported ROM-derived bytes into the repo (§8.1). Per-run finding
counts were 5/4/11/4 on identical input — a single review pass would have
missed most of this.
**Supersedes:** `docs/superpowers/prime_directive_tracker.json` as the
progress-of-record. The prime-directive tracker stays for phase/gate
bookkeeping and hard-rule enforcement; it stops answering "how done is
the port?"

---

## 1. Why the current tracker must be replaced

`tools/audit/primedirective/prime_refresh.py:139-149`:

```python
for pid in sorted(PHASE_NAMES.keys(), key=float):
    if pid == active_id:
        status = "active"
        seen_active = True
    elif not seen_active:
        status = old.get("status", "complete")   # <-- positional default
    else:
        status = "pending"
```

Phase status is a function of **position relative to the active phase**,
not of evidence. Setting the active phase to 17 marked phases 0–16
`complete` with zero verification. The tracker reported 18/18 phases
complete against a build with no save system, no file select, a 0/18
dungeon harness, and known-wrong dungeon room membership.

**Root requirement for the replacement: status is a pure function of
on-disk evidence. No default may ever be "complete."** Absence of
evidence is RED, always.

---

## 2. Goal (user, 2026-08-03, verbatim)

> "MOSTLY faithful port, runs better cause it's on the genesis, and you
> make it using best practices, then the final product contains nothing
> copywrited. You can drag and drop a rom and it creates the genesis rom."

Five independent gates, each of which can be RED while the others are
GREEN. A system is not 100% until all five are GREEN or justified `N/A`.

| Axis | Question | Bar |
|---|---|---|
| **DATA** | Do the assets/tables match NES? | Byte-exact vs NES capture, after documented normalization. The bar caves (20/20) and Q1 dungeons (171/171) already met. |
| **BEHAVIOR** | Does it act like NES? | Live NES-vs-Genesis state diff inside a **written** tolerance. Tolerance must name each accepted delta and why (hardware bound, RNG phase, color model). Undocumented delta = RED. |
| **PLAYABLE** | Can a player reach and use it? | Exercised by a scripted run that starts at power-on and uses no debug chord, no granted items, no forced RAM pokes. |
| **CODE** | Is it built right? | In the `Debug.md` build; no stub/TODO on a live path; respects SGDK-1 adapter boundary and WT-5; owns its state; has a probe. |
| **LEGAL** | Does it ship clean? | Every byte it needs regenerates from the user's own ROM. Nothing Nintendo-derived is in the release package. |

"Runs better on Genesis" is measured in two places, deliberately. Each
system's PLAYABLE cell carries a frame-budget assertion for **its own**
scenes — no scene it owns may exceed 1/60s, and scenes where the NES
slowed down must not. System 15 (`perf`) owns only what no single system
can assert: whole-run worst-case frame time, cross-emulator behavior, and
real hardware. No system may defer its own budget assertion to `perf`.

---

## 3. Systems (the re-audit units)

Sixteen systems. One audit pass each, one at a time. Derived from the
actual tree (`src/game/*`, `src/frontend/`, `src/state/`,
`tools/builder/`), not invented.

| # | System | Slug | Primary code |
|---|---|---|---|
| 1 | Boot & Frontend | `frontend` | `src/frontend/`, `src/debug/a4_probe_main.c` |
| 2 | Save & Load | `save` | `src/state/save_serializer.c`, `src/sgdk_adapter/sram_*` |
| 3 | Overworld | `overworld` | `src/game/world/`, `data/rooms/overworld.c` |
| 4 | Caves & Secrets | `caves` | `src/game/cave/`, `src/game/world/pushblock.c` |
| 5 | Dungeons | `dungeons` | `src/game/dungeon/`, `data/rooms/dungeons.c` |
| 6 | Link | `link` | `src/game/world/render/sprite_render.c`, player state |
| 7 | Combat | `combat` | `src/game/combat/` |
| 8 | Items & Inventory | `items` | `src/game/items/`, `src/game/inventory/` |
| 9 | Enemies | `enemies` | `src/game/enemies/`, `src/oracle/enemies/` |
| 10 | Bosses | `bosses` | `src/game/enemies/bosses/` |
| 11 | HUD & Pause | `hud` | `src/game/hud/`, `src/game/inventory/inventory_render.c` |
| 12 | Game Modes & Flow | `modes` | `src/game/world/mode_*.c` |
| 13 | Audio | `audio` | `src/game/audio/`, `src/audio_driver.asm`, `data/audio_music/` |
| 14 | Second Quest | `quest2` | cross-cutting; Q2 variants of 3/4/5/9/10 |
| 15 | Performance & Hardware | `perf` | frame budget, cross-emulator, real hardware |
| 16 | Builder & Legal | `builder` | `tools/builder/` |

16 systems × 5 axes = **80 cells**. That number is the denominator for
"100%".

---

## 4. Evidence contract

A cell is GREEN only if the system's audit file declares an evidence
block and every field verifies:

```yaml
# illustrative — <64 hex> stands for a real sha256 digest.
# NOTE: humans do not hand-write this block. The evidence producer emits
# it (see §4.1); the audit file embeds what the tool printed.
- system: dungeons
  axis: DATA
  verdict: GREEN
  artifact: docs/parity/dungeon_status.md
  artifact_sha256: <64 hex>
  command: python tools/parity/cave_golden/run_full_diff.py --uw
  verdict_line: "Total 171/171 PASS"
  captured_at: 2026-05-30T00:00:00Z
  run_signature: <64 hex>          # HMAC over (command, argv, inputs[], stdout)
  manifest_emitted_by: tools/parity/cave_golden/run_full_diff.py
  inputs:                          # tool-emitted, NOT hand-authored
    - path: data/rooms/dungeons.c
      sha256: <64 hex>
    - path: tools/parity/cave_golden/cave_byte_diff.py   # the verifier itself
      sha256: <64 hex>
    - path: tools/parity/cave_golden/probe_nes_dungeon_golden.lua
      sha256: <64 hex>
  rom_identity: <64 hex>           # sha256 of the user's NES ROM used for capture
```

Rules the tool enforces mechanically:

1. **Artifact must exist.** Missing file → RED.
2. **`artifact_sha256` must match the file on disk.** Mismatch → STALE →
   cell drops to RED and names the drift.
3. **Every `inputs[]` hash must match, and `inputs[]` must be
   tool-emitted.** A block whose `manifest_emitted_by` is absent, or whose
   `inputs[]` was hand-edited (detected via `run_signature`), is RED.
   Hand-authored input lists are not trusted — an author who forgets a
   dependency would otherwise mint permanent GREEN. See §4.1.
4. **`verdict_line` must appear verbatim inside the artifact.** Stops
   retyped or paraphrased verdicts (CLAUDE.md "Fail loud").
5. **`command` must have actually run, and `run_signature` must verify.**
   Presence of a command string is not evidence that it executed. See
   §4.1 — a recorded command with no verifying signature is RED.
6. **`N/A` requires a non-empty `reason` AND an entry in the schema's
   `na_allowlist` for that exact `(system, axis)` pair.** Prose alone
   cannot exempt a cell. Adding an allowlist entry is a schema change —
   reviewable in a diff, unlike free text buried in an audit file.
7. **No positional inference, ever.** There is no code path that assigns
   a status based on ordering, phase number, or neighbouring cells.
8. **BEHAVIOR cells additionally require a non-empty `tolerance`
   section** in the system's audit file, naming each accepted delta and
   its cause. A BEHAVIOR block with no tolerance is RED even if every
   other rule passes — otherwise the "documented tolerance" bar in §2 is
   unenforced prose.

Screenshots are never evidence for a verdict (RULE V1). They may be
attached under `triage:` for a RED cell only.

### 4.1 Executed evidence — the producer contract

Rules 3 and 5 are only meaningful if evidence is *generated* rather than
*described*. Every evidence producer (the parity differs, the dungeon
harness, `package_check.py`, the regression matrix) gains a
`--emit-evidence` flag. When passed, the tool:

1. Runs its normal verification.
2. Records the exact argv, every file it read (source, generated asset,
   probe, its own module set, and the ROM's sha256), and its own stdout.
3. Computes `run_signature = HMAC-SHA256(key, canonical(argv, inputs,
   stdout, verdict_line))`, where `key` is a per-repo secret in
   `tools/audit/completion/.evidence_key` (gitignored, generated on first
   use).
4. Prints the finished evidence block.

`collect.py` recomputes the HMAC from the artifact and declared inputs.
Mismatch → RED. A hand-typed block cannot produce a valid signature
without re-running the producer, which is the point.

**This is not a security boundary** — anyone with repo write access holds
the key. It is a *discipline* boundary: it makes fabricating evidence
require deliberate circumvention rather than a moment of optimism, which
is the actual failure mode this design exists to stop.

Inputs are discovered, not declared: producers report reads via an
`opened()` wrapper, so a newly added dependency lands in `inputs[]`
automatically and starts guarding the cell from that run forward.

---

## 5. Components

Four pieces, each with one job.

### 5.1 `tools/audit/completion/schema.json`
JSON Schema for the tracker + the per-system audit front-matter. Single
source of truth for field names. Everything else validates against it.

### 5.2 `tools/audit/completion/collect.py`
Reads `docs/audit/systems/*.md`, parses each evidence block, verifies
every rule in §4, writes `docs/audit/completion_tracker.json`. Pure
function of the filesystem — running it twice with no changes produces
byte-identical output. It **never** writes a verdict that isn't backed
by a passing evidence block.

Byte-identical output requires canonicalization, so the tracker carries
**no wall-clock or environment-derived fields**: keys sorted, systems and
axes in the fixed order of §3, JSON with `separators=(',', ':')` and
`ensure_ascii=False`, LF endings, no trailing newline drift. Provenance
that would otherwise vary per run (`generated_at`, hostname, tool
version) lives in a sibling `completion_tracker.meta.json` that is
excluded from the determinism test. This is a deliberate departure from
`prime_refresh.py`, whose embedded `generated_at` makes its output
un-diffable.

### 5.3 `tools/audit/completion/report.py`
Renders `docs/audit/COMPLETION.md`: the 16×5 matrix, the percentage, the
RED list ordered by blast radius, and the drift list (cells that went RED
because an input hash changed). Read-only.

### 5.4 `docs/audit/systems/<slug>.md`
One per system. Written by the audit pass. Structure:

```markdown
# System audit — <name>
## Scope            (what this system owns; what it explicitly does not)
## Axis verdicts    (the 5 evidence blocks)
## Gap list         (every RED, with the concrete work to close it)
## Tolerance        (BEHAVIOR axis: each accepted delta + why)
```

The gap list is the unit of work. Every item in it must be small enough
to finish in one session — per RULE ND-1, an audit that produces a gap
item nobody can finish is a scoping failure, not a deferral.

---

## 6. The re-audit procedure

Per system, in order, one at a time:

1. **Read the code end-to-end.** Not skim. Drain first, NES asm second
   (RULE D1). List what the system actually owns.
2. **Find or write the probe.** One probe, all domains, full ranges,
   plus decode metadata (RULE V3). Every new `.lua` goes through
   `/octo:review` before it runs (RULE V2).
3. **Capture NES live, capture Genesis live, byte-diff** (RULE ZERO).
4. **Write the five evidence blocks.** Each is GREEN with a real artifact
   or RED with a gap item. There is no third option and no "partial."
5. **Run `collect.py` + `report.py`.** Commit the audit file and the
   regenerated tracker together.
6. **Close the gaps found**, then re-run the pass until all five are
   GREEN or justified `N/A`.

A system is not "audited" when its file exists. It is audited when each
of its five cells is GREEN, or is `N/A` with both a reason and a schema
`na_allowlist` entry (§4 rule 6). This is the same bar the release gate
applies in §7 — the two definitions are deliberately identical, so a
system can never pass packaging while failing to count as audited.

### Audit order

Ordered by what unblocks the most downstream work. These are audit-pass
positions, not the system numbers from §3:

```
builder    — from_scratch_gate defines what "the product" even is;
             until it runs, no other GREEN is publicly provable
dungeons   — per-level room membership is known-wrong; every
             dungeon/boss/quest2 claim above it inherits the error
save       — nothing end-to-end is testable without persistence
frontend   — 6 of 20 game modes are stubs; no real New Game exists
modes      — death / continue / endlevel / wingame / ending
overworld  — 128 rooms, never byte-verified
caves  →  link  →  combat  →  items  →  enemies  →  bosses  →  hud  →  audio
quest2     — cross-cutting; needs dungeons/caves/overworld/enemies/bosses GREEN first
perf       — measured last, against the finished thing
```

---

## 7. Relationship to the existing tooling

Kept, wired in as evidence producers — not rebuilt:

| Existing | Feeds |
|---|---|
| `tools/parity/cave_golden/*` | DATA axis for caves/dungeons/overworld |
| `tools/parity/diff_boss_state.py` | BEHAVIOR axis for bosses |
| `tools/dungeon_harness/run_all.py` | PLAYABLE axis for dungeons + quest2 |
| `tools/run_regression_matrix.py` | CODE axis, all systems |
| `tools/audit/drain_coverage.py` | CODE axis, drain stance |
| `tools/builder/package_check.py` | LEGAL axis, all systems |
| `tools/builder/from_scratch_gate.py` | LEGAL axis for builder |
| `tools/builder/release_gate.py` | orchestrator; gains a completion gate |

`release_gate.py` gains one step: **run `collect.py` itself, in the same
invocation, then refuse to package unless every one of the 80 cells is
GREEN or an allowlisted `N/A`.** It must never read a pre-existing
`completion_tracker.json` — a tracker on disk is a report, not an
authority, and source can change after the last collection. That makes
the tracker load-bearing instead of decorative — the failure mode that
killed the old one. The percentage in `COMPLETION.md` counts `N/A` cells
as satisfied but reports them separately, so "100%" can never hide behind
unexplained exemptions.

**Override.** A hard 80-cell gate with no escape becomes a hostage to CI
flake and long external verifications, so the gate accepts
`--override <cell> --reason <text> --approved-by <name>`. Every override
is written into the release manifest at
`builds/manifests/release-*.json`, printed in the packaging banner, and
counted in `COMPLETION.md` as an override — never as GREEN. Overrides do
not persist: each applies to exactly one packaging run. The gate is
bypassable on the record, which is what keeps it from being bypassed off
the record.

The prime-directive tracker keeps hard-rule enforcement (SGDK-1..5,
WT-1..5, D1, banned names) and loses progress reporting. `prime_status.py`
gains a line pointing at `COMPLETION.md` so the two can't drift into
disagreeing about how done the port is.

---

## 8. Error handling

- **Malformed evidence block** → collect.py exits 1, names file + line.
  No partial tracker is written.
- **Hash drift** → cell RED, listed under "Drift" in the report with the
  changed input path. Not silent, not auto-healed.
- **Missing system file** → all 5 cells RED, gap item auto-generated
  ("audit not yet run").
- **Contradiction** → collect.py exits 1. A contradiction is two evidence
  blocks making *incompatible claims for the same `(system, axis)` pair*.
  One artifact legitimately serving many cells is normal and expected —
  `run_regression_matrix.py` and `package_check.py` are shared producers
  by design (§7), and their single report carries a different
  `verdict_line` per system. Artifact reuse is never itself a
  contradiction.
- **Concurrent runs** → advisory lock, same pattern as `prime_refresh.py`.

## 8.1 Evidence artifacts must never carry ROM-derived bytes

RULE V3 requires probes to capture **full** VRAM / CIRAM / PALRAM / CHR /
RAM ranges. Those captures are Nintendo-derived data. An evidence system
that files them into the repo would import the exact copyright problem
the LEGAL axis exists to prevent — while calling it proof.

Therefore:

1. **An artifact is a verdict document, never a capture.** Artifacts hold
   diff results, counts, verdict lines, and hashes of captures — never
   capture payloads. `docs/parity/dungeon_status.md` is the shape; a
   `.bin` dump is not.
2. **Raw captures live only in `build/` and `tools/parity/out/`**, both
   gitignored, and are referenced by sha256 alone. `collect.py` verifies
   the hash if the file is present locally and treats absence as normal,
   not as drift — captures are reproducible from the user's ROM.
3. **`collect.py` refuses to accept an artifact whose path is outside
   `docs/`,** or which exceeds 1 MB, or which fails
   `package_check.is_banned()`. Any of those → RED with a legal-risk note.
4. **`rom_identity` is a hash, never a path or a copy.** It proves which
   ROM produced a capture without carrying any of it.

This makes the LEGAL axis self-applying: the tracker's own evidence is
subject to the rule the tracker exists to enforce.

## 9. Testing

`collect.py`, `report.py`, and the `release_gate.py` integration get
pytest coverage under `tools/audit/completion/tests/`, consistent with
`tools/gates/` precedent. Cases that must be covered:

**Evidence validation**
- missing artifact → RED
- artifact hash drift → RED + drift entry
- input hash drift → RED + drift entry
- `verdict_line` absent from artifact → RED
- `N/A` without reason → RED
- `N/A` with reason but no `na_allowlist` entry → RED
- BEHAVIOR block with no `tolerance` section → RED
- valid block → GREEN

**Executed-evidence contract (§4.1)**
- hand-authored block with no `run_signature` → RED
- valid block with one byte of `inputs[]` edited → signature fails → RED
- artifact edited after emission → RED

**Legal (§8.1)**
- artifact outside `docs/` → RED + legal note
- artifact > 1 MB → RED
- artifact matching `package_check.is_banned()` → RED

**Collector behavior**
- malformed block → exit 1, no partial tracker written
- missing system file → 5 RED + auto gap item
- same artifact, different `verdict_line`, different `(system, axis)`
  → both GREEN, **not** a contradiction
- same `(system, axis)` claimed twice incompatibly → exit 1
- concurrent runs → advisory lock holds
- two runs, no changes → byte-identical tracker output

**Release gate**
- any cell RED → packaging refused
- any cell missing → packaging refused
- unallowlisted `N/A` → packaging refused
- stale tracker on disk with all-GREEN, but live sources RED → packaging
  refused (proves the gate re-collects rather than trusting the file)
- `--override` → packaging proceeds, override recorded in the manifest and
  counted as override, never GREEN
- all cells GREEN → packaging proceeds

**The load-bearing invariant**
- **no input can ever produce GREEN without a verifying, signature-checked
  evidence block** — the regression test for the bug that motivated this
  design. If this test can be made to pass by any hand-authored file, the
  design has failed.

---

## 10. Out of scope

- Rewriting `prime_refresh.py`'s phase logic. It stops being consulted
  for progress; its positional default is neutralized by removing the
  claim, not by refactoring the ladder.
- Phase 13 four-player mode. Optional feature, not part of "the whole
  game ported."
- Any gameplay fix. This design produces the map and the gate. Closing
  the 80 cells is the work the map orders.
