# Phase 15 Task 15.4 — DMA Transfer Optimization

- **NES source**: NES PPU uses CPU writes for VRAM updates. Genesis
                  VDP supports DMA for VRAM / CRAM / VSRAM. Scene-load
                  CHR + room tilemap fills are the high-value DMA
                  candidates.
- **Drained C**:  Phase 6 inline 15a work converted scene-load CHR
                  uploads to bulk DMA per `RoomRom/src/atlas/*`
                  pipeline. SAT DMA ordering enforced by SGDK.
- **Coverage**:   PARTIAL — bulk scene-load DMA + SAT DMA + tilemap
                  fills already converted (inline 15a). Inventory +
                  classification + per-frame chunking policy NOT
                  yet documented in a single audit.
- **Stance**:     PARTIAL — major DMA conversions ADOPT (in tree
                  since Phase 6); audit + post-DMA dump regression
                  probe deferred to Phase 15 measurement-driven
                  re-pass.

## Deferral

`phase15_dma_audit_and_regression_probe` — inventory every VRAM /
CRAM / SAT transfer site, classify scene-load vs room-load vs
per-frame vs rare-event, add regression probe comparing pre/post
DMA plane dumps.

## Status

CLOSE (with audit deferral) — Task 15.4 inline 15a DMA conversions
in tree; audit + classification + regression probe deferred.
