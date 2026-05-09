# Phase 6 Task 6.4 — Boomerang Verification

- **NES source**: `reference/aldonunez/Z_05.asm` WieldBoomerang; `reference/aldonunez/Z_07.asm` UpdateBoomerangOrFood + AnimateBoomerangAndCheckCollision (line 4209), BoomerangFrameCycle / BoomerangBaseSpriteAttrCycle (line 3779)
- **Drained C**:  N/A — RoomRom-native (`RoomRom/src/roomrom_boomerang.c`)
- **Coverage**:   PARTIAL (range-by-tier, stun, item pickup deferred)
- **Stance**:     ADOPT (timings + speed + 8-phase rotation lifted from NES; gaps tracked below)

## Verified parity

| NES behavior | NES anchor | RoomRom impl | Status |
| --- | --- | --- | --- |
| Q-speed $C0 = 3 px/frame | `Z_07.asm` UpdateBoomerangOrFood | `BOOMERANG_SPEED_PX 3` line 13 | ✅ |
| 8-phase rotation cycle | `Z_07.asm:3779` BoomerangFrameCycle | `s_phase_idx 0..7` + `advance_phase()` lines 56-63 | ✅ |
| 2 frames per spin phase | NES anim counter | `BOOMERANG_PHASE_FRAMES 2u` line 14 | ✅ |
| Outbound travel in facing direction | `Z_07.asm` boomerang dir field | `BOOMERANG_OUT` switch lines 72-78 | ✅ |
| Return chases Link | `Z_07.asm` ChaseLink branch in $40 state | `BOOMERANG_RETURN` chase lines 79-85 | ✅ |
| Re-throw locked while active | NES `s_state != IDLE` guard | `roomrom_boomerang_throw` line 41 | ✅ |
| 16x16 wide-object sprite, base attr 0 | `Z_07.asm:3437` | `ROOMROM_BOOMERANG_SUBPAL 0u` line 6 | ✅ |

## Deferred (Task 6.4-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Wooden vs magic range tier | NES item slot — magic boomerang travels farther + auto-pickups | RoomRom v6 has single 32-frame outbound; no inventory tier wired | Task 6.10 (Inventory + Pause) — once inventory exposes boomerang tier, gate `BOOMERANG_OUT_FRAMES` on `inventory.boomerang_tier` |
| Pause/spread state ($20) at distance limit | `Z_07.asm` UpdateBoomerangOrFood state $20 | Visual polish — no $20 spread frame in v6 | Task 6.4-followup (post-inventory) |
| Slow/decel state ($30) before return | `Z_07.asm` state $30 | Same as above; v6 returns instantly | Task 6.4-followup |
| Catch state ($50) when reaching Link | `Z_07.asm` state $50 | RoomRom auto-despawns at frame 64; should despawn on link-collision instead | Task 6.4-followup |
| Enemy stun on hit | `Z_07.asm` AnimateBoomerangAndCheckCollision | Enemy collision is Task 6.4 (Combat scaffolding) territory; needs enemy slot infra | Phase 7 (Enemies) — after enemy pool lands |
| Item pickup interaction (drag dropped items to Link) | NES boomerang ItemDrop pickup | Drops are Task 6.11 territory | Task 6.11 (Drops) |

## Probe / contract

- `tools/debug/test_boomerang_contract.py` — static contract: speed = 3,
  phase frames = 2, 8-phase cycle, outbound + return state machine,
  re-throw lock, deferral comment in source.

## Gate

- 4-line task header: filled.
- Gate 1: not applicable (RoomRom-native).
- Gate 2: deferred to phase exit.
- Gate 3: deferred to milestone tag.
