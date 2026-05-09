# Phase 6 next-move pick

State: 4/11 close-gate, 0 blockers, WT main, drain finding 6.1 backfilled.

Recent landed: inventory_t struct + singleton, Paused flag + gameplay-update gate, bomb/arrow/candle/wand/boomerang ownership gates, candle UsedCandle + per-room reset, RupeesToAdd/Sub rolling tick (every-other-frame), arrow rupee debit, HeartValues damage path with NES borrow-from-full-hearts $FF wrap quirk, ObjInvincibilityTimer 2-frame countdown.

Three candidate next moves:

- **A** HUD live-read of inventory_t fields (heart_values / rupees / keys / bombs / max_bombs). Replaces hardcoded "always 3 full hearts" in roomrom_hud.c. Small surface (~40 LOC). Makes rupee tick visible, makes future damage visible, unlocks probe-based close-gate steps (focused_probe_set, screenshot_state_evidence).

- **B** Task 6.10.6 NES-faithful StatusBarTransferBuf path per Z_01.asm:2850 FormatStatusBarText. Implements the transfer buf template + dynamic upload through DynTileBuf. Bigger surface, more NES-truth, no immediate visibility win without an HUD reader to consume it.

- **C** Task 6.11.2 enemy→Link damage hookup. Calls roomrom_link_damage_apply on enemy collision. Blocked: enemies not yet wired in RoomRom (collision/state path missing).

Decision priorities (Prime Directive):
1. Best long-term outcome
2. Best coding practice
3. Maximal efficiency
4. NES accuracy

Question: which next?

Brief verdict only — under 200 words.
