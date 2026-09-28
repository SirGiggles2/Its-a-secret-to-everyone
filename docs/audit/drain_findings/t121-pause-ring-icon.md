# T-121 — pause ring icon tile identity

**Result: PASS.** The task title had conflated item tiles. The live NES pause icon uses `$46/$47`. T-155 subsequently captured the world ring pickup and found that it also uses `$46/$47`; the extracted item-frame table assigns `$76/$77` to the ladder.

With `InvRing=2` in the same NES/Genesis save card, `tools/lockstep/presets/t121_ring2.json` opened the overworld pause screen and settled for 150 play ticks. The final NES OAM shows the ring at slot 56, x164/y30, tile `$46`, sub-palette 2. Genesis SAT shows the corresponding x164/y23 sprite at tile `$3F7`, PAL3 (the documented seven-pixel crop offset). `src/game/inventory/inventory_render.c` selects atlas index 64 for this pause icon; the current build's atlas base makes that `$3F7`.

`python tools/lockstep/verify_sprites.py builds/reports/lockstep/t121_ring2` reports **4/4 visible sprites exact in pixels and palette, zero wrong/unpaired**, with the ring included. The lockstep preset reports **GATE PASS, KEY 192/192**. NES/Genesis final OAM, CHR, SAT/VRAM, screenshots and diff are in `builds/reports/lockstep/t121_ring2/`. Current ROM is the T-154 Windows build SHA-256 `276a015a9b6f709bd0b6bb2ab616ae4aa512388ac236a5ce4f4f5a2a8b9faf6a`.

Only a stale source comment was corrected. No rendered bytes or gameplay behavior changed, so no rebuild was needed. This is an isolated pause fixture, not evidence of world pickup art or natural ring acquisition.
