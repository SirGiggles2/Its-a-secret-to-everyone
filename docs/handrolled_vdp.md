# Hand-Rolled VDP Allowlist (Rule SGDK-3)

**Default = SGDK API.** Raw VDP register writes outside boot/shim/adapter require ALL of:

1. Profiled hot path (cite the profiler output).
2. ≥15% measured cycle/frame or bandwidth improvement vs the SGDK API path.
3. Inline citation of the SGDK call replaced (e.g. `// replaces VDP_setTileMapData`).
4. Entry in this doc with profiler evidence + reviewer.
5. Adapter unit-test coverage proving equivalent visible behavior.

## Currently allowed exceptions

None. The owned game/frontend code goes through `src/sgdk_adapter/` 100% today. Boot and IO shims live in `src/genesis_shell.asm`, `src/nes_io.asm`, `src/c_shims.asm`, `src/audio_driver.asm` — those are the north-star ASM carve-outs and are exempt from this rule by directory matrix (see `tools/check_raw_vdp.py`).

## Adding an entry

Append a row below with: file path, function name, profiler evidence, replaced SGDK call, reviewer initials, date.

| File | Function | Cycles before | Cycles after | Δ | SGDK call replaced | Reviewer | Date |
|------|----------|---------------|--------------|---|--------------------|----------|------|
| _(none)_ |  |  |  |  |  |  |  |
