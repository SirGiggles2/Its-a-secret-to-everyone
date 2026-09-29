# T-159 — Retire stale OW sprite palette scan from the linked game

- **NES source:** `reference/aldonunez/Z_07.asm:@ChooseTileObjPalette` and `PatchAndCueLevelPalettesTransferAndAdvanceSubmode`.
- **Drained C:** NONE for the palette selector; the promoted palette data is `src/game/world/ow_palette.c`.
- **Coverage:** STALE(the old forced-warp room scan disagrees with natural room entry); the live selector and Link palette check are covered by T-138 for room `$79`.
- **Stance:** REPLACE the obsolete lookup/API with the already-linked source-backed selector in `src/game/world/render/ow_render.c`.

T-138's natural NES entry in room `$79` selected sprite row 7 `$0F/$17/$37/$12` from the rock tile object `$62` and `LevelBlockAttrsB=$83`. The historical `ow_subpal3_table.c` entry instead reads `$00/$0F/$1C/$16`; it cannot be an authority for that room. The scan's forced-warp settle condition differs from natural entry. T-138 already installed the NES dispatch in the active Original room loader and matched 1216/1216 hurt-walk and 1501/1501 hurt-attack Link pixels against live NES PALRAM. This task only removes the unused alternate path.

The scan table and its probe remain in source as historical capture, explicitly labeled stale. The table is no longer in `tools/debug/build_debug.py`'s linked object list. `roomrom_ow_palette_patch_subpal3` was a no-op and `roomrom_ow_palette_get_subpal3_patched` had no consumers; both declarations and definitions are removed. Promoted palette-file comments now point to the active room loader rather than claiming the stale table or an automatically regenerated C file owns runtime row 7. A source search finds no remaining active references to either API or the table outside its archival self-include.

`python tools/probes/check_generated_freshness.py --gen --only bg_palette_blob` refreshed the palette provenance sentinel; the full freshness check passes 9/9. Windows `Debug.bat` passes, including VRAM and link checks. Output SHA-256 remains `a879dc2a463213d5b59a4d4681d41e24dd652a5895be60b59d3bc2736f87cf53`, byte-for-byte the T-138 runtime-verified ROM. No new emulator matrix is needed for the unlink because the ROM bytes are unchanged. As in T-138, the build includes Claude's currently uncommitted T-013 `RoomRom/src/main.c` work; no such hunk is staged in this task.

This does not establish palette parity for every overworld room or every enemy; those broader behaviors remain with the existing palette/enemy tasks.
