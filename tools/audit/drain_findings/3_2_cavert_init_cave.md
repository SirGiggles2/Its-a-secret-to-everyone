# Drain Finding — Phase 3 Task 3.2 — `cavert_init_cave` + `cavert_init_cave_continue`

**Per Rule D1 Gate 1 (per-function diff).** Drained C compared against NES disassembly. Verdict per logical block: `MATCH | DIFF(<line>:<asm> vs <line>:<c>) | UNKNOWN`.

> **REVISION 2 (2026-05-02):** Initial finding flagged Block E money-game RNG byte as DIFF. RE-VERIFIED against `reference/aldonunez/Variables.inc:8 (Random := $18)` and re-confirmed scratch_state.h mappings: `ZP_RNG_A = $19 = Random+1`, `ZP_RNG_B = $1A = Random+2`. The drained C `CAVE_RANDOM_B = ZP_RNG_B = $1A` correctly reads NES `Random+2`. **Block E is MATCH.** False-alarm DIFF was an offset miscount on my part. Drain is fully correct for this function.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Drained C | `src/game/cave/cave_runtime.c` | 7-54 (cavert_init_cave_continue), 176-189 (cavert_init_cave) |
| NES asm | `reference/aldonunez/Z_01.asm` | 69-103 (InitCave), 105-244 (InitCaveContinue) |
| NES vars | `reference/aldonunez/Variables.inc` | 8 (`Random := $18`), 328 (`LevelBlockAttrsE := $6A7E`) |
| ZP map | `src/state/scratch_state.h` | ZP_RNG_BASE/A/B = $18/$19/$1A |

## Block-by-block diff

### Block A — Entry coords + dispatch test (NES 69-103 vs C 176-189)

| NES | C | Verdict |
|-----|---|---------|
| `LDA #$78 / LDY #$80 / JSR SetUpCommonCaveObjects` | `z01_set_up_common_cave_objects(120, slot, 0x80)` (120 = 0x78) | **MATCH** |
| `LDA ObjType+1 / CMP #$72 BEQ @TakeType / CMP #$71 BEQ / CMP #$7B BCS / CMP #$6E BCS InitCaveContinue` | `if (room_type == 0x72 \|\| room_type == 0x71 \|\| room_type >= 0x7B \|\| room_type < 0x6E)` | **MATCH** |
| `JSR GetRoomFlagUWItemState / BEQ InitCaveContinue / LDA #$00 STA ObjType+1 / UnhaltLink` | `if (progrt_get_room_flag_uw_item_state() != 0) { CAVE_ROOM_TYPE = 0; z01_unhalt_link(); return; }` | **MATCH** |

### Block B — Cave index + text selector (NES 106-124 vs C 8-11)

**MATCH** — straight transcription. `$03` ↔ `CAVE_TMP3` ↔ `ZP_TMP3`.

### Block C — Wares loop (NES 126-157 vs C 12-20)

**MATCH** — `LevelBlockAttrsE := $6A7E` lives in NES SRAM; drained `nes_ram[NES_SRAM_BASE(0x6000) + 0x0A7E]` = `nes_ram[0x6A7E]` ✓. `+60` (prices) = `$6ABA` ✓.

### Block D — Cave flags assembly (NES 158-184 vs C 22-26)

**MATCH** — bit packing `[3]>>6 | [0] | [2]>>4 | [1]>>2` equivalent.

### Block E — Money game RNG (NES 188-243 vs C 27-50)

| NES | C | Verdict |
|-----|---|---------|
| `AND #$20 BEQ @ResetTextbox` | `if (cave_flags & 0x20)` | **MATCH** |
| `LDA #$FF LDY #$06 @ChoosePermutation: CMP Random+1 BCC @FoundPermutation / SBC #$2B / DEY BNE` | `thresh = 0xFF; perm_idx = 6; while (thresh >= CAVE_RANDOM_A) { thresh -= 0x2B; perm_idx--; if (perm_idx == 0) break; }` | **MATCH** — `CAVE_RANDOM_A = ZP_RNG_A = $19 = NES Random+1` ✓ |
| `LDX MoneyGamePermutationEndIndexes, Y` then copy 3 perms backward to $046C-$046E | `end_idx = MoneyGamePermutationEndIndexes[perm_idx]; CAVE_MONEY_GAME_PERM(2/1/0) = MoneyGamePermutations[end_idx / -1 / -2]` | **MATCH** |
| `LDA Random+2 AND #$01` → MoneyGameLossAmounts index | `MoneyGameLossAmounts[CAVE_RANDOM_B & 1]` — `CAVE_RANDOM_B = ZP_RNG_B = $1A = NES Random+2` ✓ | **MATCH** |
| `LDA #$0A STA $0470` | `CAVE_MONEY_GAME_AMOUNT(1) = 10` | **MATCH** |
| `LDA Random+2 AND #$02 BEQ → $14 else $32 STY $0471` | `CAVE_MONEY_GAME_AMOUNT(2) = (CAVE_RANDOM_B & 2) ? 50 : 20` | **MATCH** ($14 = 20, $32 = 50) |
| `LDY #$02 @CopyAmounts: LDA $046F,X (perm) / STA $0468,Y / DEY BPL` | `for (j=2; j>=0; j--) { perm = CAVE_MONEY_GAME_PERM(j); CAVE_PRIZE_ORDER(j) = CAVE_MONEY_GAME_AMOUNT(perm); }` | **MATCH** |

### Block F — Reset textbox (NES @ResetTextbox vs C 52-53)

**MATCH** — `CAVE_TEXT_CHAR_INDEX = 0; CAVE_TEXT_LINE_ADDR_LO = TextboxLineAddrsLo[2]`.

## Verdict summary

All 6 blocks **MATCH**.

**Overall verdict: cavert_init_cave + cavert_init_cave_continue = FULL MATCH against NES InitCave + InitCaveContinue.**

## Action items

- ~~File sub-task 3.2a (REPLACE block E)~~ — REVOKED. No bug. Drain is correct.
- Update `src/state/scratch_state.h` to expose `ZP_RNG_BASE = RAM(0x0018)` for `Random+0` clarity. Done in same revision commit.
- Save this finding (revised) as the per-function diff template for subsequent Phase 3 tasks.

## Process lesson

False-alarm DIFF caused by miscounting NES Random offset (assumed Random+0 = $19; actually Random+0 = $18 per Variables.inc:8). **Future Gate 1 findings: always verify NES symbol addresses from `reference/aldonunez/Variables.inc` BEFORE comparing.**

This near-miss demonstrates exactly why per-function diff is layered with per-RAM-cell trace (Gate 2) and per-scenario oracle (Gate 3). A wrong DIFF would be caught by Gate 2 (NES money game would still match) before any REPLACE landed. Cost of the audit error here: ~30 minutes of writing + revising. Cost of acting on the wrong DIFF without re-verification: a regression.

Update Rule D1 implementation note: per-function diff findings should cite the `Variables.inc` (or equivalent symbol-table) reference for any address used in the comparison — provides traceability for the offsets.

## Stance update

Task 3.2 master plan header `Stance: ADOPT + EXTEND` stands as written. Block E confirmed correct. cavert_init_cave can be ADOPTED as-is into RoomRom dispatch wire-up; cavert_init_cave_continue likewise.

## Provenance

- Finding date: 2026-05-02 (initial), 2026-05-02 (revised after offset re-verification)
- Author: Claude Opus (autonomous session, debate 005 first Gate 1 application + first false-alarm correction)
- Tooling used: manual diff (per-function); future Gate 1 findings should cite Variables.inc for every NES symbol referenced.
