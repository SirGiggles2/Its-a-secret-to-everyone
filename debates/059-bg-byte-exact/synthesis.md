# Debate 059 Final Synthesis: BG byte-exact parity

## 5 BG BUGS confirmed by Sonnet R1 code investigation

### BUG 1 (DOMINANT): OW per-room palette table is one row repeated 128×
- **File**: `src/game/world/ow_bg_palram_table.c`
- File header claims "auto-captured live NES BG PALRAM per OW room"
- Reality: all 128 entries are byte-identical `{0x0F, 0x30, 0x00, 0x12, ...}`
- Effect: every OW room shows SAME color palette. NES has per-room variations (dungeon entries = different sub-pal 3 for door framing).
- **Fix effort: 4h** — regenerate table via NES probe, capture PALRAM at each room

### BUG 2: OW tree-top BG priority missing
- `cave_fade_mark_arch_hi_prio` handles cave-descend Link-behind-arch
- No equivalent for OW trees → Link renders IN FRONT of tree canopies
- **Fix effort: 3h** — scan OW BG for tree-top tiles, mark priority

### BUG 3: Animated BG not implemented
- `palette_tick_runtime.c` has framework
- Toggle table EMPTY per its own Phase 2 comment
- Waterfall, lava, candle-fire-reveal don't animate
- **Fix effort: 4h** — populate toggle table + animation phases

### BUG 4: Cave sub-pals 0+1 unverified
- `cave_palette_apply` stamps sub-pals 2+3 only
- Sub-pals 0+1 carry last-OW palette
- May or may not be visually wrong (BG cave uses sub-pals 2+3 dominantly; 0+1 may not be referenced by cave nametable)
- **Verify**: probe cave NT for which sub-pals are used. If 0/1 referenced → bug.
- **Fix effort: 1-2h** depending on verification

### BUG 5: No NT byte-diff probe exists
- $FF7400 raw-tile cache exists (Phase E infra)
- `probe_nes_ow_bg_palram_full_scan.lua` exists (palette probe)
- BUT no `(scene, room_id) → {nt, attr, palram, priority_mask}` golden bundle
- No Genesis-vs-NES NT diff runner
- **Build effort: 8h** — bg_golden bundle + differ

## Codex R1 architectural framing

"BG analog of SPR subpal gap = attribute/palette expansion in data but not applied at plane-entry emission time."

Each BG cell must carry: tile_index + BG_palette_line + flip_h + flip_v + priority. If any is GLOBAL instead of PER-CELL FROM NES STATE → parity drifts.

Risks per Codex:
- CHR bank timing wrong
- Attribute expansion bugs
- Palette patch ordering
- Stale UW room cache keys (must include dark/lit/shutter/pushblock/bomb/item-reveal state)
- Priority bits set per-tileset-tile instead of per-placed-cell
- Animations verified only at frame 0

## Working correctly (Sonnet confirmed)
- UW per-room palette (g_uw_room_palette[636][32], live-captured per room)
- UW door priority (`uw_is_door_tile`)
- OW heap decode + metatile expansion pipeline
- Cave layout tables (k_cave_layout_regular + shortcut)

## Execution plan (20h core + 8h infra = 28h)

### Phase K1 (4h): Regenerate OW per-room palette table
- Write `tools/probes/probe_nes_ow_palette_per_room.lua`: navigate NES Z1 OW, dump $3F00-$3F0F at every room
- Output: 128 × 16-byte rows → `data/rooms/ow_bg_palram_table.bin` (or regenerate the .c)
- Re-run OW visual sweep — expect varied palettes per room

### Phase K2 (3h): OW tree-top BG priority
- Identify NES OW tree-top tile IDs ($XX..$YY)
- After `roomrom_ow_room_render_fill_plane_a`, walk plane for tree-top tiles, set BG_PRIO bit
- Verify Link-behind-tree visually

### Phase K3 (4h): Animated BG tiles
- Populate `palette_tick_runtime.c` toggle table: waterfall (NES Z_06 anim), lava (cellar floors), candle-fire-revealed tile_id swap
- Frame phase per `nes_ram[$0015]` FrameCounter bits

### Phase K4 (1-2h): Cave sub-pals 0+1
- Verify via probe whether cave NT references sub-pal 0/1
- If yes, extend `cave_palette_apply` to upload 16 bytes (subpals 0-3)
- If no, document why 2+3 sufficient

### Phase K5 (8h): bg_golden bundle infra
- `tools/parity/bg_golden/<scene>/<room_id>/{nt.bin, attr.bin, palram.bin, priority_mask.bin}`
- Per (scene, room_id) for OW (128) + cave (20) + UW (636 unique rooms across all level/quest)
- 784 total bundle files; ~5 MB committed
- Differ: `tools/parity/bg_diff.py` — byte-compare Gen Plane A vs NES NT after CHR translation

### Phase K6 (8h+): UW per-room state-aware golden
- Codex highlighted: UW BG depends on shutter/door/pushblock/bomb/item state
- Need cache key = (level, quest, room_id, state_hash) — much larger bundle
- Possibly split into "initial state" golden (fastest path) + "post-action" goldens for shutter/bomb events

## Priorities

1. **K1 (4h)** — dominant bug, visible everywhere on OW
2. **K2 (3h)** — visible Link-tree priority bug
3. **K5 (8h)** — verification infra, blocks all future regression detection
4. **K3 (4h)** — polish (waterfalls)
5. **K4 (1-2h)** — likely no-op once verified
6. **K6 (8h)** — defer to next phase

## Total: 28-36h
