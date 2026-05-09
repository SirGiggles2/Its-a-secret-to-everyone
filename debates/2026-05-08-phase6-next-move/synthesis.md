# Phase 6 next-move debate — synthesis

**Date:** 2026-05-08  
**Topic:** Pick A / B / C for next Phase 6 move (4/11 close-gate, 0 blockers).

## Verdict — UNANIMOUS A

| Provider | Pick | Driving priority |
|----------|------|------------------|
| Codex (gpt-5)        | A | best ordering, low risk, observable state |
| Gemini (2.x)         | A | immediate visual validation, B premature, C blocked |
| Sonnet 4.6 (Agent)   | A | #3 efficiency + #1 long-term outcome |
| Claude Opus 4.7 (me) | A | smallest surface, biggest leverage, unblocks probes |

## Synthesis

A is the forcing function. Every other Phase 6 deliverable already in RAM
(RupeesToAdd/Sub tick, HeartValues damage subtract, ObjInvincibilityTimer
2-frame countdown, ownership gates) is observationally invisible until the
HUD reader consumes inventory_t. Without A:
- focused_probe_set has no visible state to diff
- screenshot_state_evidence captures the "always 3 hearts" placeholder
- B (StatusBarTransferBuf) ships the transfer plumbing but no consumer
- C (enemy→Link harm) is blocked on absent enemy collision/state path

## Trade-off accepted

A reads `g_inventory.heart_values` / `rupees` / `keys` / `bombs` /
`max_bombs` directly from `roomrom_hud.c` rather than routing through
the NES `DynTileBuf` transfer-buf pattern (B). Mild NES-accuracy debt at
the routing layer. Redeemable later: B replaces the direct read once
the transfer-buf path is wired.

## Action

Execute A:
1. Add live-read helpers in `roomrom_hud.c`:
   - heart row reads `heart_values_max(hv)` for outline count + `heart_values_cur(hv)` + `heart_partial > 0` for fill state
   - count rows read `rupees`, `bombs`, `keys` and format 3-digit decimal
2. Re-run `Debug.bat` and probe HUD via BizHawk.
3. Commit + refresh tracker.
