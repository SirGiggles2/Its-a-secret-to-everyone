# Known divergences from NES Zelda 1

Deliberate, evidence-backed departures from NES behaviour. Anything in
this file is a divergence someone **decided to accept**, with the NES
citation and the reason recorded.

A divergence that is not in this file is a bug, not a decision.

Rule: a contract test may assert current behaviour that differs from the
NES **only** if it cites an entry here. Otherwise the test must assert
the NES behaviour and stay red until the code matches it.

---

## D-001 — Sword beam palette flash: 3-step, NES is 4-step

**Status:** ACCEPTED (hardware-constrained), 2026-08-04
**Found by:** `tools/debug/test_sword_contract.py::test_beam_palette_flash_cycles_4`,
which had been failing silently since the change landed.

**NES behaviour** — `reference/aldonunez/Z_07.asm:3453`:

```asm
; Set the sprite attributes to (base attribute OR (frame counter AND 3)).
; This makes the shot flash by cycling all the palettes, one each frame.
LDA FrameCounter
AND #$03
ORA RDirectionToWeaponBaseAttribute, Y
```

Four-step cycle across all four NES sprite sub-palettes, one per frame.

**Genesis behaviour** — `src/game/combat/combat_runtime.c:369`:

```c
s_beam_palette_phase = (unsigned char)((s_beam_palette_phase + 1u) % 3u);
```

Three-step cycle across `RENDER_PAL1 + {0,1,2}` = PAL1/PAL2/PAL3.

**Cause:** commit `2e2a54eb` *"Phase B: ITEM bank 3x->1x via per-sprite
OAM pal routing"*. Before it, the beam path rewrote `PAL2[0..3]` from
sub-palette N every frame, which reproduced the NES 4-step cycle exactly.
That was removed so PAL2 could permanently hold sub-palette 1 colours for
bomb and explosion sprites, and to collapse the ITEM atlas from 210 tiles
to 70.

**Why it is accepted rather than fixed:** the Genesis has four CRAM
palettes and PAL0 is BG, leaving three for sprites. A true 4-step cycle
requires per-frame CRAM rewrites — which is what was traded away for the
VRAM budget. Restoring it would re-cost 140 tiles of ITEM atlas and give
PAL2 back to the beam, at the expense of bomb/explosion colours.

**This is NOT hardware-impossible, only hardware-constrained.** The
NES-accurate version existed and worked. If the VRAM budget later frees
up (see `docs/audit/genesis_budget_baseline.md`), this should be
revisited.

**Visible effect:** the sword beam flashes through three colours instead
of four, so its flash period is 3 frames rather than 4.

**Process failure worth noting:** the contract test caught this at the
time and was left red. The change was made and shipped with a failing
test that named the exact NES line it broke. That is how a deliberate
optimisation became an undocumented divergence.
