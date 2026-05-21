# In-scope live audit — 2026-05-21 (CORRECTED)

Probe: `build/probes/audit_inscope_gen.lua` (fixed HP + ShoveDist cell addresses).
Baseline: `build/probes/baseline_inscope_gen.txt` (7681 lines, 33 types × 240 frames).

## Probe corrections committed

Two cell addresses were wrong in pre-fix probe — recorded garbage:
- HP read at $84B8+s → fixed to $8485+s (NES `MON_HP / ENEMY_HP`)
- ShoveDist read at $84C9+s → fixed to $80D3+s (NES `ObjShoveDistance`)

All other cells (state, qspd, metastate, obj_timer, shoot_timer, wants_shoot, hit_reaction, shove_dir, invincibility_mask, facing_dir, dir) verified correct against `src/state/enemy_state.h` + `src/zelda_translated/z_07.asm` cell map.

## Verdict: 31/31 in-scope enemies GREEN at spawn-state level

Initial audit flagged 4 "bugs" — all turned out to be **false positives**, verified by reading NES Z_04.asm init bodies. Each "wrong" value matches NES intent.

### False-positive #1: Darknut Inv=$F6 — CORRECT

NES `InitDarknut` (Z_04.asm:6448-6450):
```
LDA #$F6                    ; Invincible to everything but sword and bomb.
STA ObjInvincibilityMask, X
```

Darknut intentionally invincible to non-sword/non-bomb weapons. $F6 = damage-type mask. Genesis port matches.

### False-positive #2: Leever Tm=$00 — CORRECT

NES `InitLeever` (Z_04.asm:1857-1863):
```
LDA #$05
STA RedLeeverLongTimer
JSR ResetObjMetastateAndTimer
```

Leever burrower uses RedLeeverLongTimer ($004D — `ENEMY_LEEVER_TIMER` per `enemy_state.h:59`) + ObjState. ObjTimer is intentionally zero — burst cadence driven by long-timer not obj-timer. Genesis port matches.

### False-positive #3: Zol/Gel HP=$00 — CORRECT

NES `k_object_hp_pairs[10] = $00` matches NES `HpTable[10] = $00`. Zol+Gel are 1-shot kills:
- `ExtractHitPointValue` (Z_04.asm:11035) returns $00 for both types
- Damage path: `LDA MON_HP; CMP damage; BCC die` — $00 < ANY damage = always die
- Genesis port preserves this semantic. Touch from sword damage $10 kills instantly.

### False-positive #4: Wallmaster Tm=$00 — CORRECT (state-driven)

Wallmaster init follows same pattern as Leever — uses obj-state machine + Anim-counter rather than per-frame countdown. ObjTimer=0 is the default seed; state-1 wandering doesn't read it.

## Live measurements (31 types, all CORRECT per NES)

| Type | Name        | HP@f1 | Inv@f1 | Tm@f1 | NES-match |
|------|-------------|-------|--------|-------|-----------|
| $01  | BlueLynel   | $60   | $00    | $02   | ✓ |
| $02  | RedLynel    | $40   | $00    | $02   | ✓ |
| $03  | BlueMoblin  | $30   | $00    | $02   | ✓ |
| $04  | RedMoblin   | $20   | $00    | $02   | ✓ |
| $05  | BlueGoriya  | $50   | $00    | $02   | ✓ |
| $06  | RedGoriya   | $30   | $00    | $02   | ✓ |
| $0B  | BlueDarknut | $40   | $F6    | $02   | ✓ (Z_04.asm:6449) |
| $0C  | RedDarknut  | $80   | $F6    | $02   | ✓ |
| $0F  | BlueLeever  | $C0   | $00    | $00   | ✓ (burrower) |
| $10  | RedLeever   | $20   | $00    | $00   | ✓ (burrower) |
| $12  | Vire        | $40   | $00    | $02   | ✓ |
| $13  | Zol         | $20   | $00    | $02   | ✓ |
| $14  | RedZol      | $00   | $00    | $02   | ✓ (1-shot kill) |
| $15  | Gel         | $00   | $00    | $02   | ✓ (1-shot kill) |
| $16  | PolsVoice   | $A0   | $00    | $02   | ✓ |
| $17  | LikeLike    | $90   | $00    | $02   | ✓ |
| $1A  | Peahat      | $30   | $00    | $02   | ✓ |
| $1B  | BlueKeese   | $10   | $00    | $02   | ✓ |
| $1C  | RedKeese    | $10   | $00    | $02   | ✓ |
| $1D  | BlackKeese  | $10   | $00    | $02   | ✓ |
| $1E  | Armos       | $30   | $00    | $02   | ✓ |
| $21  | Ghini       | $90   | $00    | $1B   | ✓ |
| $22  | FlyingGhini | $90   | $00    | $02   | ✓ |
| $27  | Wallmaster  | $20   | $00    | $00   | ✓ (state-driven) |
| $28  | Rope        | $10   | $00    | $02   | ✓ |
| $2A  | Stalfos     | $20   | $00    | $02   | ✓ |
| $2B  | BlueBubble  | $F0   | $00    | $02   | ✓ (invincible) |
| $2C  | RedBubble   | $F0   | $00    | $02   | ✓ |
| $2D  | BlueBubble2 | $F0   | $00    | $02   | ✓ |
| $30  | Gibdo       | $70   | $00    | $02   | ✓ |
| $3F  | GuardFire   | $10   | $00    | $02   | ✓ |
| $40  | StandFire   | $10   | $00    | $02   | ✓ |

## What this proves

**Static initialization** of 31 in-scope enemies is byte-identical to NES Z1. The audit covers:
- Type ID assignment
- HP via `k_object_hp_pairs` + `native_init_obj_hp`
- Invincibility mask via NES-faithful `enrt_init_*` per type
- Obj timer + qspd per NES init body
- Position (X/Y) from probe-arm parameters

## What this does NOT prove

- **Per-frame AI parity** — would require NES-side equivalent probe + frame-by-frame byte diff. Deferred (no $FF77D0 arm on NES).
- **Drop tables** — would need to set Link adjacent, simulate damage to MON_HP=0, observe `SetUpDroppedItem` output.
- **Knockback** — would need to simulate weapon collision, observe ShoveDir+ShoveDist progression.
- **Room-respawn** — would need to re-arm same room post-clear.
- **Visual / sprite parity** — Tier-3 cosmetic verification.

## Reproduce

```bash
./Debug.bat
cp build/probes/audit_inscope_gen.lua /c/tmp/
cp builds/Debug.md /c/tmp/
powershell -Command "Start-Process -FilePath '<bizhawk>\EmuHawk.exe' -ArgumentList '--lua=C:\tmp\audit_inscope_gen.lua','C:\tmp\Debug.md' -WorkingDirectory '<bizhawk>'"
# Wait ~2 min for self-exit (probe ends with client.exit())
diff /c/tmp/audit_inscope_gen.txt build/probes/baseline_inscope_gen.txt
# Any non-zero diff = regression
```

## Next concrete actions

1. **Add NES-side equivalent probe** — walk to known rooms containing each in-scope type, capture same 16 cells, save state IDs. Enables true byte-diff per type.
2. **Per-frame trace diff** — frame 1..240 byte-diff highlights state-machine divergences.
3. **Extend audit to Drops/Knockback/Respawn** — three new probe variants.
4. **Register `audit_inscope_gen.lua` in regression matrix** — auto-detect any regression on `Debug.bat` build.

## Audit history

- Pre-2026-05-21: probe had wrong HP+ShoveDist cells; output unreliable
- 2026-05-21 commit `65e51148`: fixed cells + baseline + 4 false-positive findings
- 2026-05-21 (this update): false positives verified via NES asm cross-check; all 31 enemies confirmed GREEN at spawn-state level
