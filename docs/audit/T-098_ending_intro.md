# T-098: ending initialization, flash and peace text

Status: partial checkpoint, **not whole ending or connected quest acceptance**. Live queue and next owner are in `docs/TRACKER.md`.

- **NES source:** `reference/aldonunez/Z_02.asm:InitMode13_Full`, `UpdateMode13WinGame`, `DrawLinkZeldaTriforces`; `Z_07.asm:HideAllSprites`, common timer loop.
- **Drained C:** existing `mode_wingame.c`, `sprite_dispatch.c`, `draw_dispatch.c`, `progress_dispatch.c`; frontend InitMode13_Sub3/Sub4 candidates reviewed. Existing palette tick drain read; retained.
- **Coverage:** PARTIAL. Initialization, curtain, thanks text, flash, peace text and their sprites verified at staged mode-entry scope. Credits and final profile/save reset remain unfinished.
- **Stance:** EXTEND existing linked mode, sprite, transfer and extracted-data owners. No new frontend dependency, RoomRom file or asset format.

## 1. Real problem and reproduction

The host had exclusive branches for death/end-level/continue/save, but no ending branch. Mode $13 therefore ran Link/weapon/enemy updates underneath its scaffold. The scaffold used ObjTimer+8 `$30` instead of Link's `$28`, ButtonsPressed `$F4` instead of `$F8`, and decremented the long timer every tick in addition to the common tenth-tick timer owner. Its initialization was never dispatched, and its sprite/credits/reset helpers were empty.

`t098_ending_update_before` captures the original public source plus private generated inputs on frozen595AD94C:1500/1500 completed ticks. At601, Zelda's Triforce stayed at the guard-fire coordinates; at792 the delay was written to `$30`; at793 the long timer decremented immediately, skipping most peace text. The host still animated guard fires/chase state during ending. No acceptance was inferred from the earlier staged Ganon reward tests.

After update-mode repair, `t098_ending_init_before` captures the remaining missing initialization on7BF99A0:2100/2100 ticks. NES initializes thanks text and enters update mode at981; Genesis never sets IsUpdatingMode. These are deliberate staged mode tests, not a fight/rescue route.

## 2. Structural changes

- One exclusive native host branch dispatches Mode $13 initialization or update before gameplay input/movement/objects/HUD. Existing common timers remain authoritative.
- InitMode13 uses the existing curtain/progress and column presentation owners, installs zero play-area attributes, emits the encoded thanks text and transitions through the source's delays into update mode.
- Correct timer/button aliases; remove the extra long-timer decrement and invented dynamic-buffer length write. Source-defined SongRequest is retained; audible music remains a separate unfinished check.
- Hide ending sprites each source-directed frame; draw Link with the existing specific-item writer at fixed OAM offsets, Zelda through the existing mirrored object writer, and both Triforces through existing item publishers. Native publication ownership is explicit.
- Reuse the normal Link pose renderer independently of death's persistent spark state. Avoid hiding Link with a raw position write before calling its cached lift renderer: that previously left the cache believing the now-hidden pose was already displayed.
- Palette transfer of `$3F10` updates Genesis's universal backdrop, matching its NES `$3F00` alias. This fixes the missing ending flash without a new palette override.
- Link existing217-byte `data/text/nes_frontend_text.c`; replace duplicate ending literals with its manifest offsets. Regenerate in `build/scratch/t098_extract/` from the supported supplied ROM: file byte-exact, SHA256 `C387C0A3A4F13C3CEA90983F57E60A655C472AFAFA0A10BA23E668CCBD8AAA34`. No generated file changed or published.

## 3. Verification and limits

Final `Debug.bat` PASS; local frozen `builds/playtests/Debug-T098-ending-init.md`, SHA256 `2664E2A56DA08964739C043CC9FB3F611AE67E1245612D151548F067BE5AF0F5`; matching ELF `build/scratch/Debug-T098-ending-init.out`. Launch manifests confirm the actual private launched ROM and exit0. `T-098_ending_intro.json` records exact counts and paths.

`t098_ending_init_final`:2100/2100 completed ticks. Setup at600 installs the source-defined Zelda handoff coordinates/blank tile map/curtain state with the fanfare already stopped. No later corrections. Between600 and1810 inclusive, all25 named state cells agree for1211 ticks: mode/update/submode, both delays, long timer, Link/Zelda/Triforce positions, curtain columns, story/peace character state and Link animation. At981 both begin update; at1173 both begin peace text; at1811 both begin credits.

Five decoded frames (680,800,1000,1200,1500), each256x224 pixels, **MATCH**: curtain completion, thanks text, flash and peace text with all four actors/items. Correct window settings used. Screenshots establish those appearances, not an audible or connected progression claim.

Raw GATE remains FAIL: two KEY differences at51/56 precede the ending setup and reflect this tick-clock staged load; no baseline was blessed. Native CurObjIndex/cache ownership differs; this is not whole-RAM equality. CreditsRow/VramLine/LineIndex still diverge when the credits stub is reached at1812.

Strict `lag_scan` remains FAIL: the ending episode is1500NES/1501GEN frames, one extra initialization frame at677. This is within the user's one-frame allowance. No busy-scene margin or broad T-172 acceptance follows.

Named consumers: final ROM normal boot266/266 and death760/760 **GATE PASS**; death/screen300 (window7) and continue/screen580 (window off) pixel-exact. Full normal L1 route9065/9065 **GATE PASS** on587B13C2 with the same palette repair before normal-Link renderer factoring; that unchanged route evidence carries forward. No broader suite repeated.

## 4. Remaining work / handoff

T-098 stays ACTIVE. Next: implement `DrawCredits` using existing `nes_frontend_credits` and text-support tables, correct nametable scrolling/attributes/window ownership and handle ending palette selector `$6A`. Finish final Triforce/ashes, source-defined Quest1-to-Quest2 profile conversion, normal save and actual SRAM close/reopen. Then verify controller rescue and unassisted Ganon victory; these remain T-022, not established by staging. Q2 ending variant and audible fanfare/ending routing remain unverified. T-051 is still TODO for remaining presentation.

Both presets disclose staging. `t098_ending_update` intentionally bypasses initialization; its peace text on the inherited dungeon palette is not valid initialized-ending presentation acceptance. The initialized fixture proves the correct palette path, rather than adding unsupported glyph copies for that invalid bypass.
