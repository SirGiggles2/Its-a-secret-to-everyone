# r1_sonnet — Phase 6 next-move verdict

**Pick: A — HUD live-read of inventory_t fields**

**Driving priority: #3 Maximal efficiency, backed by #1 Long-term outcome.**

A is the forcing function that makes everything already landed observable. RupeesToAdd/Sub tick, HeartValues damage, ObjInvincibilityTimer — all are in RAM but invisible until the HUD reader consumes them. Without A, the close-gate probes (focused_probe_set, screenshot_state_evidence) cannot produce meaningful diffs; you would be merging B or C against an unverified baseline.

B (StatusBarTransferBuf) is more NES-faithful at the transfer layer but produces zero visible change until an HUD reader exists downstream — it is the right final form, not the next unblock. C (enemy→Link damage) is explicitly blocked on missing collision/state wiring; forcing it now would require scaffolding that is not in scope.

**Trade-off accepted:** A's ~40 LOC reads inventory_t directly rather than going through the NES DynTileBuf path (B). That is a mild NES-accuracy debt at the HUD data-routing layer. Acceptable because A is a scaffolding step, not the final HUD implementation; B can replace the direct read once the transfer buf path is proven.

**Model:** claude-sonnet-4-6  
**Date:** 2026-05-08
