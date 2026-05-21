# In-scope live audit — 2026-05-21

Probe: `build/probes/audit_inscope_gen.lua` (fixed HP + ShoveDist cell addresses).
Baseline: `build/probes/baseline_inscope_gen.txt` (7681 lines, 33 types × 240 frames).

## Probe corrections committed

Two cell addresses were wrong in pre-fix probe — recorded garbage:
- HP read at $84B8+s → fixed to $8485+s (NES `MON_HP / ENEMY_HP`)
- ShoveDist read at $84C9+s → fixed to $80D3+s (NES `ObjShoveDistance`)

All other cells (state, qspd, metastate, obj_timer, shoot_timer, wants_shoot, hit_reaction, shove_dir, invincibility_mask, facing_dir, dir) verified correct against `src/state/enemy_state.h` + `src/zelda_translated/z_07.asm` cell map.

## Live findings (post-fix audit)

### Walker family

| Type | Name        | HP@f1 | Inv@f1 | Tm@f1 | Verdict |
|------|-------------|-------|--------|-------|---------|
| $01  | BlueLynel   | $60   | $00    | $02   | OK      |
| $02  | RedLynel    | $40   | $00    | $02   | OK      |
| $03  | BlueMoblin  | $30   | $00    | $02   | OK      |
| $04  | RedMoblin   | $20   | $00    | $02   | OK      |
| $05  | BlueGoriya  | $50   | $00    | $02   | OK      |
| $06  | RedGoriya   | $30   | $00    | $02   | OK      |
| $0B  | BlueDarknut | $40   | **$F6**| $02   | **BUG: Inv mask garbage** |
| $0C  | RedDarknut  | $80   | **$F6**| $02   | **BUG: Inv mask garbage** |
| $12  | Vire        | $40   | $00    | $02   | OK      |
| $13  | Zol         | $20   | $00    | $02   | OK      |
| $14  | RedZol      | **$00**| $00   | $02   | **BUG: HP init = 0** |
| $15  | Gel         | **$00**| $00   | $02   | **BUG: HP init = 0** |
| $16  | PolsVoice   | $A0   | $00    | $02   | OK      |
| $17  | LikeLike    | $90   | $00    | $02   | OK      |
| $1E  | Armos       | $30   | $00    | $02   | OK      |
| $21  | Ghini       | $90   | $00    | $1B   | OK      |
| $27  | Wallmaster  | $20   | $00    | **$00**| **CHECK: Tm=00 at spawn** |
| $28  | Rope        | $10   | $00    | $02   | OK      |
| $2A  | Stalfos     | $20   | $00    | $02   | OK      |
| $2B  | BlueBubble  | $F0   | $00    | $02   | OK (invincible obstacle) |
| $2C  | RedBubble   | $F0   | $00    | $02   | OK |
| $2D  | BlueBubble2 | $F0   | $00    | $02   | OK |
| $30  | Gibdo       | $70   | $00    | $02   | OK |
| $3F  | GuardFire   | $10   | $00    | $02   | OK |
| $40  | StandFire   | $10   | $00    | $02   | OK |

### Flyer family

| Type | Name        | HP@f1 | Tm@f1 | Verdict |
|------|-------------|-------|-------|---------|
| $1A  | Peahat      | $30   | $02   | OK |
| $1B  | BlueKeese   | $10   | $02   | OK |
| $1C  | RedKeese    | $10   | $02   | OK |
| $1D  | BlackKeese  | $10   | $02   | OK |
| $22  | FlyingGhini | $90   | $02   | OK |

### Jumper family

| Type | Name        | HP@f1 | Tm@f1 | Verdict |
|------|-------------|-------|-------|---------|
| $0F  | BlueLeever  | $C0   | **$00** | **CHECK: Tm=00** |
| $10  | RedLeever   | $20   | **$00** | **CHECK: Tm=00** |

## Bugs to fix (per audit)

1. **Darknut Inv mask $F6** (types $0B/$0C) — likely uninitialized garbage. NES Darknut has back-only damage gating via `MON_INVINCIBILITY`; should be set per `enrt_init_darknut`. Probe shows mask never cleared.
2. **Zol/Gel HP=$00** (types $14/$15) — `k_object_hp_pairs[10]=0x00` per enemy_loop.c:42. NES has Zol with 1-hp child split logic. Either table value wrong or split-from-Zol path skips HP init.
3. **Wallmaster Tm=$00** ($27) — fresh-spawn timer should be non-zero per NES InitWallmaster. Investigate `enrt_init_walker` for Wallmaster branch.
4. **Leever Tm=$00** ($0F/$10) — burrower init may legitimately use Tm differently (state-driven not timer-driven). Verify vs NES `UpdateBurrower`.

## Drop / knockback / respawn dimensions

NOT in this audit. Probe only captures Tier-1 deterministic cells. To extend:
- **Drops** — set Link adjacent to spawn point, simulate damage to MON_HP=0, observe enemy_drop_init() output.
- **Knockback** — simulate Link weapon collision, observe ShoveDir + ShoveDist progression over 30f.
- **Room-respawn** — re-arm same room, observe whether enemy persists or clears.

## Reproduce

```bash
./Debug.bat
cp build/probes/audit_inscope_gen.lua /c/tmp/
cp builds/Debug.md /c/tmp/
powershell -Command "Start-Process -FilePath '<bizhawk>\EmuHawk.exe' -ArgumentList '--lua=C:\tmp\audit_inscope_gen.lua','C:\tmp\Debug.md' -WorkingDirectory '<bizhawk>'"
# Wait ~2 min for self-exit
diff /c/tmp/audit_inscope_gen.txt build/probes/baseline_inscope_gen.txt
# Any non-zero diff = regression
```

## Next concrete actions

1. Fix Darknut Inv mask init in `enrt_init_darknut`
2. Fix Zol/Gel HP table or init path
3. Verify Wallmaster Tm semantic
4. Add NES-side equivalent probe (separate save-state walks) for true byte-diff
