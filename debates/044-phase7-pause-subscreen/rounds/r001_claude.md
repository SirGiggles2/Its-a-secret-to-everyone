# Claude (Opus) — Round 1 Analysis

## Argument AGAINST plan as written

**The plan optimizes for byte-diff PERFECTION over user value.** User said "exactly right" which translates more to "visually NES-feeling" than "every byte identical." Byte-diff zero across 100+ frames is a research-grade target, not a shipping target.

### Blind Spots

1. **Emulator color pipeline asymmetry.** BizHawk NES core (Nestopia/QuickerNES) outputs RGB via its own NES palette interpretation. BizHawk Genesis core (Genplus/Mike Pavone) outputs RGB via Genesis CRAM quantization. Even with identical logical content, RGB bytes WILL differ. Phase 4 V5 already documented this — quantization noise dominates 10k+ "diff cells" that aren't bugs. PX9 verification gate "diff = 0" is mathematically impossible without color normalization, which is itself a guess.

2. **HUD plane overlap.** Genesis Window plane carries HUD at top 4 rows. NES pause scrolls inventory UNDER the HUD. If Genesis Plane B carries subscreen + slides up under Window, the HUD edge clipping behavior won't match NES PPU (which uses sprite 0 hit + scroll value changes at HBlank to mask).

3. **PX1 NES capture assumes deterministic emulator state.** BizHawk Lua's `joypad.set` + frame advance ≠ deterministic across runs. Tiny timing variations shift the capture frame; "frame N" on one run isn't "frame N" on next. Without TAS-style input file + savestate baseline, captures drift between runs.

### Risks

4. **PX4 PRG extraction is fragile.** SubmenuTransferBufSelectors in Z_05.asm point to data tables. Walking those tables programmatically requires understanding NES MMC1 bank switching (Z1 swaps banks during InitMode_Submenu). My plan handwaved this. Real cost: 6-10 hr just to write the extractor, not 3-4 as written.

5. **PX7 cost grossly underestimated.** Plane priority swap on Genesis without breaking gameplay rendering = subsurface architecture change. PR-2 Option F deployment assumed single-plane gameplay. Touching this = risk of regression across 26 OW + UW + cave scenes. 3-5 hr estimate is fantasy; realistic = 8-15 hr.

### Sequencing errors

6. **PX0 cleanup of enemy_render.c merge conflicts is mis-categorized.** Conflict markers suggest a real unresolved state change — picking "Updated stashed" might revert recent enemy fixes (E0 Phase). Should investigate WHAT each side does before merging, not just delete markers.

7. **Verification (PX9) should come BEFORE implementation (PX4-8).** Build the capture + diff pipeline first. If diff is unreliable, scrap pixel-exact goal entirely.

### Missing tasks

8. **No animation phase sync.** NES has FrameCounter-driven flashing (slot $16/$19/$1A/$1B per Z_05.asm:7869). Genesis FrameCounter may not match NES per-frame. Without sync, cursor flash + item color cycle will visibly differ even with byte-correct CHR.

9. **No save-state checkpointing for capture stability.** Best practice for byte-diff = load identical save-state on both ROMs, then drive same input sequence. Plan doesn't address.

## Simpler alternative

**Phase 7-LITE (4-7 hr):**
- A1: Fix items SubmenuItemXs coords (1 hr) — replaces approximated grid
- A2: Add cursor flash (30 min) — visible polish
- A3: Add CRAM swap on enter (1 hr) — distinguishes subscreen palette from gameplay
- A4: NES capture for ONE frame at active subscreen only (no scroll-frames) (1-2 hr) — single reference image
- A5: Side-by-side PNG comparison via existing png_diff_atlas.py — accept ~80% visual match (2 hr)

Skip: scroll animation port (cosmetic), full PRG tilemap extraction, multi-frame diff classifier.

**Recommendation:** Do NOT proceed with Phase 7 as written. Adopt LITE version. If user still wants 100% byte-exact after seeing 80%-match, then escalate.

Round 2: will respond to Gemini, Codex, Sonnet.
