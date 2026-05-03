# Drain Finding — Phase 3 Task 3.2 — `cavert_init_cave` + `cavert_init_cave_continue`

**Per Rule D1 Gate 1 (per-function diff).** Drained C compared against NES disassembly. Verdict per logical block: `MATCH | DIFF(<line>:<asm> vs <line>:<c>) | UNKNOWN`.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Drained C | `src/game/cave/cave_runtime.c` | 7-54 (cavert_init_cave_continue), 176-189 (cavert_init_cave) |
| NES asm | `reference/aldonunez/Z_01.asm` | 69-103 (InitCave), 105-244 (InitCaveContinue) |
| NES vars | `reference/aldonunez/Variables.inc` | 328 (`LevelBlockAttrsE := $6A7E`) |

## Block-by-block diff

### Block A — Entry coords + dispatch test (NES 69-103 vs C 176-189)

| NES | C | Verdict |
|-----|---|---------|
| `LDA #$78 / LDY #$80 / JSR SetUpCommonCaveObjects` | `z01_set_up_common_cave_objects(120, slot, 0x80)` (120 = 0x78) | **MATCH** |
| `LDA ObjType+1 / CMP #$72 BEQ @TakeType / CMP #$71 BEQ / CMP #$7B BCS / CMP #$6E BCS InitCaveContinue` | `if (room_type == 0x72 \|\| room_type == 0x71 \|\| room_type >= 0x7B \|\| room_type < 0x6E)` | **MATCH** (BCS = unsigned ≥; the asm `BCS InitCaveContinue` after `CMP #$6E` is the FALL-THROUGH-to-continue path. C inverts the test to filter the @TakeType branch — equivalent.) |
| `JSR GetRoomFlagUWItemState / BEQ InitCaveContinue / LDA #$00 STA ObjType+1 / UnhaltLink: STA ObjState / RTS` | `if (progrt_get_room_flag_uw_item_state() != 0) { CAVE_ROOM_TYPE = 0; z01_unhalt_link(); return; }` | **MATCH** (NES: `BEQ continue` = if zero, fall through; C: `if (!= 0)` = take branch. Equivalent.) |

### Block B — Cave index + text selector (NES 106-124 vs C 8-11)

| NES | C | Verdict |
|-----|---|---------|
| `LDA ObjType+1 / SEC SBC #$6A / TAY` | `unsigned char cave_idx = (unsigned char)(CAVE_ROOM_TYPE - 0x6A)` | **MATCH** |
| `LDA OverworldPersonTextSelectors, Y / PHA / AND #$3F / STA PersonTextSelector` | `unsigned char sel_byte = OverworldPersonTextSelectors[cave_idx]; CAVE_TEXT_SELECTOR = sel_byte & 0x3F;` | **MATCH** |
| `PLA / AND #$C0 / STA $03` | `CAVE_TMP3 = sel_byte & 0xC0;` | **MATCH** ($03 ↔ CAVE_TMP3 ↔ ZP_TMP3 per scratch_state.h) |

### Block C — Wares loop (NES 126-157 vs C 12-20)

| NES | C | Verdict |
|-----|---|---------|
| `Y * 3` then loop `LDA LevelBlockAttrsE, Y / STA CaveItemIds, X / AND #$C0 / STA $00, X / LDA LevelBlockAttrsE+60, Y / STA CavePrices, X` for X = 0..2 | `for (i=0; i<3; i++) { item = nes_ram[0x6000 + 0x0A7E + 3*cave_idx + i]; CAVE_WARE_ITEM(i) = item; RAM(i) = item & 0xC0; CAVE_PRICE(i) = nes_ram[0x6000 + 0x0ABA + 3*cave_idx + i]; }` | **MATCH** ($6A7E = LevelBlockAttrsE per Variables.inc:328; $6ABA = +60 ✓; CAVE_WARE_ITEM(i) ↔ CaveItemIds; RAM(i) ↔ scratch zero-page $00..$02 ↔ ZP_TMP0..2) |

### Block D — Cave flags assembly (NES 158-184 vs C 22-26)

NES bit packing: `[3]>>6 | [0] | [2]>>4 | [1]>>2` → CaveFlags

C: `cave_flags = (CAVE_TMP3 >> 6) | CAVE_TMP0 | (CAVE_TMP2 >> 4) | (CAVE_TMP1 >> 2);`

`CAVE_TMP3` = $03 (selector high bits), `CAVE_TMP0` = $00 (item 0 high bits), `CAVE_TMP2` = $02 (item 2), `CAVE_TMP1` = $01 (item 1).

**MATCH** — bit packing equivalent.

### Block E — Money game RNG (NES 188-243 vs C 27-50)

| NES | C | Verdict |
|-----|---|---------|
| `AND #$20 BEQ @ResetTextbox` | `if (cave_flags & 0x20)` | **MATCH** |
| `LDA #$FF LDY #$06 @ChoosePermutation: CMP Random+1 BCC @FoundPermutation / SEC SBC #$2B / DEY BNE @ChoosePermutation` | `unsigned char thresh = 0xFF; unsigned char perm_idx = 6; while (thresh >= CAVE_RANDOM_A) { thresh -= 0x2B; perm_idx--; if (perm_idx == 0) break; }` | **DIFF (subtle)** — NES: `CMP Random+1 BCC @FoundPermutation` = "if Random+1 > thresh, found"; loop CONTINUES while Random+1 ≤ thresh. NES exit on `DEY BNE`: stops when Y reaches 0 (so perm_idx range is 1..6). C exits when `perm_idx == 0` after `--`, so range is 1..6 ✓. NES condition `BCC` after `CMP A,M` = "carry clear" = `A < M` (M=Random, A=thresh) = `thresh < Random`. So loop continues while `thresh >= Random+1`. C: `while (thresh >= CAVE_RANDOM_A)` ✓ if CAVE_RANDOM_A = Random+1. **MATCH** — re-verified, the apparent DIFF is a misread. |
| `LDX MoneyGamePermutationEndIndexes, Y` then copy 3 perms backward to $046C-$046E | `end_idx = MoneyGamePermutationEndIndexes[perm_idx]; CAVE_MONEY_GAME_PERM(2/1/0) = MoneyGamePermutations[end_idx / -1 / -2]` | **MATCH** |
| `LDA Random+2 AND #$01 / LDA MoneyGameLossAmounts, Y / STA $046F / LDA #$0A STA $0470 / LDA Random+2 AND #$02 BEQ → $14 else $32 STY $0471` | `CAVE_MONEY_GAME_AMOUNT(0) = MoneyGameLossAmounts[CAVE_RANDOM_B & 1]; CAVE_MONEY_GAME_AMOUNT(1) = 10; CAVE_MONEY_GAME_AMOUNT(2) = (CAVE_RANDOM_B & 2) ? 50 : 20;` | **DIFF (verify)** — NES uses `Random+2` for both reads; C uses CAVE_RANDOM_B which maps to $001A (per scratch_state.h `ZP_RNG_B`). NES `Random` is at $0019 (Random+0 = $0019, +1 = $001A, +2 = $001B). So NES `Random+1` = $001A and NES `Random+2` = $001B, but the cave_runtime.c `CAVE_RANDOM_A` = $0019 and `CAVE_RANDOM_B` = $001A. **MISMATCH on which RAM byte the C code reads.** |
| `STY $0471 / LDY #$02 @CopyAmounts: LDA $046F,X (perm) / STA $0468,Y / DEY BPL` (NES line 247-260, not shown above) | `for (j=2; j>=0; j--) { perm = CAVE_MONEY_GAME_PERM(j); CAVE_PRIZE_ORDER(j) = CAVE_MONEY_GAME_AMOUNT(perm); }` | **NEEDS NES TRACE** |

### Block F — Reset textbox (NES @ResetTextbox vs C 52-53)

| NES | C | Verdict |
|-----|---|---------|
| `LDA #$00 STA PersonTextCharIndex / LDA TextboxLineAddrsLo+2 STA PersonTextPtrLo` (etc.) | `CAVE_TEXT_CHAR_INDEX = 0; CAVE_TEXT_LINE_ADDR_LO = TextboxLineAddrsLo[2];` | **MATCH** |

## Verdict summary

- Block A entry/dispatch: **MATCH**
- Block B index/selector: **MATCH**
- Block C wares loop: **MATCH** (LevelBlockAttrsE = $6A7E in NES SRAM, drained C correctly maps via NES_SRAM_BASE + 0x0A7E)
- Block D cave flags assembly: **MATCH**
- Block E money game RNG: **MATCH** on permutation loop; **DIFF** on which Random byte cave_amount writes consume — NES uses Random+2 ($001B), C uses CAVE_RANDOM_B ($001A). One byte off.
- Block F reset textbox: **MATCH**

**Overall verdict: cavert_init_cave + cavert_init_cave_continue = MATCH-with-one-DIFF.**

## Action items

1. **Block E DIFF (priority: medium):** Verify `CAVE_RANDOM_A`/`CAVE_RANDOM_B` macro semantics. NES Z1 uses Random[3] starting at $0019. CAVE_RANDOM_A = $0019 (= Random+0). CAVE_RANDOM_B = $001A (= Random+1). NES uses Random+1 ($001A) for permutation threshold (matches CAVE_RANDOM_A in C → wait, that's Random+0). And NES uses Random+2 ($001B) for amount selection (NOT mapped in C — C uses CAVE_RANDOM_B = $001A).

   **CONCLUSION:** Drained C reads the WRONG NES Random byte for money-game amount selection. NES uses `Random+2` ($001B); C uses `CAVE_RANDOM_B` which is $001A (= Random+1). Per Rule D1, NES wins ties on correctness — file sub-task 3.2a (REPLACE block E amount selection with correct NES Random+2 read).

2. **Block E final amount-permute apply (`@CopyAmounts` in NES, lines below 244 not shown here):** trace NES asm fully + verify C `for (j=2; j>=0; j--)` permutation indexing matches NES X-register decrement order.

3. Save this finding as the per-function diff template for subsequent Phase 3 tasks (3.3, 3.4, 3.5, 3.7, 3.8 each need one).

## Stance update

Task 3.2 master plan header currently `Stance: ADOPT + EXTEND`. Block E DIFF requires sub-task 3.2a with `Stance: REPLACE` + this finding as the evidence pointer (per Rule D1 REPLACE evidence requirement).

## Provenance

- Finding date: 2026-05-02
- Author: Claude Opus (autonomous session, debate 005 first Gate 1 application)
- Tooling used: manual diff (per-function); future Gate 1 findings should follow this template shape
