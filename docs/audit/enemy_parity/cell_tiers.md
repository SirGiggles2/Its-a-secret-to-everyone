# Cell Tiering — Enemy Parity Audit

User said "match NES almost EXACTLY". Bytewise gate across all cells is
unhittable under RNG drift (see `probe_address_model.md` — A1 status).
Tier cells by what kind of mismatch counts as a real divergence.

## T1 — deterministic (must match bytewise)

These cells are pure functions of (initial state, input, time). After
force-poking RNG and Link position to identical state on both ROMs,
T1 cells MUST match every frame.

| Cell                   | NES addr      | Why deterministic                          |
|---                     |---            |---                                         |
| ObjType[slot]          | `$034F+s`     | Set once at spawn; written by table lookup |
| ObjX[slot]             | `$0070+s`     | f(spawn pos, dir, qspd, time)              |
| ObjY[slot]             | `$0084+s`     | f(spawn pos, dir, qspd, time)              |
| ObjDir[slot]           | `$008C+s`     | f(spawn dir, walk logic). Branches via RNG, but value is sampled  |
| ObjQSpdFrac[s]         | `$03BC+s`     | Set at init; static table                  |
| ObjAttr[slot]          | `$04BF+s`     | Set at init from table                     |
| MonHP[slot]            | `$04B8+s`     | Set at init; only changes on damage event  |
| ObjState[slot]         | `$00AC+s`     | State machine — deterministic given inputs |
| ObjMetastate[slot]     | `$04D8+s`     | Animation cluster (deterministic)          |
| ObjAnimCounter[s]      | `$03C8+s`     | Frame counter                              |
| ObjTimer[slot]         | `$0028+s`     | Generic — counts down per frame            |
| StunTimer[slot]        | `$003D+s`     | Counts down per frame; set on collision    |
| HitReaction[slot]      | `$04F0+s`     | Decrement every 2 frames; set on hit       |
| ShoveDir[slot]         | `$0490+s`     | Set on shove event                         |
| ShoveDist[slot]        | `$0498+s`     | Counts down                                |
| FirstUnwalk            | `$034A`       | Set once on room load                      |
| ChaseLongTimer         | `$004A`       | Decremented per frame; reset via Random[1] |
| ChaseTargetX           | `$0061`       | = LinkX unless mirror-flipped              |
| ChaseTargetY           | `$0062`       | = LinkY unless mirror-flipped              |

**Gate**: T1 cells = 0 divergence across audit window (60-240 frames).

## T2 — RNG-driven (matches only when RNG parity is intact)

These cells consume Random[$18..$24] at decision points. Match
bytewise ONLY if A1 RNG-stream parity is byte-identical at probe
start. With force-poke at probe start AND no extraneous Random
writers, T2 should match too. Mismatch in T2 with T1 also mismatch =
RNG drift; T2 alone = real divergence.

| Cell / behavior                | NES code site                            |
|---                             |---                                       |
| Walker turn-reroll direction   | `Z_04.asm:1965` UpdateLynel              |
| Octorok turn cadence           | `Z_04.asm:1845`                          |
| Shoot gate roll                | `_TryShooting` / `c_shoot_if_wanted`     |
| Drop-table lookup on kill      | `Z_04.asm:11035` ExtractHitPointValue    |
| Spawn-position roll            | `Z_07.asm:5528` LDA Random+1,X           |
| Octorok rock dir randomization | `Z_04.asm:5620`                          |
| Wizzrobe teleport target       | `enemy_wizzrobe_runtime.c:125`           |
| Moldorm split direction        | `enemy_moldorm_runtime.c:152`            |

**Gate**: T2 matches when A1 verified at frame 0. Otherwise: defer
T2 to RNG-parity follow-up.

## T3 — cosmetic / out of audit scope

These cells affect rendering or palette flicker only. Not in user's
"movement / attacks / AI" framing. Mismatch does NOT block audit.

| Cell                        | Why cosmetic                          |
|---                          |---                                    |
| ObjFrame / draw frame index | Sprite anim cadence — visual only     |
| Palette row / flash byte    | Hit flash + ambient palette cycle     |
| FrameCounter `$0015`        | Used as cycle source (T3 input → T1/T2 derived) |
| OAM mirror bytes            | Sprite SAT — handled by render audit  |
| ShoveScratchBytes           | Per-frame shove math intermediates    |

Render-side parity is a separate audit (`docs/audit/enemy_parity/` is
only for movement / attacks / AI).

## Audit probe template

Each family probe captures:

```lua
-- Per slot, per frame, log T1 cells:
f:write(string.format("%4d s%d T:$%02X X:$%02X Y:$%02X D:$%02X Q:$%02X A:$%02X HP:$%02X St:$%02X Ms:$%02X Tm:$%02X StTm:$%02X Hit:$%02X SDir:$%02X SDist:$%02X\n",
    fr, slot,
    R(0x034F+slot), R(0x0070+slot), R(0x0084+slot),
    R(0x008C+slot), R(0x03BC+slot), R(0x04BF+slot),
    R(0x04B8+slot), R(0x00AC+slot), R(0x04D8+slot),
    R(0x0028+slot), R(0x003D+slot), R(0x04F0+slot),
    R(0x0490+slot), R(0x0498+slot)))
```

Globals (frame-level T1):
- FirstUnwalk `$034A`, ChaseLongTimer `$004A`,
- ChaseTargetX `$0061`, ChaseTargetY `$0062`,
- LinkX `$0070`, LinkY `$0084`, LinkFace `$008C`,
- RoomId `$00EB`, CurLevel `$0010`, GameMode `$0012`.

Plus T2 inspection (Random[0..12] at `$0018..$0024`) for divergence
attribution.

## Compare script

`tools/audit/enemy_parity_diff.py` — reads NES + Genesis probe outputs,
emits per-cell tier-aware diff:
- T1 cell mismatch → BLOCK (counts as audit failure).
- T2 cell mismatch + T1 match → WARN (likely RNG drift; check
  `audit_rng_parity_*` output for the same frame window).
- T3 cell mismatch → IGNORE.

(Script does not yet exist; deferred to first family that needs it. By
default per-family probes write side-by-side text files and a
hand-paste diff is sufficient.)
