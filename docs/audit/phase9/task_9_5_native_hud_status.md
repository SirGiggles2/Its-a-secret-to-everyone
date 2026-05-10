# Phase 9 Task 9.5 — Native HUD Status

The 11-bullet master plan task assigns rendering responsibility to
RoomRom (`docs/superpowers/plans/2026-05-02-...master-plan.md` line
1455 — "9.5 HUD rendering → RoomRom"). The 2026-05-09 WT-5 directive
later froze RoomRom against new files / non-trivial edits, so the path
to "Render hearts/rupees/bombs/keys/items/maps/triforce" is now
two-step: (1) lock the format contracts in `src/game/hud/`; (2) port
the VRAM-write side out of `RoomRom/src/roomrom_hud.c` into
`src/game/hud/hud_native_render.{c,h}` once a sanctioned RoomRom
carve-out lands or the freeze lifts.

## Format-side coverage (DONE — `src/game/hud/`)

Drained `hud_format_status_bar_text` (`src/game/hud/hud_dispatch.c`)
fills the 41-byte transfer buffer at RAM(`$0302..$032A`) with NES tile
IDs + 3-byte VRAM headers. The HUD format probe at `$FF7EC0` exercises
the heart-row formatter against hand-traced expected byte sequences.

| Probe artifact | Result |
|---|---|
| `task_9_5_hud_format_probe_report_v1.txt` | passes=8/8 (heart row), bits=$FF, fc=155 |
| `task_9_5_hud_format_probe_report_v2.txt` | passes=15/15 (+ rupee/bomb/key/master-key), mask=$7FFF, fc=154 |
| `task_9_5_hud_format_probe_report_v3.txt` | passes=20/20 (+ anim rupee tick gates 1-5), mask=$FFFFF, fc=154 |

Format coverage matrix:

| Bullet | Format chain | Probe coverage | Render |
|---|---|---|---|
| Render hearts | `hud_format_hearts_in_text_buf` | v1 — 7 heart shapes + degenerate | RoomRom (frozen) |
| Render rupees | `hud_format_decimal_count_byte_in_text_buf(LINK_RUPEES, 27)` | v2 — 0/42/255 | RoomRom (frozen) |
| Render bombs | same path with offset 39 | v2 — 8/99 | RoomRom (frozen) |
| Render keys | conditional master-key dash + same path with offset 33 | v2 — 5 + master-key dash | RoomRom (frozen) |
| Render B/A item | `RoomRom/src/roomrom_hud.c` `s_b_item` token | none — RoomRom-internal | RoomRom (frozen) |
| Render OW map | atlas tile `TILE_GRAY_MAP` block | none — RoomRom-internal | RoomRom (frozen) |
| Render dungeon map | redux automap (`redux_hud_chr.c`) | none — RoomRom-internal | RoomRom (frozen) |
| Render triforce | `roomrom_hud_draw` triforce tile | none — RoomRom-internal | RoomRom (frozen) |
| Add HUD style option | `OPTION_ID_HUD_STYLE` (not yet defined) | n/a | needs option scaffolding |
| Verify static + animated | format probe + screenshot gate | v3 — static (15) + animated rupee tick (5 gates: buf-select / high-bit / odd-frame / credit / debit) | needs render port |

## Render-side blocker

`RoomRom/src/roomrom_hud.c::roomrom_hud_draw` and
`roomrom_hud_refresh_dynamic` own the VRAM nametable writes. Both call
`VDP_setTileMapXY` with explicit col/row computed from NES tile-ID
literals. WT-5 forbids new RoomRom files; existing-file edits are
permitted only for one-line probe call-outs.

The clean port path requires a new file
`src/game/hud/hud_native_render.{c,h}` that:

1. Reads the 41-byte transfer buffer (`TRANSFER_BUF_BYTE(0..40)`).
2. Walks 3-byte VRAM headers (`hi, lo, count`) → NES NT addr → Plane A
   col/row.
3. Writes Plane A nametable cells via `render_set_plane_a_word`.

This is a clean WT-5 adherent path (lives entirely in `src/game/`),
but it duplicates `roomrom_hud_draw` until RoomRom's HUD render is
retired. Both renderers writing the same Plane A cells is
last-writer-wins; acceptable if the native renderer runs after
`roomrom_hud_draw` in the per-frame order.

## Next concrete advance

When sanctioned: build `hud_native_render.{c,h}` (~80 LOC) + extend
HUD format probe with rupee/bomb/key decimal coverage + add a render
verification probe that reads back live Plane A nametable cells via
the existing RoomRom render pipeline. This advances bullets 1-4 to
"render verified". Remaining bullets (item slots, maps, triforce, HUD
style) require additional drain ports of B-item / map / triforce
render logic — separate sub-tasks.
