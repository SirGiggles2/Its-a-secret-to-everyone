# T36 Stage F — SRAM[$6975] divergence

## Evidence

At t=288 (cave enter, mode $0B init), `AssignObjSpawnPositions`
runs on both NES and Gen. On Gen it writes $0350=$6A at PC $45CEE.

Gen state at that moment:
- $00EB = $77
- SRAM[$6975] = $42
- calc: ($42 & $FC) - $40 = 0 → >> 2 = 0 → + $6A = $6A ✓

NES state (per-frame capture, same t):
- $00EB = $77 (matches)
- SRAM[$6975] = 0 (captured from t=1..800+)
- capture shows $0350 = 0 throughout — NES never has $6A

## Hypothesis

NES's SRAM read at $6975 returns 0 (MMC1 mapper may disable
SRAM read access outside save-file operations, or NES save
image genuinely has 0 at $6975). On NES the calc yields:

- 0 & $FC = 0
- 0 - $40 (with 6502 SBC borrow) = $C0
- $C0 >> 2 = $30
- $30 + $6A + carry = $9A or $9B

$9A >= $7B → InitCave takes `_L_z01_InitCave_TakeType` branch →
GetRoomFlagUWItemState → item taken → __far_z_01_0001 →
destroy person ($0350 ← 0) → fall through to UnhaltLink
($00AC ← 0).

This matches NES observed behavior: $00AC=$40 set briefly
then cleared, $0350 stays 0.

On Gen: SRAM[$6975]=$42 → $0350=$6A → NOT TakeType →
InitCaveContinue → no UnhaltLink → Link halted forever.

## Root cause candidates

1. **Gen SRAM init bug**: fresh save should have 0 at $6975
   but Gen has $42. Possibly genesis_shell.asm preloads SRAM
   from ROM template, and that template carries $42 at $6975.
2. **Gen MMC1 emulation missing**: real NES disables SRAM reads
   outside save routines, Gen always reads from RAM mirror.
3. **NES has $42 at $6975 but via mapper banking read path
   differs** — less likely given SRAM is simple battery.

## Next step

Check `src/genesis_shell.asm` + `src/nes_io.asm` NES_SRAM mirror
init. Grep for how $FF6975 gets seeded on boot. If it's set
to $42 by ROM init, that's the bug — should be 0.

Alternatively: grep original NES ROM at offset corresponding
to save-file template for an $42 at relative offset $0975. If
ROM template has $42 but physical SRAM on NES reads 0, Gen's
literal-copy of template is wrong and must zero or skip that
byte.
