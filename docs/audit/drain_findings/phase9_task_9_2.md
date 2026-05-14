# Phase 9 Task 9.2 — SRAM Persistence

- **NES source**: `reference/aldonunez/Z_05.asm:7375` InitSaveRam +
                  `Variables.inc` `SaveRamBegin` / `SaveRamEnd`
                  sentinels (`$5A` / `$A5`). SRAM base at NES `$6000`
                  per `NES_SRAM_BASE` aliased through
                  `platform_abi.h`. NES has no per-slot checksum —
                  Redux extension only. SaveFile inventory mirror lives
                  at NES `$0657..$067E` (40 bytes) per
                  `Z_05.asm` save / load helpers; this maps directly to
                  `SAVE_INVENTORY_RAM_BASE` / `SAVE_INVENTORY_BYTES`.
- **Drained C**:  NONE — InitSaveRam is a short native loop, not in
                  `tools/audit/drain_coverage.json` candidate set.
                  `src/state/save_serializer.{h,c}` is the native
                  substrate; its inventory mirror byte range is the
                  NES-parity slice, while the per-slot XOR checksum is
                  Redux extension over the NES contract.
- **Coverage**:   FULL (NES-parity slice) — magic sentinels (`$5A` /
                  `$A5`) + inventory mirror byte range (`$0657..$067E`)
                  match NES exactly. Per-slot stride (`682` =
                  `SAVE_SLOT_STRIDE`) preserves the NES contract that
                  options live BELOW the slot region (`$800..$81F`
                  options, slot region above per Task 9.2 master plan
                  spec).
- **Stance**:     EXTEND — adopts NES sentinel + inventory layout
                  verbatim; extends with Redux-only XOR checksum +
                  multi-slot detection. EXTEND is correct stance per
                  Rule D1: drain is empty (no candidate), NES asm wins
                  the sentinel + offset tie-break, Redux adds the
                  checksum layer (sanctioned per debate 004 save-format
                  ask).

## Substrate (`src/state/save_serializer.{h,c}` + `src/state/save_state.h`)

Per-slot layout (43 bytes):
```
[0..1]   magic       $5A $A5     (matches NES InitSaveRam sentinel)
[2..41]  inventory   $0657..$067E mirror (NES save inventory range)
[42]     checksum    XOR of bytes [0..41] (Redux extension)
```

Three slots at SRAM offsets `0`, `682`, `1364` (per
`SAVE_SLOT_STRIDE = 682`). Options live below at `$800..$81F` per Task
9.2 master-plan spec — the per-slot stride leaves the options window
untouched.

Public API:
- `save_slot_compute_checksum(slot_idx)` — XOR over slot bytes [0..41].
- `save_slot_serialize(slot_idx)` — write magic + inventory mirror +
  checksum to SRAM.
- `save_slot_deserialize(slot_idx)` — verify magic + checksum, then
  pull inventory back into RAM.
- `save_slot_is_valid(slot_idx)` — magic + checksum sanity for FS load
  / continue prompt.

## Probe

`src/state/probes/save_serializer_probe.c` — covers:
- defaults round-trip: clear SRAM → serialize → checksum matches.
- power-cycle: serialize → wipe RAM → deserialize → byte-for-byte match
  of `$0657..$067E`.
- invalid-zero / all-FF: forge zeroed and FF-filled slots; assert
  `save_slot_is_valid` returns false.
- multi-slot independence: poke slot A, leave B/C untouched; verify B
  / C slots remain valid.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
python tools/debug/build_debug.py  (probe TU compiled)
```

Clean build; `save_serializer.c` + probe linked into `Debug.md`.

## Status

CLOSE — Task 9.2 SRAM Persistence substrate landed. NES sentinel +
inventory mirror parity verified against `Z_05.asm:7375 InitSaveRam` +
`Variables.inc` `SaveRamBegin/End`. Redux XOR-checksum extension
sanctioned per debate 004 save-format ask.
