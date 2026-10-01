# T-175 — grade-aware pause ring palette (2026-10-01)

- **NES source:** `reference/aldonunez/Z_07.asm:DrawItemInInventory, DrawItemBySlot`; `Z_05.asm:DrawSubmenuItems`.
- **Drained C:** `src/game/world/draw_dispatch.c:draw_item_icon`, side-effect-free item descriptor/color resolution; shared `roomrom_spr_subpal_to_pal`.
- **Coverage:** blue and red ring pause fixtures, item tile/position/transparency/color and RAM continuity. Natural acquisition, menu motion/function and other graded items remain separate acceptance.
- **Stance:** EXTEND existing inventory renderer with existing drain helper; no new palette algorithm.

T-174's blue-ring named consumer passed RAM but failed presentation on ROM `8CA38EB91026E97900F7B8D9CE3DC846818615F48437FB857BDEF871346030C1`. NES OAM slot 56 is x164/y30, tile $46, attribute 1. Genesis used PAL3 at x164/y23, correct art with red-grade colors. Actual CRAM comparison (not only palette-bank numbers) found 37/39 opaque pixels wrong: expected $A22/$E88, actual $22A/$2AE; two white pixels agreed.

`k_inv_slot_to_pal` encoded one captured grade's colors. The ring slot now resolves attributes through existing `draw_item_icon(slot, g_inventory.ring, &attr)`, then shared subpalette routing. This reads authoritative native grade without modifying gameplay/scratch RAM. Red ring retains PAL3; blue ring selects PAL2. A pre-existing unused local renderer helper was renamed `draw_item_icon_8x16` to avoid its name collision with the drained helper.

Windows `Debug.bat` PASS, checksum $34F2, ROM SHA-256 `557C922AE40314550C94AFD113211054BD8D7AF1DCFE646ACDAE1B885F555465`. Existing Claude WIP remains preserved and present in this local build.

- `t121_ring1` and `t121_ring2`: **192/192 GATE PASS each**, existing baselines unchanged.
- `verify_sprites.py`: **4/4 exact each**, zero wrong/unpaired, expected seven-pixel menu crop offset.
- Actual per-opaque-pixel CRAM comparison: **39/39 exact each**; blue NES attr 1 → Genesis PAL2, red attr 2 → PAL3. Tile/transparent geometry unchanged.

Reports: `builds/reports/lockstep/t121_ring1/`, `t121_ring2/`. Prior T-121 red-grade evidence remains valid; its row now includes both grades. No broad dungeon rerun was required for an isolated pause icon palette repair. Full pause acceptance T-165 and other graded inventory icons remain open.
