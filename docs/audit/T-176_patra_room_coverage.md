# T-176 — missing Patra encounter room inputs (2026-10-01)

- **NES source:** `Z_05.asm:InitMode_EnterRoom, AssignObjSpawnPositions, LayoutUWFloor`; live Q1 L9 $52 NT/RAM/video.
- **Implementation:** existing ROM-data `gen_uw_room_tiles.py` and aggregate injection; linked UW render/collision lookup.
- **Coverage:** seven missing Patra-room data entries, one live installed room and spawn phase. Patra fight still fails independently after tick 365; no full route gate/baseline accepted here.
- **Stance:** EXTEND T-174 injection coverage and generated blob; no enemy or renderer replacement.

The explicit main-boss/reward roles did not cover intermediate Patra encounters. ROM AttrsC/D decode (`C & $3F | (D & $80) >> 1`) identifies Patra types $47/$48 in L9. Seven locations had neither direct entries nor same-block fallback: Q1 $16/$21/$27/$52/$61; Q2 $01/$46. Already covered Q2 $16/$44 remain unchanged. Injection now adds the missing L9 encounter roles from ROM tables rather than hardcoding room locations.

Pre-fix Q1 $52 was black (39,957 pixel differences at t350). Missing collision/layout input also rejected a valid spawn square: SpawnCycle and child positions diverged from 301. Live NES $52 tiles match existing generator 704/704. With its blob installed, t350 SCREEN MATCH and SpawnCycle plus all parent/child X/Y cells match every tick 301–366. Original generated-room consistency is 349/349; total blob 667, Redux unchanged 318. Sparse BG stays 677, so no new VRAM allocation or catalog change.

Windows `Debug.bat` PASS, checksum $E966, SHA-256 `C2A93F4EB4B4F95B1152C872FE52569F01A62A032C9E4C7C710FC743953FE168`; freshness 9/9 and VRAM gate PASS. Room generation: 569/667 exact, remaining 98 existing Redux door-state variants, no floor/frame/underrun failures. Includes existing unrelated Claude WIP. Evidence report: `builds/reports/lockstep/t171_patra_sword/` (overwritten by later focused verification; the reproduction numbers are preserved here).

This closes missing Patra room data/installed-input scope only. The controller fight still diverges first at maneuver timer t365 ($FF NES/$00 Genesis), then maneuver index t366 and child Y t367. No failing gameplay difference has been blessed. T-171 owns that bridge repair; capture-independent extraction remains T-080 and the other six new rooms lack independent live acceptance.
