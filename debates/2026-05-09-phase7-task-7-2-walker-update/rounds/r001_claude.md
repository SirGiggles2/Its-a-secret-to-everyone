# Claude (Opus) — Round 1

## Pick: hybrid C → A (link asm chain) for Phase 7, with B (native drain) as the medium-term planned successor.

## Direct evidence I read

`src/c_shims.asm` primitives are calling-convention trampolines (4–7 lines each), not implementations:

```
c_walker_move:                     ; src/c_shims.asm:4455
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     Walker_Move            ; ← real body lives in zelda_translated/z_07.asm:3763
    move.l  (SP)+,D2
    rts

c_check_monster_collisions:        ; src/c_shims.asm:3656
    move.l  4(SP),D2
    jsr     z01_check_monster_collisions   ; → src/zelda_translated/z_01.asm
    rts

c_draw_object_not_mirrored:        ; src/c_shims.asm:3674
    move.l  4(SP),D2
    jmp     DrawObjectNotMirrored  ; → src/zelda_translated/z_01.asm:2069
```

This invalidates Option C as listed: **`src/c_shims.asm` IS the bridge.** A separate "thin asm bridge" file is just rebuilding what already exists. The real surface is the zelda_translated chain, not the shim file.

## Why A first, B second

- **D1 says drained C is PRIMARY, NES asm is SECONDARY but final authority.** A doesn't violate D1 — the drained C bodies (`enrt_update_rope`, `enrt_init_walker`, `enrt_octorock_common`) drive the algorithm; the asm chain only provides leaf primitives (Walker_Move, DrawObjectNotMirrored, z01_check_monster_collisions). That mirrors how the existing 433-function drain layer was wired pre-Phase-7.
- **Master plan Task 7.2 demands "Probe movement and collision."** That's impossible without primitive bodies. A unblocks probes; B alone cannot until weeks elapse.
- **gas/vasm friction is overstated.** The build already feeds `.asm` and `.s` files through gas with `-Wa,--register-prefix-optional --bitwise-or`. `c_shims.asm` was written for vasm but the M68K mnemonics + addressing modes are gas-compatible; the only known incompat is `dc.b $FF` padding tail (`feedback_drain_size_preserving`). Section directives + `rept/endr` may need adapter — small, scoped fix.
- **Per-function GC means we DON'T pay for everything.** Wiring `enemy_update_fns[$07] = enrt_update_rope` retains exactly its transitive call set. The first link will fail loudly with a finite list of undefineds — drive native drain (B) at those leaves over Phase 7.3+.

## Ordering risk

Don't try to land all walker UPDATEs in one commit. Sequence:
1. Add `c_shims.asm` + `src/gen/z_07.c` + `src/gen/z_01.c` to build_debug.py. Check link errors.
2. For each undefined symbol: add minimum `zelda_translated/z_*.asm` chunk OR drain to native (whichever is cheaper for that symbol).
3. Wire `enemy_update_fns[$07]` first. Probe trace. Then $05, $06, etc.

## Hard gotchas

- `OBJ_STATE` ↔ `ENEMY_STATE_TIMER` overlap (just bit me in step 3 probe at check[6]). Update bodies likely write both views — diff vs NES per-cell will surface drift.
- `c_shims.asm` references `Walker_Move`, `Obj_Shove`, `AnimateItemObject` — those ALSO need their chain. `wc -l zelda_translated/z_*.asm = 27,517`. Realistic upper bound on link surface, not actual.
- vasm `dc.b $FF` tail padding stripped at drain time will break vasm-style trampolines (`feedback_drain_size_preserving` from prior project memory). Inspect `c_shims.asm` for similar size-coupled blocks.

## Reject D

D ("defer entirely") fails master plan checklist + leaves Phase 7 in PARTIAL forever. /primedirective FRESH gates require evidence. No.
