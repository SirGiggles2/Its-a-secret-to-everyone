# T-158 — ring pickup Link-Y control

**Result: the reported five-pixel pickup discrepancy was a fixture artifact, not a pickup defect.** No production code change.

The original T-155 contact stage placed Link at x`$C0`, y`$90` with `ObjGridOffset=0`. NES then reported y`$95` while Genesis retained `$90`. A control preset, `tools/lockstep/presets/t158_position_control.json`, placed Link at the same coordinates with **no item object**. The same y`$90 → $95` change occurred on NES tick 61, and Genesis remained `$90`. Item acquisition is therefore not the cause.

The NES live write callback at `$0084` reported PC `$EDEA`, value `$95` from tick 61 onward. The disassembly and `reference/aldonunez/Z_07.asm:EnsureObjectAligned` show the preceding instruction sequence: when `ObjGridOffset=0`, `ObjY := (ObjY & $F8) | $05`. The stage supplied an invalid grid-aligned Y. This routine also aligns X to an eight-pixel boundary. The original error was in the fixture's contact position, not a missing item-lift animation.

T-155's blue and red ring contact stages now use valid y`$95`; the item remains at y`$90`, within NES's nine-pixel pickup threshold. Both consoles clear the item and set `InvRing` 1 or 2 on tick 61, with Link y`$95` on both. Full focused captures now report **KEY 260/260** (blue) and **KEY 80/80** (red), zero failures. The diagnostic full-RAM GATE still has no baseline and reports pre-existing/staged scratch differences, so it is not a whole-game parity claim. `builds/reports/lockstep/t155_ring_pickup/`, `t155_ring2_pickup/`, and `t158_position_control/` retain captures.

**Stance:** KEEP the active gameplay path. Use NES-valid coordinates in future staged movement/item probes; natural-route evidence remains the stronger acceptance for connected progression.
