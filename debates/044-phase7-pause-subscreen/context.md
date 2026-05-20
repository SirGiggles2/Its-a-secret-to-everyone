# Debate: Phase 7 — pixel-EXACT NES pause subscreen plan critique

## Question
Should we proceed with Phase 7 (PX0-PX9) of the master plan as written for getting pixel-EXACT NES Zelda 1 pause inventory subscreen parity on the Genesis port? What are the risks, blind spots, and simpler alternatives?

## Style
Adversarial — 2 rounds. Each participant must challenge weaknesses in the plan.

## Project context
- Genesis port of NES Zelda 1, ROM = builds/Debug.md.
- Phase 6 already shipped a WORKING pause subscreen but diverges from NES:
  - ASCII text labels via hand-written LUT vs NES inline tile_id bytes
  - Approximated item sprite positions vs NES SubmenuItemXs table
  - Row-by-row tilemap replacement scroll vs NES VScroll PPU
  - No CRAM swap, no NES baseline capture
- User explicitly asks for PIXEL-EXACT NES parity — byte-for-byte match.
- Plan estimate: 17-26 hours across 10 tasks (PX0-PX9).

## Plan tasks summary
- PX0: clean enemy_render.c merge conflict markers (blocker)
- PX1: capture NES pause subscreen (43-frame scroll + active + scroll-out)
- PX2: capture Genesis pause subscreen (current state baseline)
- PX3: diff classifier per (frame, region): TM_TILE / TM_ATTR / SPR_POS / SPR_TILE / SPR_PAL / CRAM / SCROLL
- PX4: port SubmenuTransferBufSelectors + tilemap blob from NES PRG (replaces hand-coded text)
- PX5: port SubmenuItemXs + DrawItemInInventory exact coords (16-entry x table + Y per slot range)
- PX6: port cursor exact behavior (tile $1E + 8-frame flash AND #$08, LSR x3, ADC #$01)
- PX7: port VScroll state machine ($EF→$41 over 43 frames, 3 px/frame) — implementation choice: Plane B + priority swap recommended
- PX8: CRAM swap on enter/exit (subscreen-specific palette)
- PX9: pixel-exact verification gate (all diff counts = 0)

## Genesis platform constraints
- SGDK m68k, Plane A currently 64x32 (= 512x256 px) in PR-2 Option F.
- Plane B currently idle during gameplay.
- VSRAM[0]/VSRAM[2] for Plane A / Plane B vscroll.
- Window plane carries HUD.
- 32-row plane wraps at 256 px vertically — doesn't fit 28 gameplay + 28 inventory cleanly.

## Constraints
- Existing inventory subscreen LANDED (Phase 6 P6.1-P6.5+P6.7); functional but not pixel-exact.
- User wants pixel-exact PER USER ("EXACT EXACT pause screen from the NES. and get it exactly right").
- Sole build target = builds/Debug.md.
- Per CLAUDE.md RULE ZERO: capture NES live + Genesis live + byte-diff BEFORE writing any code.

## Plan FULL TEXT
See plan_context.md (2557 lines) — search for "Phase 7" section near end.

## Adversarial debate prompts
Each participant: argue AGAINST the plan as written. Identify:
1. Blind spots (assumptions that may not hold)
2. Risks (estimate uncertainty, dependency chains)
3. Simpler alternatives (pragmatic shortcuts that achieve 80%+ of goal at 30%- effort)
4. Sequencing errors (tasks that should run in different order)
5. Missing tasks (gaps the plan doesn't address)

Then: respond to other participants in round 2.
