# RoomRom S7 Fix — Sword Sprite Source (v3)

**Date:** 2026-04-30
**Status:** Draft
**Predecessor:** S7 v2 (commit 868924e4 — "4-direction sword, still wrong")
**Successor (planned):** Horizontal sword slice + sword beam (S7b)

## Problem

S7 v2 uploaded NES tiles `$18-$1B` as the vertical sword and `$82-$85` as
the horizontal sword, copied directly from `common_chr` byte offsets
`tile*32`. In-game both directions render as Link/body fragments and
unrelated background noise.

Root cause: the previous live OAM capture interpreted **NES OAM byte 1**
(an 8x16 sprite *pair* identifier in NES sprite-size mode) as a Genesis
**8x8 tile index** into `common_chr`. NES Zelda runs in 8x16 sprite mode
for gameplay sprites, so OAM byte 1 = `$20` means "render tiles `$20`
(top) and `$21` (bottom) from pattern table 0". `$82` is in pattern
table 1 (`sprites_chr` block), not `common_chr`, so reading
`common_chr[0x82*32]` is unrelated data.

Disasm + CHR inspection (sources: `Anim_ItemFrameTiles`,
`RDirectionToWeaponFrame`, `Anim_WriteSpecificItemSprites`,
`tools/out/common_chr_tiles_full.txt`) say the vertical sword is the 8x16
sprite at OAM tile `$20`, which decomposes to Genesis 8x8 tiles `$20`
and `$21` in `common_chr`. The horizontal sword lives in pattern table 1
at OAM tile `$82` (decomposes to `sprites_chr` tiles, not `common_chr`)
and is out of scope for this fix.

## Goal

1. Vertical sword renders the real Z1 sword sprite when Link presses A
   facing UP or DOWN.
2. Horizontal sword (LEFT/RIGHT) shows nothing — never garbage. Swing
   timing + Link freeze still happen so combat state machine stays
   honest.
3. Headers + comments describe the v1 vertical-only behavior, not the
   stale v2 4-direction claim.
4. Ground truth captured live before patching, written to
   `tools/out/nes_sword_capture.json`, so future horizontal work has a
   verified starting point.

## Approach

Probe → verify → patch. One Lua probe captures NES sword OAM + PPU
pattern bytes during a vertical swing. Compare PPU bytes for tile `$20`
and `$21` to `common_chr` byte slices at the same offsets — if they
match, the vertical-sword source is confirmed and the C patch lands.

If they do not match, fix is paused and the design doc is updated with
the actual vertical-sword tile IDs the probe found.

## Probe — `RoomRom/probe_nes_sword_capture.lua`

Single Lua, runs against `Legend of Zelda, The (USA).nes`.

Steps:

1. Standard `boot_to_overworld()` (reuse pattern from
   `probe_nes_uw_chr_dump.lua`).
2. Force sword in inventory: `w8($0657, $01)` (Inventory_Sword =
   wooden sword) and `w8($0656, $01)` (selected B-item index, harmless
   for sword which is always A-button).
3. Wait for stable OW frame (`GAME_MODE == 0x05`, `GAME_SUB == 0`).
4. Face Link DOWN (already default after FS1 spawn).
5. Schedule `A` press for 1 frame.
6. For 20 frames after the press:
   - Dump full OAM (256 bytes).
   - Read `$00AC + 13` (sword item slot state).
   - Read `$03D0 + 13` (state timer).
   - On the frame where state is 1 and timer == peak (frame 2-3 of the
     extend), record the OAM entries whose tile IDs are NOT in Link's
     known pose tile set. Those are the sword OAM entries.
7. Identify sword tile via OAM: byte 1 of the new sprite. Expected
   `$20`.
8. Dump PPU `$0000-$007F` (top of sprite pattern table 0, covers tiles
   `$00-$03`) — actually dump `$0400-$047F` covering tiles `$20-$23` =
   PPU offset `$20*16 = $0200`. Range to dump: PPU `$0200-$023F` (tiles
   `$20` and `$21`, 32 bytes each in 2-bitplane NES format = 64 bytes).
   For safety dump `$0000-$0FFF` whole bank.
9. Repeat for UP facing: walk Link up one step (or use $0070 to set
   facing directly), press A, capture again.
10. Write JSON output:
    ```json
    {
      "down": { "oam_tile": 32, "x_offset": 4, "y_offset": 16,
                 "oam_attr_byte2": "<hex>" },
      "up":   { "oam_tile": 32, "x_offset": 4, "y_offset": -16,
                 "oam_attr_byte2": "<hex>" },
      "ppu_pattern_table_0": "<hex bytes 0x0000..0x0FFF>"
    }
    ```
    The `oam_attr_byte2` field bit 7 (NES vflip) tells which direction is
    the un-flipped canonical form. Spec body assumes UP is canonical
    (vflip=0); if the probe shows DOWN canonical, swap in the patch.
11. Save to `tools/out/nes_sword_capture.json` and
    `tools/out/nes_sword_ppu0.bin`.

Verification step (offline):

```bash
python -c "
data = open('tools/out/nes_sword_ppu0.bin','rb').read()
# NES 2bpp tile = 16 bytes. Tile $20 starts at offset $20*16 = $200.
nes_tile_20 = data[0x200:0x210]
nes_tile_21 = data[0x210:0x220]
# common_chr is 4bpp Genesis. We can't byte-compare directly, but we can
# confirm tile $20/$21 in common_chr is non-zero in the same pixel pattern
# as the NES bytes (low 2 bits of each Genesis nibble = NES bit 0+1 of the
# corresponding pixel). Render both side-by-side as PNG and eyeball.
"
```

Output goes in commit message of the fix.

## C patch — `RoomRom/src/roomrom_sprites.c`

Replace the `static const unsigned char sword_nes[8] = { ... };` upload
loop with a 2-tile upload:

```c
/* S7 v3: vertical sword only. NES OAM tile $20 (8x16 sprite pair) =
 * Genesis 8x8 tiles $20 + $21 in common_chr. Verified by
 * probe_nes_sword_capture.lua, 2026-04-30. Horizontal sword lives in
 * pattern table 1 (sprites_chr) and is out of scope here. */
{
    unsigned short nes_off = (unsigned short)0x20u * 32u;
    render_chr_upload(
        (unsigned short)((SWORD_VRAM_TILE + 0u) * 32u),
        common_chr + nes_off, 32u);
    nes_off = (unsigned short)0x21u * 32u;
    render_chr_upload(
        (unsigned short)((SWORD_VRAM_TILE + 1u) * 32u),
        common_chr + nes_off, 32u);
}
```

Drop the `SWORD_VRAM_TILE_HORZ`, `SWORD_VRAM_TILE_VERT`, and
`SWORD_VRAM_TILE_COUNT` macros — only one slot is used now. Keep
`SWORD_VRAM_TILE` (still the base for the 2 sword tiles).

Rewrite `roomrom_sprites_set_sword_pose`:

```c
void roomrom_sprites_set_sword_pose(link_face_t face, short x, short y)
{
    unsigned char vflip = 0u;
    switch (face) {
    case LINK_FACE_UP:
        vflip = 0u;  /* common_chr $20/$21 = blade pointing up (canonical) */
        break;
    case LINK_FACE_DOWN:
        vflip = 1u;  /* RDirectionToWeaponBaseAttribute: DOWN = vflipped */
        break;
    case LINK_FACE_LEFT:
    case LINK_FACE_RIGHT:
    default:
        roomrom_sprites_clear_sword();
        return;
    }
    VDP_setSpriteFull(1,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, vflip, 0, SWORD_VRAM_TILE),
                      0);
    VDP_updateSprites(2, DMA);
}
```

Update `roomrom_sprites_spawn_link` and `roomrom_sprites_clear_sword`
to use `SPRITE_SIZE(1, 2)` for slot 1 (was `SPRITE_SIZE(2, 2)`).

NES vflip mapping note: `common_chr` tiles `$20/$21` hold the
blade-pointing-UP sword (canonical). `RDirectionToWeaponBaseAttribute`
sets the vflip bit for DOWN, inverting the tile to point blade-down.
RoomRom matches: UP = no flip, DOWN = vflip. The probe must confirm
the canonical orientation of `$20/$21` matches this assumption — if
the canonical orientation is blade-down instead, the spec swaps which
direction gets the flip and the patch follows.

## C patch — `RoomRom/src/roomrom_combat.c`

Update `compute_sword_pos` for an 8x16 weapon offset from a 16x16 Link:

```c
static void compute_sword_pos(link_face_t face, short link_x, short link_y,
                              short *out_x, short *out_y)
{
    short sx = link_x;
    short sy = link_y;
    switch (face) {
    case LINK_FACE_UP:
        sx = (short)(link_x + 4);
        sy = (short)(link_y - 16);
        break;
    case LINK_FACE_DOWN:
        sx = (short)(link_x + 4);
        sy = (short)(link_y + 16);
        break;
    case LINK_FACE_LEFT:
    case LINK_FACE_RIGHT:
        /* Sword sprite cleared in set_sword_pose; position irrelevant. */
        break;
    }
    *out_x = sx;
    *out_y = sy;
}
```

Combat state machine itself is unchanged — `try_swing` still locks Link
for `EXTEND_FRAMES + RETRACT_FRAMES` regardless of facing, so horizontal
swings still freeze movement and play the swing timing.

## Header cleanup

`roomrom_sprites.h` — replace the v2 sword block comment with:

> S7 v3 combat: sword sprite (slot 1). Vertical only. UP = vflip,
> DOWN = no flip. LEFT/RIGHT clear (horizontal CHR source is in
> sprites_chr pattern table 1, not yet wired). Sword tile data uploaded
> inside `roomrom_sprites_upload_chr` from `common_chr` tiles
> $20 + $21.

`roomrom_combat.h` — replace the v1 reference comment with:

> v3 scope: UP/DOWN sword facings only (vertical sword tiles $20/$21
> in common_chr, verified 2026-04-30). LEFT/RIGHT swings still lock
> Link for the swing window but draw no sword sprite. Horizontal sword
> tiles + sword beam projectile are tracked as S7b follow-up.

## Test plan

1. Build: `RoomRom\build.bat` from the roomrom-s1 worktree.
2. Boot RoomRom in BizHawk. Press A facing DOWN — sword sprite is the
   real Z1 sword, blade pointing down, anchored 16 px below Link.
3. Press A facing UP — same sprite vflipped, anchored 16 px above
   Link.
4. Press A facing LEFT or RIGHT — no sword sprite appears at all.
   Link freezes for the swing window then movement resumes.
5. SAT probe (single Lua, after build): dump OAM slot 1 and verify
   tile == `SWORD_VRAM_TILE`, size `1x2`, palette PAL3, vflip set
   only on DOWN.
6. Memory diff: `git diff --stat` should touch only
   `roomrom_sprites.[ch]`, `roomrom_combat.[ch]`, the new probe Lua,
   and the design doc / spec.

## Risks

| Risk | Mitigation |
|---|---|
| Probe finds vertical tile != `$20` | Pause fix, update spec, re-run probe. Don't patch C until probe confirms. |
| `common_chr` tile `$20` is also used by another sprite (e.g., HUD heart) and the upload accidentally reuses VRAM | Check current `common_chr` consumers via grep. Heart/sword/Link are all in `common_chr`; `SWORD_VRAM_TILE` is its own VRAM slot, not shared with the bulk `common_chr` upload, so no collision. |
| Sword sprite priority over UW door arch | Match Link priority (PAL3, prio=0). Same NES feel: sword arc disappears behind door arch. |
| LEFT/RIGHT clear races set_sword_pose call order | `compute_sword_pos` writes positional state; `set_sword_pose` decides to clear. Single-threaded VDP update path, no race. |

## Out of scope (S7b follow-up)

- Horizontal sword (LEFT/RIGHT) — needs CHR source in `sprites_chr` pattern
  table 1 mapped + uploaded into a new VRAM slot.
- Sword beam projectile — tracked separately.
- Enemy hit detection.
- Sword sound effects.
