# RoomRom UW Door Priority — Design

**Date:** 2026-04-30
**Scope:** RoomRom test harness only — `RoomRom/src/uw_room_render_roomrom.c` and the upcoming `roomrom_sprites.c` (S1).
**Supersedes for RoomRom:** `2026-04-30-uw-door-priority-design.md` (which targeted the `whatif.md` transpiled-NES path; not the active dev surface).

## Problem

In RoomRom UW scenes, all BG cells are written with priority bit 15 = 0 (low). Link's sprite (S1) is planned at priority bit = 1 (high). Genesis VDP layer order then puts Link's sprite over every BG pixel, so the door arch never occludes him. NES Zelda 1 feel: Link's head/torso behind door arches at side doorways, feet visible on floor.

## Solution — single global priority flip

Genesis VDP layer order (top to bottom):
1. Sprite high prio
2. Plane A high prio
3. Plane B high prio
4. **Sprite low prio**
5. **Plane A low prio**
6. Plane B low prio
7. Backdrop

If we configure:
- **Door arch tiles** → Plane A **high** prio
- **Walls + floor** → Plane A **low** prio
- **Link sprite** → **low** prio (always)

Then everywhere except over an arch cell: sprite low (4) beats plane A low (5) — Link draws over walls and floor. At arch cells: plane A high (2) beats sprite low (4) — arch covers Link.

Color-0 transparency inside the arch tile (open doorway interior) lets Link show through naturally — no per-row split needed. The NES "head behind, feet on floor" look emerges from the existing CHR pixel pattern, exactly as on real hardware.

This avoids any dynamic priority toggle (no equivalent of NES OAM bit-5 flip) — Link sprite stays low-prio statically. Simpler, fewer moving parts, idiomatic Genesis.

## Arch zone — position-based, not tile-ID

Initial design tried to gate priority on a tile-ID bitmap derived from the
manifest `door_tiles` arrays (themselves a union of `DoorFaceTiles{N,S,E,W}`
in z_05.asm). Empirical probe showed the door_tiles set overlaps the dungeon
primary-squares decoration set (`PrimarySquaresUW` square 1 = tiles
$74-$77, used as both door context AND interior floor decoration), so a
tile-ID gate over-tags ~50% of the room.

Final design uses **blob-grid position**: cells in the outer 2-tile border
(rows 0..1, rows ROOMROM_UW_BLOB_ROWS-2..ROOMROM_UW_BLOB_ROWS-1, cols 0..1,
cols ROOMROM_UW_BLOB_COLS-2..ROOMROM_UW_BLOB_COLS-1) get bit 15. Interior
stays low. This matches where dungeon walls and door arches actually live
in the room layout — every NES Zelda 1 dungeon room has its arches and
walls in the outer border, with the interior reserved for floor and
gameplay objects.

Helper: `static unsigned char uw_pos_is_arch_zone(col, row)` — pure
function, evaluated once per cell during `blit_blob` / `draw_placeholder`.

## Files

- **Edit:** `RoomRom/src/uw_room_render_roomrom.c`
  - Add `static unsigned char uw_pos_is_arch_zone(col, row)` helper.
  - Modify `write_tile_raw` to OR `0x8000` into the tile word when the cell
    is in the arch zone.
- **Edit (when S1 lands):** `RoomRom/src/roomrom_sprites.c`
  - Set `TILE_ATTR_FULL(PAL3, 0 /*priority*/, ...)` instead of `1`.
- **Edit:** `docs/superpowers/specs/2026-04-30-roomrom-s1-sprite-link-design.md`
  - Update line 94 priority from `1` to `0` and reference this spec for why.

## Acceptance

- Build green via `RoomRom/build.bat`.
- Boot RoomRom, **B** to UW, navigate to L1 entry room.
- Visually: door arches render in front of where Link's sprite stands at room
  center (or wherever S1 places him). Walls/floor render behind sprite as
  before.
- Once S1 sprite ships: Link standing at a doorway shows arch covering head/
  torso, feet on floor — full NES feel.
- No regression on OW (which doesn't use door_tiles set).

## Out of Scope

- Per-tile priority for OW renderer (user reports OW unchanged).
- Top/bottom door priority on the legacy `whatif.md` transpiled path
  (separate design, NES does not handle those).
- Dynamic priority toggle on Link (NES bit-5-style). Static low-prio is
  sufficient for RoomRom because no game logic currently depends on Link
  rendering above arches.

## Risk

- An interior decoration tile placed inside the 2-cell border would be
  tagged HP. Inspection of L1 R0x43 dump (the entry-area room) shows the
  border zone is exclusively walls + arches — no interior decor reaches the
  border. If a future room flips a decor block into the border, that cell
  would render in front of a low-prio sprite passing through. Acceptable;
  flag and re-evaluate per-room if seen.
- HUD draws on Plane A rows 0..7 (above ROOMROM_ROOM_FIRST_ROW). The arch
  zone test runs in blob coordinates relative to the play area, so HUD
  cells are not touched.
