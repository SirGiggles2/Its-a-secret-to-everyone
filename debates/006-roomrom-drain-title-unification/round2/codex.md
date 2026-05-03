**Pick: D2.** Make `src/game/` non-A4 and use one `platform_abi.h` for both ROMs. D1 and D3 preserve the wrong abstraction: target-specific RAM ABI inside shared gameplay code. D3 is less bad than D1, but conditional ABI behavior in one header will still create “works in Title, breaks in RoomRom” failures. D2 makes the shared source actually shared.

Concrete r1 adjustment: keep debug boot, keep moving gameplay into `src/game/`, keep drain-as-oracle, keep cave-first native integration. Change the deletion step: `RoomRom/` does not die. It becomes a permanent build target whose boot path enters shared `src/game/` directly. Also change build work from “remove RoomRom” to “make both Title and RoomRom compile the same gameplay modules with the same ABI.”

RoomRom keeps its fast iteration because its value was never the folder name; it was boot-direct-to-gameplay, small target surface, and no title/story crash dependency. Under D2, RoomRom still boots straight into the gameplay entrypoint, but now exercises the exact same `src/game/` implementation that Title will eventually reach.

Yes, D2 still satisfies Debate 005 Rule D1 and `feedback_full_native_rewrite`. D1 means drain first as behavioral proof, not ship the drained A4 substrate forever. `feedback_full_native_rewrite` argues for removing transpile-era assumptions; D2 does that better than D1/D3 because A4-pinned `nes_ram` stops being the shared-game ABI.

Phase 12 “combine” deliverable changes: it is not deleting one ROM. It is proving both ROMs consume the same `src/game/` source and same gameplay state model. If there is later a single commercial/final ROM, that is a packaging/boot-flow milestone, not the destruction of RoomRom as a test cartridge.

Maintainability ranking: **D2 > D3 > D1**. D2 has one ABI. D3 has one file but two meanings. D1 has two headers and guaranteed drift.

Most autonomously achievable: **D3**, because it is the smallest edit. Best long-term: **D2**. I would still pick D2 unless profiling proves A4 is required.

Top new risk from “two ROMs forever”: test matrix drift. Every gameplay change must build and smoke-test both Title and RoomRom, or one target becomes ceremonial.

Convergence: drain-as-oracle, not drain-as-runtime. Debug boot is still necessary. First commit should be the dual-target scaffold: shared `src/game/` entrypoint, RoomRom boot path into it, Title debug boot into it, both builds green.
