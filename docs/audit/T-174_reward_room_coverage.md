# T-174 — missing Original Triforce rooms (2026-10-01)

- **NES source:** `reference/aldonunez/Z_05.asm:LayoutUWFloor, WriteSquareUW`; live Q1 L6 reward-room nametable and Q2 L8 reward-room video captures.
- **Drained implementation:** existing ROM-derived `tools/builder/gen_uw_room_tiles.py` composition and linked UW blob lookup; `inject_boss_rooms.py` now includes explicit Triforce roles.
- **Coverage:** data/lookup coverage for 11 missing rooms; live presentation for Q1 L6 and Q2 L8. Gohma controller fight, reward and departure are staged. Other new rooms, Triforce collection, persistence and connected quests remain unverified.
- **Stance:** EXTEND existing extraction/generation and required generated host artifacts. No replacement room renderer or game data embedded in release tooling.

## Reproduction and correction

`tools/lockstep/presets/t171_gohma_arrows.json` stages Q1 L6 at tick 50, mode-3 boss room $1C at 300, and selected bow at 620. It seeds bow/arrows, 60 rupees, sword and red ring. Controller input then leaves the doorway and fires arrows without state corrections. Closed-eye hit at 703 and half-open hit at 799 are rejected; upward arrow with open eye at 830 kills Gohma. Death ends 849, heart container is collected 922, north departure reaches $0C at 996. Maximum initial hearts do not verify capacity growth. NES-only bot input was folded into deterministic Genesis replay. An initial exit aimed at the wrong doorway X was a fixture error.

The 1087-tick RAM gate passed, but the final scene differed by 40,195 pixels: Genesis had a black room. CRAM and room darkness agreed, ruling out the initial palette hypothesis. The destination had neither a direct blob entry nor a same-block fallback. The existing ROM-data generator matched the live NES destination 704/704 tiles. The capture traversal list omitted terminal rooms; the manifest's explicit `triforce_room_id` still identified them. Injection now considers both boss and reward roles, retaining the existing direct/fallback checks and idempotence.

New entries (all Original, layout UID 63): Q1 L6 $0C, L7 $2B, L8 $2C; Q2 L1 $08, L2 $20, L3 $1B, L4 $00, L5 $4F, L6 $16, L7 $2D, L8 $1B. Aggregate/blob 649→660, Original 331→342; Redux remains 318. Tiles come from local extracted ROM data, attributes from the existing same-block/door capture majority, palette from existing level captures. This preserves the documented builder capture-independence gap under T-080; it does not close the distributable builder.

The sparse BG atlas grew 663→677 tiles. The old budget gate used two stale map constants and falsely passed a 14-tile overlap with sprites. The layout now reserves the actual generated count: BG 1–677, sprites 678–964, items 965–1074, PAL3 boss bank 1075–1138. The build gate compares the reservation to `BG_SPARSE_TILE_COUNT`; a temporary stale 663 reservation is rejected. Catalog and freshness sentinels were regenerated. This is the affected allocation slice, not full graphics-budget acceptance.

## Focused verification

Windows `Debug.bat` PASS, checksum $C7BD, ROM SHA-256 `8CA38EB91026E97900F7B8D9CE3DC846818615F48437FB857BDEF871346030C1`. Existing unrelated Claude flute/whirlwind WIP is present and preserved separately.

- Gohma **1087/1087 GATE PASS**; SCREEN MATCH 703/799/830/922/1086. At 845, nine pixels lie only in overlapping sprites (accepted stable Genesis order versus rotating NES OAM).
- Newly covered Q2 L8 $1B **480/480 PASS**; SCREEN MATCH 350/479. This is a staged entry/presentation case.
- Named consumers on this ROM: Digdogger **1454/1454 PASS**, exact split/child/reward/departure screens 840/1000/1326/1453; normal new game **266/266 PASS**, SCREEN MATCH 265; blue-ring pause **192/192 RAM PASS**. Pause motion is outside `screen_diff`'s supported settled frame model; no full pause-screen match is claimed.
- Room generator Original **342/342 byte-exact** against the aggregate. Across 660 entries: 562 exact, 98 existing Redux door-state variants; no floor/frame/underrun failures. Eleven generated entries agreeing with their generator is data consistency, not eleven independent live captures.
- Generated freshness **9/9 PASS**, VRAM gate PASS; stale-count negative check rejects as intended; second injection adds nothing.
- New baselines: Gohma 68 cells, Q2 reward room 65. Entry/setup classes inherited from existing staged fixtures; later OAM rotation ($342, plus $341 in Q2) and NES transition PPU-address scratch ($58 at 996) remain explicitly accepted. No gameplay KEY or other new runtime mismatch was blessed.

Reports: `builds/reports/lockstep/t171_gohma_arrows/`, `t174_q2_reward_room/`, `t171_digdogger_flute/`, `newgame/`, `t121_ring1/`. The blue-ring pause consumer exposed an independent presentation defect: 37/39 opaque ring pixels use red-grade colors despite blue-grade state. This is tracked separately as T-175; prior T-121 red-grade evidence remains valid.

T-174 passes its missing-room data/installed-output scope. Connected progression, off-route rooms, SRAM and complete quests remain open.
