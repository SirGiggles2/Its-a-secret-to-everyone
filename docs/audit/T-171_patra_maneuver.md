# T-171 — Patra post-collision maneuver index (2026-10-01)

- **NES source:** `Z_04.asm:UpdatePatra, PatraManeuverTime`; `Z_01.asm:CheckLinkCollision, CheckMonsterCollisions`.
- **Drained C:** `boss_patra.c` orchestrator and `enemy_patra_runtime.c` child/math helpers; collision dispatch.
- **Coverage:** Q1 red Patra $52 child protection/kill, parent fight/death/drop/pickup/north departure. Blue variant, timer reload coinciding with death, re-entry/SRAM/connected route remain open; scene performance still FAIL.
- **Stance:** EXTEND existing orchestrator; preserve current no-children path and drained collisions.

After T-176 repairs absent room/collision input, the first real divergence is timer $2A at t365 ($FF NES/$00 Genesis), maneuver index at 366, child Y at 367. The bridge retained the child-search Y (8), incorrectly used zero-filled pretend ROM bytes and flipped maneuvers again at 366. NES calls CheckLinkCollision after that search: it resets Y to zero; DoObjectsCollide also restores Y from Link slot zero, and ring damage counts Y down to zero. A live NES memory callback observes the timer write at PC $ABAD with **Y=0, X=1**, frame 953; `build/scratch/patra_trace.json` creates read-only instrumentation, report `t171_patra_trace/`. Source `PatraManeuverTime[0]` is $FF. The bridge now uses post-collision index zero. Removed invented zero-padding and corrected misleading FULL coverage comments.

Windows `Debug.bat` PASS, checksum $0908, SHA-256 `CDE3B0717CE0FE1FDD637C09A7DB7D41FB750BBC00EE4BFAE38E909D155C1E2B` (includes existing Claude WIP).

- **1533/1533 KEY ticks match**, no gameplay allowance. Eight children clear progressively at 482/502/602/680/683/695/1142. Sword overlaps protected parent at 446–456 while eight children remain: HP stays $B0. Last child clears 1142 and parent takes first accepted hit ($B0→$70), then $30 at 1175; death starts 1224, drop appears 1243, collected 1334, north departure to Ganon room $42 at 1442.
- SCREEN MATCH at 350/500/1100/1142/1224/1300/1435/1532.
- Named generated-data consumer Gohma **1087/1087 GATE PASS**, existing baseline unchanged.
- **No Patra baseline blessed yet.** 65 familiar setup cells plus accepted OAM rotation ($342) and transition address scratch ($58) remain. CurObjIndex also differs at only 418/484: Genesis is sampled mid-object-loop, restored next tick. Frame dump confirms these ticks each spend two video frames.
- `lag_scan.py t171_patra_sword`: **FAIL**, 125 slower ticks, 236 NES/362 Genesis video frames summed over those ticks; includes staged reload at 300. Busy fight from 367 repeatedly costs two frames. Performance remains T-172 and blocks final Patra scene acceptance; do not turn state/screenshot success into full scene PASS.

Preset `tools/lockstep/presets/t171_patra_sword.json` stages level at 50/room reload 300, then uses controller-only NES bot input folded into deterministic Genesis replay. Magic sword/red ring/full hearts are declared fixture prerequisites. An aborted south-exit trial correctly hit the wall; final route uses north shutter. No post-entry state corrections. Reports `builds/reports/lockstep/t171_patra_sword/`, `t171_gohma_arrows/`. Next: profile/repair Patra busy-scene budget under T-172, then establish baseline only after unresolved differences are accounted for.
