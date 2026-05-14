# Phase 15 Task 15.3 — VDP Plane Strategy

- **NES source**: NES has 2 nametables. Genesis has 3 planes
                  (A / B / Window). NES nametable usage maps onto
                  Genesis Plane A; HUD takes Window plane;
                  transitions use Plane B.
- **Drained C**:  `RoomRom/src/atlas/roomrom_scene_vram_contracts.c`
                  + per-scene VRAM layout. Window plane HUD already
                  implemented inline during Phase 6.
- **Coverage**:   PARTIAL — strategy locked, verifier gates not yet
                  written. Window-HUD invariant in tree but
                  unverified by automated probe.
- **Stance**:     PARTIAL — strategy ADOPT (Window HUD + Plane A
                  playfield + Plane B staging already in use);
                  verifier work deferred to Phase 15
                  measurement-driven re-pass.

## Strategy (already in tree)

- **Window plane** = HUD + menu band (per Phase 6 inline 15a work).
- **Plane A** = active playfield (default).
- **Plane B** = transition / staging / backdrop.

## Deferred verifiers

- "Direct playfield writes into Window plane outside HUD owners" gate.
- "Large per-tile loops where bulk plane transfer exists" gate.

## Status

CLOSE (with verifier deferral) — Task 15.3 strategy in tree;
verifier gates deferred with `phase15_plane_strategy_verifiers`.
