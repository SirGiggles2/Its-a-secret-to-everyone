# T-172 — Patra busy-scene budget, merged verification (2026-10-01)

NES reference: `Z_04.asm` Patra rotation/maneuver; `Z_01.asm` monster collision;
`Z_07.asm` sprite publication. Owners: `enemy_patra_runtime`, `draw_dispatch`,
`sprite_dispatch`, `enemy_render`, `world_dispatch`, `link_collision_dispatch`.
Drain stance: optimize existing arithmetic/publication, preserve active collision paths.
Coverage: staged Q1 red Patra $52 protection/children/parent/death/drop/pickup/north
departure and named OW route; blue variant, re-entry, SRAM and connected L9 remain open.

Baseline had 125 slower ticks, including one staged reload and 124 fight ticks.
Read-only PC profiling identified shift-multiply, duplicate Patra OAM/native
publication, redundant scratch writes and five inactive weapon helper calls per
monster. Codex `71fc7a50` replaces byte-loop multiplication with the equivalent
16-bit product; packed carry/borrow and bounded cursor helpers preserve byte wrap.
Multiply 589824/589824, carry/borrow 66586624/66586624 and double-cursor 256/256
inputs agree. Rotation fell from 242.3 to 95.5 instructions/call. Native Patra
publishes its own parent/children/death; other bosses retain OAM publication and
resident CHR translation. Inactive weapon helpers are gated by their slot state;
active paths and final Link collision remain authoritative. Fixed spawn/death FX
are prepared with persistent CHR. Intermediate focused fairy, bomb, fire, rod,
Gleeok and Digdogger consumer evidence remains in isolated reports.

This reduced stalls to reload 300 and fragment-copy tick 370. Read-only watch
identified source tile 1073, generated item tile $30 (sword-shot spread). Claude
`a5d6190d` preserves item cache entries across scene swaps and queues ROM-derived
copies for VBlank; it also precomputes mode-3 UW layout work. This supersedes
Codex's unbuilt dedicated fragment-bank attempt, which was removed without
changing these general fixes. No new art input or dedicated VRAM reservation.

The build budget previously omitted the existing PT1 and palette-3 pair caches.
It now checks both against every occupied bank and VDP tables. Three in-memory
negative fixtures reject PT1/spark overlap, palette-3/boss overlap and table
overflow. Real bank headroom is 96 tiles. Freshness 9/9 and Windows `Debug.bat`
PASS; checksum $BF44, SHA-256:
`DDA0092EAD3C54DE34D06EC95741BEDB1A3325CEBE835D15C677185D725D8195`.

ROM frozen as `builds/playtests/Debug-T172.md`, matched ELF
`build/scratch/t172_final.out`; unique report directories avoid concurrent
Claude captures overwriting evidence:

- `t171_patra_sword_codex_t172`: 1533/1533 GATE, baseline 67 unchanged,
  no KEY differences/allowance; eight SCREEN MATCH ticks
  350/500/1100/1142/1224/1300/1435/1532. The 67 ratcheted cells consist of
  65 startup cells, OAM rotation $342 at 1 and transition scratch $58 at 1442.
- `t012_route_codex_t172`: 2187/2187 GATE, baseline 69 unchanged.
- Complete RAM lengths, video-record lengths and completion verified before
  `lag_scan`: **LAG PASS, zero slower-than-NES rows** for both routes, including
  Patra staged reload. Report `build/scratch/t172_final_lag.md`.

Claude reports 85/85 plus 510 visual cases on his a5d6190d build; those are his
evidence, not a newly repeated full-suite claim on this frozen ROM. T-172 remains
ACTIVE for other busy scenes, pause/continue and margin. T-177 records that
lag_scan currently skips missing traces and can falsely pass zero cases; the
shared probe runner also hashes a mutable source after capture. Frozen input and
explicit completion checks protected this verification.
