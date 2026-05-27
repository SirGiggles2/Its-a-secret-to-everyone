# Opus R1 — Dungeon sprite parity (verified Sonnet's findings)

## Sonnet identified 4 REAL bugs + 1 large gap

### BUG 1: UW SPR palette load wrong on first dungeon entry
- `uw_render.c:171` load_palette_from_blob = OK (both BG+SPR via palram_full)
- `uw_render.c:210` load_palette_from_levelinfo = bg_only, comment admits "SPR half preserved from prior room"
- First entry: enemies/bosses use OW SPR palette → wrong colors
- **Effort: 2h** (single call site change)

### BUG 2: 6 enemy families have NO animation dispatch
- $0B/$0C Darknut, $29 Rope, $12/$13 Bubble
- enemy_walker_bridge.c has dispatch rows for major types but these 6 are silent (no `z07_anim_advance_and_fetch` call) → frame phase frozen
- **Effort: 2h** (drain remaining rows)

### BUG 3: All 9 boss draw paths are stubs or unverified
- `enrt_update_aquamentus` (enemy_dispatch.c:135) = ONE-LINER stub
- Ganon explicitly "does not render or move" (enemy_ganon_bridge.c:6)
- `bosses.c` atlas 192 tiles, NO MANIFEST mapping → VRAM upload unverified
- This is the direct dungeon analog of cave SPR subpal gap, but MUCH worse scope
- **Effort: 7h** (probe + fix each boss + verify atlas mapping)

### BUG 4: Item drops never drawn in gameplay
- `draw_animate_item_object` fully implemented (draw_dispatch.c:674)
- `item_object_update` (item_object.c:120-124) SKIPS calling it ("deferred")
- → No room-clear heart/rupee/key/bomb drops appear
- **Effort: 1h** (1-line fix + probe)

### GAP 5: No door sprite animations
- `door_state.c` does BG tile patches only
- Shutter slide + bomb-door explosion sprite frames don't exist anywhere in src/game/
- **Effort: 3h** (port from Z_01.asm door anim path)

## Total: ~15h to close all dungeon sprite gaps

Plus verification:
- Extend cave_golden to uw_golden per (level, quest, room_id): 5h
- Per-boss room triples (multi-state oracle): adds 4h
- CI gate: 2h

**Grand total: ~26h** for dungeon byte-exact + Bossin parity infra.

## Priority order
1. **BUG 4 first** (1h, lowest risk): item drops invisible right now — visible regression
2. **BUG 1** (2h): UW palette on entry — visible color bug
3. **BUG 2** (2h): 6 enemy anims
4. **BUG 3** (7h): boss draw — high risk + large scope
5. **GAP 5** (3h): door anims — defer to polish phase

## Genesis improvements (opt-in)
- Bosses with extra detail (Aquamentus 2nd head animation, Gleeok individual head death frames smoothed)
- 60fps interp for enemy walk
- Per-boss particle effects (Gohma laser glow)
- Anti-flicker on 8+ enemy rooms

## Verification
Per Codex R1 + Sonnet R3 (057): raw OAM + per-tile CHR hashes. Frame phases per boss state (Aquamentus pre-hit / hit / death). Golden bundle path: `tools/parity/uw_golden/L<N>Q<Q>/R<XX>/{oam_f0,f30,f60,f120,state_X.json}`.

State machine per boss: hardcode probe-side state writes (e.g. force Aquamentus state=2 = throwing fireball) to capture all phases without playing through combat.
