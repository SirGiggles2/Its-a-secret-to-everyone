# T-180 — failed capture cannot become timing acceptance

2026-10-02, Codex. P0.17. Owner `tools/lockstep/lag_gate.py`; retain run_lockstep, lag_scan and T-177 completion validators.

Problem: the new wrapper printed each child return code but ignored it, then returned lag_scan's result. A failed RAM gate with complete timing files, or a failed capture leaving older complete files, could therefore produce overall LAG PASS. Source f856d3be confirms this flow.

Correction: collect all nonzero capture/gate statuses and return1 with explicit LAG FAIL; do not scan/accept reports if any runner failed. Empty case inventory returns FAIL. Successful captures still propagate lag_scan's result. Add --rom and --report-suffix so a frozen payload and isolated report names pass through to captures and their matching scan. Caller supplies the immutable ROM; no claim that mutable default Debug.md is frozen across a suite.

Focused tests `python tools/lockstep/test_lag_gate.py`: **5/5 PASS**. They exercise failed runner with a potentially successful stale scan, one failure among successful cases, scan failure, frozen path containing spaces/suffix/budget forwarding, and empty inventory. Actual invalid-preset CLI returns1 / LAG FAIL with no PASS. No emulator launched for that missing input.

One real consumer: `python tools/lockstep/lag_gate.py t179_gel_dungeon_turn --rom builds/playtests/Debug-T179.md --report-suffix _codex_laggate --budget 0xE0` exits0. Child1856/1856 GATE PASS; one completed case, zero extra lag, worst lineD9. Frozen ROM SHA `AA64D45F23A0A2391156040D753E73E77C131762DB7D7FC9D5857FF897B1D8A5`; launched-payload hash captured in isolated run metadata. Logs `build/scratch/t180_live.log`, `t180_missing.log`; report `builds/reports/lockstep/t179_gel_dungeon_turn_codex_laggate`.

Python orchestration only; no game change/rebuild required after accepted T-179 Debug.bat. Earlier T-177 validators preserved. Whole legacy-launcher inventory and full performance acceptance remain separate; broad default busy suite not repeated.
