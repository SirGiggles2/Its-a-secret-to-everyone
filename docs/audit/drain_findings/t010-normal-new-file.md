# T-010 — normal boot, file creation, overworld start

**Result: PASS for the opening route.** On the current Windows ROM, controller input alone reached the title, File Select, empty-slot name board, registered `LINK`, selected that occupied slot, and entered Original overworld room `$77`. No debug all-items chord or state injection was used.

The existing `tools/debug/probes/probe_fs_register.lua` replayed the route in an isolated owned BizHawk Genplus-gx process with fresh private SRAM. Current `builds/Debug.md` SHA-256: `276a015a9b6f709bd0b6bb2ab616ae4aa512388ac236a5ce4f4f5a2a8b9faf6a`. Probe SHA-256: `81f0a617ed4b50a6bb8f8967c9d63543c7cfa81dc14cf69d9803e4bf491da314`. The output, five screenshots and launcher identity are in `builds/reports/recovery/t010-new-file-current/`.

All **11/11** checks passed: slot name/active/hearts, cart File A name/items/active/quest/markers/checksum, GameMode `$05`, profile hearts `$22/$FF`, max bombs 8, sword 0 and current save slot 0. The final screenshot visibly shows Link in the starting overworld with three hearts and no equipped sword. The old T-099 capture gave the same behavior on its earlier build; this rerun confirms the current ROM.

**Scope:** normal file creation and first overworld entry. Sword-cave acquisition is T-011, connected L1 play is T-013, and close/reopen save lifecycle remains under T-013/T-053. No production source changed for this verification.
