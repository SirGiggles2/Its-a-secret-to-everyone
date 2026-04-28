<!-- docs/audit/sram_map.md -->
# SRAM Map (locked at S0)

The Genesis SRAM region is divided into named ranges. The native rewrite must
preserve existing ranges byte-for-byte to keep saves loadable. New ranges
allocated at S0 stay reserved and unwritten until the relevant subsystem
lands.

Cart SRAM is declared in the ROM header at `$1B0`–`$1BB`: start `$200001`,
end `$203FFF`, odd-byte interleaved (stride 2), 8 KB total logical capacity.
The SRAM mapper port at `$A130F1` must be set to `$01` before any read/write.

Logical offsets below refer to the even 0-based index into the odd-byte
array: logical offset N → bus address `$200001 + N*2`.

The work-RAM mirror at `$FF6000`–`$FF7FFF` is populated from cart SRAM at
boot via `_sram_load_save_slots` and written back via `_sram_commit_save_slots`.
All C code reads/writes the mirror; only the commit/load helpers touch
physical cart SRAM.

| Range (byte offset) | Size | Owner | Status |
|---|---|---|---|
| `0x000` – `0x7FF` | 2048 bytes | NES save slots (3 files) | preserved verbatim by rewrite |
| `0x800` – `0x81F` | 32 bytes | `OptionsState` (Section 4.6) | reserved at S0; written first time in S8a |
| `0x820` – `0x1FF8` | 6105 bytes | unallocated | reserved for future use |
| `0x1FF9` – `0x1FFF` | 4 bytes (odd-byte: `$203FF9`/`$FFB`/`$FFD`/`$FFF`) | Boot smoke-test sentinel (`$5A $A5 $C3 $3C`) | written at boot to verify mapper; never interpreted as user data |

**Notes on the save-slot range:**

- NES Zelda 1 save slots occupy NES SRAM `$6000`–`$67FF` (3 files × ~680 bytes
  each, with gap/padding within the 2 KB window).
- The per-slot 2-byte checksums (`FileBChecksums`) are stored at work RAM
  `$FF1200` (6 bytes) and are NOT part of cart SRAM — they are recomputed
  on load and written only to the RAM mirror. Therefore no checksum byte range
  within `0x000`–`0x7FF` needs special treatment.
- The remainder of the NES SRAM window (`$6800`–`$7FFF`) is zero-filled in
  the mirror after slot load; it is not committed to cart SRAM.

### OptionsState SRAM layout

Per spec Section 4.6:

```c
struct OptionsState {
    u8  version;          // schema version
    u8  flags[N];         // packed flag bytes
    u8  reserved[16];     // future expansion, zero
    u8  checksum;         // simple XOR of preceding bytes
};
```

`N` is fixed at S0 to **8** (room for 64 bool flags or 8 enum byte-values).
Bumping `N` requires a `version` bump and a new persistence migration step.

Total struct size at N=8: 1 + 8 + 16 + 1 = 26 bytes. Padded to 32 bytes
(`0x800`–`0x81F`) with 6 trailing bytes reserved/zero.

Initial `version` = `0x01`. A zeroed or all-`$FF` region is detected as
invalid (XOR checksum will not match `version + flags + reserved`) and the
runtime falls back to defaults without overwriting the slot range.

### SGDK SRAM API

Byte-level access via SGDK: `SRAM_enable()`, `SRAM_disable()`,
`SRAM_readByte(offset)`, `SRAM_writeByte(offset, val)`, plus word/long
variants. Layout above is application policy on top of these primitives.

> **Note:** The existing codebase uses hand-rolled `_sram_enable`,
> `_sram_read_byte`, `_sram_write_byte`, and bulk `_sram_load/commit_save_slots`
> helpers in `src/nes_io.asm`. The native rewrite (S1+) may migrate to SGDK
> primitives but must preserve the logical byte offsets defined here.

### Invariant

S1's SRAM fixture test (`tools/probes/sram_layout_test.c`) asserts:

- existing save slot offsets are unchanged
- the OptionsState range is initialized to all-zero on a fresh SRAM
- on re-read, an all-zero `OptionsState` is detected as invalid (checksum
  fails) and the runtime falls back to defaults
