# T-155 — world ring pickups

**Result: PASS for both ring grades' art and acquisition state.** The previous `$76/$77` label was false for rings. The live NES item table maps pickup IDs `$12/$13` to ring slot `$0B`, whose frame tile is `$46/$47`; `$76/$77` is ladder slot `$0C`.

## Focused scenario and ownership

`tools/lockstep/presets/t155_ring_pickup.json` and `t155_ring2_pickup.json` load the same empty Q1 save card on NES and Genesis, then stage item object slot 2 at x`$C0`, y`$90`, with pickup ID `$12` or `$13`. This is an isolated item fixture, not connected acquisition. At tick 60 they place Link at the item to exercise pickup. The active draw chain is `src/game/world/draw_dispatch.c:draw_animate_item_object` through `src/game/enemies/enemy_render.c`; the legacy `roomrom_sprites_set_room_item` switch in `src/game/world/render/sprite_render.c` has no caller and is not acceptance evidence.

The user ROM runs in BizHawk 2.11 NesHawk. Genesis runs the T-154 `builds/Debug.md`, SHA-256 `276a015a9b6f709bd0b6bb2ab616ae4aa512388ac236a5ce4f4f5a2a8b9faf6a`, in Genplus-gx. Reports and tick-50 captures: `builds/reports/lockstep/t155_ring_pickup/` and `t155_ring2_pickup/`.

## Live comparison

- Before contact, NES OAM shows the ring at x196/y144, tile `$46`, sub-palette 1. The current Genesis SAT sprite maps to the same 8×16 pixels and palette at the expected seven-pixel vertical crop offset. `verify_sprites.py` on each tick-50 capture reports **4/4 visible sprites exact**, zero wrong or unpaired, for both `$12` and `$13` grades. The first 60 staged ticks have **KEY 60/60** in each case.
- On tick 61 after contact, both systems clear item object slot 2 and set `InvRing` `$0662` to **1** for `$12`, **2** for `$13`. Those values persist through the captured tail. Visibility and pickup-state behavior therefore agree for both distinct grades.
- A separate common pickup-presentation defect appears at tick 61: NES Link Y becomes `$95` (149) while Genesis remains `$90` (144), lasting through the held-item submode. The full post-contact lockstep consequently reports 40 KEY differences in the 260-tick blue-ring capture and 19 in the 80-tick red-ring capture. T-158 owns this five-pixel discrepancy; it does not contradict the ring art or inventory result.

**Stance:** KEEP the active native item draw path. T-157 tracks reconciliation of the uncalled legacy switch and stale atlas item-ID catalog. No production source changed for T-155, so the verified Windows ROM remains the current build.
