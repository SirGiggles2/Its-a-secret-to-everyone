# TRACKER — single source of truth for who is doing what

Read this file first, every session. Everything else (`docs/plans/*`, Prime Directive status,
completion JSON) is history or evidence, not the work queue.

## 60-second protocol (both agents)

1. `git log --oneline -5` and read **Current state** + the last 3 **Handoff log** entries.
2. Pick the top `TODO` task you can do (see **Agents**). Set it `ACTIVE`, put your name in Owner,
   list the files you will touch in Scope. Commit that one-line change: `[T-###] claim`.
3. Work only inside your Scope. Need a file in someone else's Scope? Log it and wait or pick another task.
4. Finish = acceptance met with evidence. Commit code + evidence path + board row + one handoff
   entry together: `[T-###] <what>`. Status `DONE` (or `REVIEW` if the other agent must verify).
5. Stopping mid-task: commit WIP as `[T-###] wip: <state>`, handoff entry says exactly where you stopped.
   **Never end a session with uncommitted work.** (13 days of work sat uncommitted once; a stale
   `.git/index.lock` from 2026-09-14 blocked every commit and nobody noticed.)

Rules: one ACTIVE task per agent. New work found mid-task becomes a new `TODO` row, not scope creep.
Evidence rules, NES-first capture rules and task IDs `P#.#` from `docs/plans/2026-09-10-project-completion.md`
and `CLAUDE.md` still apply. Handoff entries: newest on top, max 5 lines, facts only.

## Agents

| Agent | Runs on | Can | Cannot |
|---|---|---|---|
| **Astra** | Windows host | `Debug.bat`, BizHawk NES+GPGX probes, live captures, play builds | — |
| **Claude (Cowork)** | Linux VM on the same folder via bridge | Code edits, Python generators/extractors, ROM data analysis, host-gcc syntax + symbol check (`tools/audit/host_link_check.py`), git, reviews, tracker upkeep | `Debug.bat` / BizHawk (Windows toolchain) unless given computer use |

Git from the VM: `git -c core.checkStat=minimal -c core.trustctime=false -c core.autocrlf=input …`
(index stat info is Windows-written; without these, status re-hashes every file).

## Current state

- **Branch:** `main` (local; not pushed). `main` = recovery work (Sep 11–24) + merged `feat/cave-entry-transition-parity` (Aug).
  Old main preserved at `codex/recovery-baseline-20260911-074018` (= f513b997).
- **Last verified ROM:** `cfea713e…` (pre-merge, Ganon→Zelda handoff). **Merged tree has NOT been built yet → T-001.**
- **Generated data:** freshness 8/8 OK. UW blob 649 rooms. Room generator reproduces 330/331 original rooms byte-exact; only L9Q1 `$42` (Ganon) differs → T-004.
- **Music:** deferred to last by user direction.

## Board

Status: `TODO` · `ACTIVE` · `BLOCKED` · `REVIEW` · `DONE`. Plan ref = task ID in the 2026-09-10 plan.

### S0 — Consolidate (blocks everything)

| ID | Task | Plan ref | Status | Owner | Scope | Acceptance / evidence |
|---|---|---|---|---|---|---|
| T-001 | Build + boot the merged tree | P0.2 | TODO | Astra | build only | `Debug.bat` clean; regression matrix GREEN 12/12; Ganon→Zelda `reward.lua` passes; Aquamentus consumer passes; File Select→New Game; save survives hard reset (`probe_save_persistence.lua`). Record ROM SHA here. Any failure → new T row, fix before S1 |
| T-002 | Quest 2 installed LevelInfo check (offline) | P0.12 | ACTIVE | Claude | `level_info_install.c`, `room_dispatch.c` (Q2 branch), `tools/extract_rooms.py`, `data/rooms/*`, `dungeons_offsets.h` | Run `level_info_install_uw` logic in Python from `data/rooms/dungeons.c`. Installed `$6B9E/$6BAB/$6BAC/$6BAD/$6BAE` for L1–9 Q2 must equal the retired capture (Q2 start `77 75 79 72 7D 74 7F 79 74`, rot `00 05 0D 06 0A 04 0C 0C 04`, tri `08 20 1B 00 4F 16 2D 1B 07`, sbx `E0 00 C8 10 B0 00 C0 C0 00`, marker `0C 02 0B 0F 0A 08 0A 00 0F`). Mismatch = install bug |
| T-003 | World-flag regions (`$067F` OW, `$06FF` L1–6, `$077F` L7–9) | P7.2 / P5.4 | TODO | Claude → Astra | `level_info_install.c`, `save_game.c`, `save_serializer.c` | Code: new game zeroes all three, SRAM save/load keeps all three. Runtime (Astra): kill Digdogger + Patra, leave, re-enter → no respawn; OW secret still open after a dungeon |
| T-004 | Room generator: Ganon room `$42` | P0.14 | TODO | Claude | `tools/builder/gen_uw_room_tiles.py` | Generator output for L9Q1 `$42` byte-equal to the live capture in `uw_room_blob.c` (240 NT bytes differ today). Then 331/331 → builder no longer needs live captures |
| T-005 | Triforce/pause tint after palette LUT change | P7.1a | TODO | Astra | `tools/extract_misc.py` | Aug CRAM overrides `$17/$36/$37` were dropped for the Sep NES-reference LUT. Byte-compare triforce + L1 pause palette vs NES; fix in generator if wrong |
| T-006 | Retire competing trackers | — | DONE | Claude | `.claude/skills/primedirective`, `docs/superpowers/prime_directive_*` | PD skill reads `docs/TRACKER.md` for next action; its Phase 8 "next action" pointer no longer claims authority |

### S1 — Quest 1 route (the test driver; controller-only; checkpoint with SRAM saves, not savestates)

| ID | Segment | Plan ref | Status | Owner | Acceptance |
|---|---|---|---|---|---|
| T-010 | Boot → file create → OW start | P2.1, P7.4 | TODO | | Recorded input file replays to OW start |
| T-011 | Sword cave → sword → exit | P2.2 | TODO | | Sword owned, HUD updated, correct exit spot |
| T-012 | OW → L1 entrance (combat, room crossings) | P2.3–2.4 | TODO | | Enters L1 with no staging |
| T-013 | L1 full → Aquamentus → heart + triforce → exit | P2.5, P1.1–1.7 | TODO | | Real fight, reward, exit; save/reload once (P2.6) |
| T-014 … T-021 | L2 … L9 (one row each, add when reached) | P8.1–8.2 | TODO | | Entry, key items, boss, reward, exit |
| T-022 | Ganon → Zelda → ending | P6.1, P8.3 | TODO | | Unassisted fight; ending mode + credits (renderer stubs → T-051) |

Each failure inside a segment = new `T-1xx` bug row (owner fixes at the owning function, re-runs that segment only).

### S2 — Breadth not on the route

| ID | Task | Plan ref | Status | Owner |
|---|---|---|---|---|
| T-030 | Enemy families: one natural encounter each, per `docs/audit/enemy_parity/INDEX.md` open rows | P3.3–3.5 | TODO | |
| T-040 | Bosses: Dodongo, Manhandla, Gleeok, Digdogger, Gohma, Patra, Moldorm/Lanmola — one real kill each + variant diffs | P6.2–6.4 | TODO | |
| T-050 | Unwired object dispatch rows: `$2F` pond fairy, `$5E` flute secret, `$61–$68` OW objects | P4 | TODO | |
| T-051 | Ending renderer stubs (sprites, credits, finalize) | P7.4 / P8.3 | TODO | |
| T-052 | Items/secrets table | P4.1–4.3 | TODO | |
| T-053 | Death/continue lifecycle | P7.3 | TODO | |

### S3 — Quest 2 · S4 — Audio (last) · S5 — Release

| ID | Task | Plan ref | Status |
|---|---|---|---|
| T-060 | Q2 connected route (X+Y+Z boot) | P9 | TODO |
| T-070 | Audio: `audio_init` not called on active boot; event wiring before driver changes | P7.5 | TODO (after S1–S3) |
| T-080 | Builder: clean-staging build from user ROM, no live captures, drag-and-drop shell, reproducibility | P10 | TODO |

## Handoff log (newest first)

**2026-09-24 · Claude** — Committed 13 days of uncommitted Sep work (`2dffd36f`), removed stale `.git/index.lock` (2026-09-14).
Merged `feat/cave-entry-transition-parity` (`3586d1e3`): SRAM saves, linked File Select, builder gates, room generator.
Replaced captured tables with ROM LevelInfo reads (offsets `$20/$2D–$30` verified against ROM for Q1). Removed the Aug world-flags
override (it aimed dungeons at OW flags). Generated data regenerated and byte-checked; host-gcc 198/198 syntax-clean, no symbol conflicts.
**Not built on Windows yet — Astra: T-001 first.** Created this tracker, `AGENTS.md`, `tools/audit/host_link_check.py`.
