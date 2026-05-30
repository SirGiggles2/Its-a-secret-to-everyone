# Phase 0.A — HP cell width audit

**Date:** 2026-05-30
**Phase:** 8 (boss completion)
**Question:** Is `MON_HP` / `ENEMY_HP` cell 8-bit or 16-bit on Genesis port?

## Evidence

### Cell definition

`src/state/combat_state.h:56`
```c
#define MON_HP(slot)                    OBJ(0x0485, (slot))
```

`src/state/enemy_state.h:183`
```c
#define ENEMY_HP(slot)                      OBJ(0x0485, (slot))
```

Both alias the same offset `$0485` per Moldorm comment block at
`enemy_state.h:178`: "$0485 ObjHP(slot) aliases ENEMY_CHARGE_SPEED".

### Macro definition

`src/abi/platform_abi.h:52, 56, 64`
```c
extern volatile unsigned char *nes_ram;        /* RoomRom build */
register volatile unsigned char *nes_ram asm("a4");  /* Debug build */
#define OBJ(off, slot) (nes_ram[(off) + (slot)])
```

`nes_ram` type: `volatile unsigned char *`
Pointer arithmetic + `[]` deref yields `unsigned char` = **8 bits**.

### NES ground truth

NES Z1 `ObjHP` at `$0485` is 8-bit per Z_04.asm enemy HP table
(`EnemyHP`). Boss HP values are single bytes (Aquamentus=4, Dodongo=3,
Gleeok=variable per head 1..4, Ganon=4, etc).

## Verdict

**HP cell width = 8-bit** on both NES and Genesis port. **No
normalization needed** in `tools/parity/diff_boss.py`. Differ reads
raw byte at `$0485 + slot` from both sides and compares directly.

Phase B + D differs proceed against u8 HP without conditional logic.

## Implication for differ

```python
# tools/parity/diff_boss.py — HP cell read
def read_hp(ram_buf, slot):
    return ram_buf[0x0485 + slot]  # u8 both sides; no swap, no mask
```
