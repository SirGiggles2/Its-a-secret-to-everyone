# Sonnet — Round 1 (independent, code-grounded, 19 file reads)

## Recommendation: Unify on Scheme 2 (subpal_routing.h + bg_palette.c). Retire the CHR_EXPANSION _oam_dma block.

### Which scheme is live (Sonnet's trace)
- `CHR_EXPANSION_ENABLED equ 1` (nes_io.asm:37), but claims `_oam_dma` is NOT the live gameplay sprite path.
- Claims gameplay (enemies/bonfire/Link) goes through enemy_render.c:translate_attrs + sprite_render.c → roomrom_spr_subpal_to_pal().
- Bonfire trace: enrt_update_standing_fire (enemy_walker_runtime.c:148) → z01_anim_set_sprite_desc_attrs(2) → attr=2 → translate_attrs → sub_pal=2 → roomrom_spr_subpal_to_pal(2) → **PAL3** (CRAM 48-51).
- Bug claim: cave_palette_apply uploads cave BG to PAL0[8-15] but never reloads PAL3; OW exit set PAL3=fire but cave never calls load_palram_full again. If bonfire still blue post-J1 → render_cram_subrange_upload(48) not firing or CRAM clobbered after. "No additional scheme confusion exists."

### Canonical mapping (Sonnet)
| NES slot | Genesis CRAM | Occupant |
|---|---|---|
| BG sub-pals 0-3 | PAL0[0..15] | 4x pixel-bias BG bank |
| SPR sub-pal 0 | PAL1 | Link, sword, common |
| SPR sub-pal 1 | PAL2 | cloud, bomb, blue FX |
| SPR sub-pal 2 | PAL3 | fire, candle, red/orange |
| SPR sub-pal 3 | PAL2 (clamp) | rare |

Every scene transition calls ONE scene_palette_apply(scene_id) that writes ALL of PAL0-3 from a full 32-byte NES PALRAM buffer. No partial CRAM uploads ever. Cave is not special — same function, its own PALRAM buffer with SPR sub-pal 2 = fire.

### Migration / risk
- nes_io.asm: set CHR_EXPANSION_ENABLED=0, delete dead block 2170-2244 AFTER auditing _oam_dma callers (title/story transpile path may still use it). Risk: killing it removes title/story sprite palette mapping.
- cave_palette.c: replace ad-hoc render_cram_subrange_upload(8,...) with a full cave 32-byte PALRAM buffer → load_palram_full. Kills the partial-upload path.
- subpal_routing.h / enemy_render.c already correct.

### Genesis strength
Per-sprite 2-bit PAL field is independent (no NES 2x2 attribute-block constraint). Write all 4 PALs once per scene, set each sprite's pal-field at draw; never partial-overwrite mid-scene.

## CONFLICT vs Claude R1 / live evidence
Sonnet says bonfire → enemy_render → PAL3 (already scheme 2). Claude's LIVE probe shows the bonfire IS in the NES OAM mirror $8200 as tile $5C/$5E attr=$02 → that means it goes through draw_object→OAM→_oam_dma (scheme 1, PAL0), NOT enemy_render. If true, PAL3=fire can't fix it (bonfire is on PAL0). ROUND 2 must resolve: does the cave bonfire publish via draw_object/OAM/_oam_dma or via enemy_render/sprite_render? The OAM-mirror live read is the tiebreaker.
