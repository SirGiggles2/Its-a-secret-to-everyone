# Debate 058 Final Synthesis: Dungeon sprite + animation parity

## Verdict: 4 REAL bugs + 1 gap found via code investigation

| # | Bug | Owner file:line | Effort | Risk |
|---|-----|-----------------|--------|------|
| 1 | UW SPR palette `bg_only` on first entry | uw_render.c:210 | 2h | Low |
| 2 | 6 enemy families silent animation ($0B/$0C/$12/$13/$29) | enemy_walker_bridge.c | 2h | Low |
| 3 | All 9 boss draw paths stubs/unverified | enemy_dispatch.c:135, enemy_ganon_bridge.c:6, bosses.c | 7h | High |
| 4 | Item drops never drawn in gameplay | item_object.c:120-124 | 1h | Low |
| 5 | No door sprite animations (BG patches only) | door_state.c | 3h | Med |

## Visible bugs RIGHT NOW
- **Item drops invisible** (room-clear heart/rupee/key never appear)
- **Bosses don't render** (Aquamentus stub, Ganon explicit no-render)
- **6 enemy types frozen frame** (Darknut, Bubble, Rope animations don't advance)
- **First dungeon entry: enemies use OW colors** (palette inherit bug)

## Execution sequence (15h core + 11h infra = 26h)

### Phase J1 (1h): Item drop drawing
Edit `item_object.c:120-124` — remove "deferred" skip, call `draw_animate_item_object` per item slot per frame. Verify via NES probe.

### Phase J2 (2h): UW palette load on first entry
Edit `uw_render.c:210` `load_palette_from_levelinfo` — change `bg_only` → `palram_full`. Re-run dungeon sweep, expect color shift on enemy sprites first entry.

### Phase J3 (2h): 6 enemy animation rows
Drain $0B/$0C Darknut, $12/$13 Bubble, $29 Rope dispatch in `enemy_walker_bridge.c`. Pattern: clone existing row, swap z07_anim_advance_and_fetch call.

### Phase J4 (7h): Boss draw fix
- Aquamentus: full state-machine port from Z_04.asm (walk/head/fireball)
- Dodongo: walk/eat/stun/death animation states
- Manhandla: body/head_loss
- Gleeok: detached neck sprites
- Digdogger: large/split
- Gohma: eye open/closed
- Patra: orbit + core
- Ganon: invisibility, hit flash, death/triforce
- Add `bosses.c` atlas tile-id manifest mapping

### Phase J5 (3h): Door sprite animations
Bombable door reveal frames, shutter slide, key-lock disappearance. Port from Z_01.asm.

### Phase J6 (11h): Verification infra
- 5h: uw_golden bundle generator (mirror cave_golden from 057, extended for boss state-machine)
- 4h: per-boss state probe — force CavePersonState equivalents for each boss state
- 2h: CI hook + docs

## NES authority confirmed
- ObjAnimations + ObjAnimFrameHeap = source of truth for enemy/boss tiles
- Variables.inc:330 LevelInfo_PalettesTransferBuf — per-level palette
- Z_04.asm bosses — over-Link priority
- Z_07.asm enemy_loop dispatch

## Codex R1 summary
Hit gaps spot-on: "SPR subpalette routing, boss bespoke animation paths, OAM order/priority, frame timer off-by-one." Particularly highlighted boss state overrides bypass normal enemy table → exactly Sonnet's finding for stubbed Aquamentus + Ganon.

## Priority
1. J1 (1h) item drops — single line fix, immediate visible win
2. J2 (2h) UW palette — single function call change
3. J3 (2h) enemy anims — formulaic clone-and-paste
4. J4 (7h) bosses — biggest scope, do in pieces (Aquamentus first since L1Q1 is highest-traffic)
5. J5 (3h) door anims — polish
6. J6 (11h) verification infra — long-term gate
