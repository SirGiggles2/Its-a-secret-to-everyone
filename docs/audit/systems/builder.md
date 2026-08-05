# System audit — builder

> Status is derived from the signed evidence blocks below, never from
> this file's existence. No blocks = all five cells RED. See
> `docs/superpowers/specs/2026-08-03-completion-tracker-design.md`.

**Audited:** 2026-08-03. First system audited per spec §6 ordering.

## Scope

The builder owns the path from *a user's own NES ROM* to
`builds/Debug.md`, plus the gates that decide whether a build may be
packaged and shipped.

Owns:

- `tools/builder/build.py` — drag-and-drop entry point (ROM → ROM)
- `tools/builder/from_scratch_gate.py` — from-scratch reproducibility
- `tools/builder/determinism_gate.py` — deterministic-rebuild gate
- `tools/builder/package_check.py` — release include/exclude policy
- `tools/builder/release_gate.py` — gate orchestrator
- `tools/builder/strict_build_check.py` — generated-only build gate
- `tools/builder/completion_gate.py` — completion-tracker gate
- `tools/debug/build_debug.py` — the single build script
- `tools/sgdk_pin.json` — pinned toolchain

Does NOT own:

- The correctness of any extracted asset. Each asset is audited on the
  DATA axis of the system that consumes it.
- Gameplay behaviour of the ROM it produces.

## Axis verdicts

```yaml evidence
- system: builder
  axis: LEGAL
  verdict: GREEN
  artifact: docs/audit/package_check_status.md
  artifact_sha256: 09ce5a9f7ca128545d3a57e1739893d56a8e3b2820b75ebb81d7c55e53eca4f9
  command: python tools/builder/package_check.py --emit-evidence builder
  verdict_line: 'package_check: 107 banned file(s) excluded, 12576 would ship'
  manifest_emitted_by: tools/builder/package_check.py
  run_signature: 624b06a2e50713e891a0f0f71450108502179850ae2ece17b78b1b3938dd344e
  inputs:
  - path: tools/builder/package_check.py
    sha256: c3d3e8fc1669dd15d60f19cd25530de9d1ad1b677d07358d1a0c031d9fb87498
```

```yaml evidence
- system: builder
  axis: BEHAVIOR
  verdict: GREEN
  artifact: docs/audit/determinism_status.md
  artifact_sha256: 7ed078b67674bba29e5180153041b703f4d9ae8e7d354ee2100587f83d88b2ab
  command: python tools/builder/determinism_gate.py --emit-evidence builder
  verdict_line: 'determinism_gate: deterministic rebuild byte-identical, 2097152 bytes,
    sha256 0e2f06dbdd7762a78a644bc4923bd6fd6e5c292792b389269bfefed2e3172d44 (NOT from-scratch
    reproduction; see from_scratch_gate.py)'
  manifest_emitted_by: tools/builder/determinism_gate.py
  run_signature: fb4285b39b1e2171dc90bb7ceb3386326f7c9f2249c4d68438fa38e391c074e0
  tolerance: 'Zero tolerance: the two builds must be byte-identical. No accepted deltas.
    Scope is deterministic rebuild only; from-scratch reproduction from a user ROM
    is unproven and tracked as a RED gap on the PLAYABLE axis.'
  inputs:
  - path: tools/debug/build_debug.py
    sha256: 683e37c905276f82ecdb7b662c024d32beaf688f0bbaeb58b6b7e762238c2ee3
  - path: tools/builder/determinism_gate.py
    sha256: 01ec4f64664bf0f0563751b175baa2e6377d5c4f4cb216c44936521c21c58fb1
  - path: tools/sgdk_pin.json
    sha256: cd9d3071b25c8801e4f01376d7a5ca32f60bfe31b97bd2e2567969e817ce34a8
```

```yaml evidence
- system: builder
  axis: CODE
  verdict: GREEN
  artifact: docs/audit/extractor_coverage_status.md
  artifact_sha256: 9d38a742356984920374afe2500649f20d1f7786b621c7c98e28cbf86a14ca14
  command: python tools/builder/extractor_coverage_gate.py --emit-evidence builder
  verdict_line: 'extractor_coverage: 11 extractor(s) wired into build.py, 1 documented
    as manual, 12 on disk, 0 unwired'
  manifest_emitted_by: tools/builder/extractor_coverage_gate.py
  run_signature: db0639750f362fc5ecb7fa9ed3560da6f9569f29d89dcf84da06a1c73f4de7b2
  inputs:
  - path: tools/builder/build.py
    sha256: 2d917e01912a5700d04a2624d00295e1ff685a01f4008f32e1986e0fe0fce77a
  - path: tools/builder/extractor_coverage_gate.py
    sha256: 8e01c849aaf7bc9e3028372198ba6031cbf572e4e4f24a594460aff64316b1f4
  - path: tools/extract_nes_banks.py
    sha256: 22d99e39ae057889bd546b24f5402321d33be1d6e9d778bfaed4e4fb15d04a84
  - path: tools/extract_dat_sidecars.py
    sha256: 9ff900d17c8a6c3975e7f7cb7a8893e0e7eb44b1624fa25de8fde3c51ffac0e7
  - path: tools/extract_chr.py
    sha256: c9719abfd1cfecb5a1e4bf22a486c722efc91e43a630bd1848e1150c5b1b7f22
  - path: tools/extract_rooms.py
    sha256: 5477de1e21086f0cf4d8dc9b7f853ad9b4f442426e9e639f291598613c3faf8d
  - path: tools/extract_enemies.py
    sha256: 7ead21ef8f1734c827844a030d4d21c7c461b637ffdb5490231b5bef67c0da47
  - path: tools/extract_audio.py
    sha256: 004ef3b4124cab8923919c8d629ad45bc29f70abe62180003e18abc1a829034b
  - path: tools/extract_dmc_samples.py
    sha256: 12cb80af69fac7bb2dbfe7545b854bd3fb6df1b229ad5477649210604fe234be
  - path: tools/extract_frontend.py
    sha256: c6ad683511335d6532a92e78a383f0762759d7e62e966338d7b1cc7ca0c0b799
  - path: tools/extract_misc.py
    sha256: 0b1f7b2245e8e7847ecc81c9334567cebe5326c2d7a5d2b5d1ab7e5aae6dde90
  - path: tools/extract_demo_text.py
    sha256: ddb7244fcaf89e688c0edb82a31ddef4aa7c9dfa7a042c27e59251706e3fa302
  - path: tools/extract_intro_assets.py
    sha256: 9f6a32a741efcafb953e9afe37540983735f86ee6bcee1738d67abed3f36b8dc
```

```yaml evidence
- system: builder
  axis: PLAYABLE
  verdict: GREEN
  artifact: docs/audit/from_scratch_status.md
  artifact_sha256: 0cd994a872eb6df781b83feeab11a2faee8fb1b3383a7ef5597407f3d26d9ca3
  command: python tools/builder/from_scratch_gate.py <rom> --emit-evidence builder
  verdict_line: 'from_scratch_gate: byte-identical reproduction from a user ROM, 2097152
    bytes, sha256 0e2f06dbdd7762a78a644bc4923bd6fd6e5c292792b389269bfefed2e3172d44'
  manifest_emitted_by: tools/builder/from_scratch_gate.py
  run_signature: 570b86cd12e2efaed4ebbd4ad439d778f6168baa84698ea9621a8251687ae5a8
  rom_identity: 8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac
  inputs:
  - path: tools/builder/from_scratch_gate.py
    sha256: 2270d2c2c7c42460c9937d37f21288f307df00d628c981fd7e99b007ae3d4eeb
  - path: tools/builder/build.py
    sha256: 2d917e01912a5700d04a2624d00295e1ff685a01f4008f32e1986e0fe0fce77a
  - path: tools/debug/build_debug.py
    sha256: 683e37c905276f82ecdb7b662c024d32beaf688f0bbaeb58b6b7e762238c2ee3
```

```yaml evidence
- system: builder
  axis: DATA
  verdict: N/A
  reason: The builder produces NES-derived assets, it does not own any. Every asset
    it emits is audited on the DATA axis of the consuming system.
```

PLAYABLE has no evidence block. It is RED — see the gap list. That is
deliberate: RED with a named gap is the honest state, and inventing an
N/A allowlist entry to make the grid look better is exactly what the
allowlist mechanism exists to prevent.

## Gap list

### PLAYABLE — RED. The extractors regress committed data.

**Executed 2026-08-03** against `roms/Legend of Zelda, The (USA).nes`
(sha256 `8f72dc2e98572eb4ba7c3a902bca5f69c448fc4391837e5f8f0d4556280440ac`,
131088 bytes). This is no longer "never run" — it ran, and it failed for
a concrete reason.

What worked:

- ROM hash validated.
- All 11 wired extractors executed and exited 0. The CODE-axis wiring is
  confirmed against a real ROM, not just statically.
- `build.py` correctly propagated the downstream failure (exit 3).

What failed — `check_generated_freshness` 2 of 8 specs:

```
uw_collision:    expected 706fa5bc1b43..., got bbd0d8d7b0b1...
bg_palette_blob: expected 0fdddf3b7b91..., got 2d8642914da2...
```

Root cause: regenerating from the ROM **overwrites committed generated
data with different content**. Three tracked files changed:

| File | Change |
|---|---|
| `data/rooms/dungeons.c` | 25 lines; the Q1-LBA fix header was stripped |
| `data/misc/palettes.c` | 4 lines |
| `data/text/MANIFEST.json` | 319 lines deleted |

**CORRECTION (same session).** The first reading of this — that
`extract_rooms.py` reintroduces the Q1/Q2 LevelBlockAttrs bug — was
wrong, and was based on the stripped header comment rather than the
bytes. Byte-diff says the opposite:

```
regen[0:768]    == LevelBlockUW1Q1.dat : True
regen[768:1536] == LevelBlockUW2Q1.dat : True
```

The extractor emits the **correct** Q1 LevelBlockAttrs. Only the header
comment was lost, which is cosmetic. The Q1-LBA fix is not at risk.

The real divergence is 35 bytes at `0x0c24-0x1427`, entirely inside
`LevelInfoUW1..UW9`, and at exactly one field position in each:
**in-block offsets 36-39**.

Ground truth, `reference/aldonunez/Variables.inc`:

```
LevelInfo_PalettesTransferBuf := $6B7E   (block base)
LevelInfo_FoeCounts           := $6BA2   -> offset $24 = 36
```

So offsets 36-39 are `LevelInfo_FoeCounts`, the 4-entry table
`Z_05.asm:1726` indexes with a 2-bit per-room group id. This is the field
`fix_dungeons_q1_lba.py` explicitly declined to touch: *"LevelInfo (incl.
FoeCounts at SRAM offset 36) is NOT touched here — its dat layout differs
(FoeCounts at dat offset 32). Tracked separately for regular-room
counts."*

Neither side is verified correct:

| | L1 | L2 | L6 |
|---|---|---|---|
| committed | `03 05 06 08` | `03 05 06 08` | `03 05 06 08` |
| regenerated | `dd c9 ac 89` | `2c 0a b0 7d` | `ff ff 1c 00` |

- The **regenerated** values are garbage — the extractor copies
  `LevelInfoUW{n}.dat[36:40]`, but the dats carry FoeCounts at offset 32,
  so it lands four bytes late and picks up neighbouring fields.
- The **committed** values are identical across all nine dungeons, which
  is implausible for per-level data and matches
  `LevelInfoUW1.dat[32:36]` exactly. That looks like L1's values were
  copied to every level.

So the extractor is definitely wrong, and the committed data is probably
also wrong — just wrong in a way that happens to be harmless-looking.
Resolving it needs the real per-level FoeCounts read from the ROM at the
verified LevelInfo table offsets.

All three files were restored (`git checkout`); freshness re-verified
8/8 OK, and `builds/Debug.md` rebuilt to sha256
`0b176550f8df15173dfb8c65d8c31e2d376bf4ef8e27a1ee950e5bfac33f71be`,
identical to the determinism baseline. The tree is clean.

### ROOT CAUSE FOUND AND FIXED IN THE GENERATOR — 2026-08-03

`LEVEL_INFO_SIZE` was `0x100`. The real ROM record is **252 bytes**. The
walk therefore drifted 4 bytes per level, so `LevelInfoUW<n>` was read
`4*(n-1)` bytes late and every field landed at the wrong offset.

Byte-verified against live NES SRAM (`k_uw_map_*` in
`src/game/dungeon/uw_map_data.c`, captured by
`tools/parity/pause_golden/uw_capture_all_levels.lua`):

| Field | in-block offset | stride 252 @ PRG $193FC | stride 256 @ $19400 |
|---|---|---|---|
| `StartRoomId` (`$6BAD`) | 47 | `73 7d 7c 71 76 79 79 7e 76` ✅ | `01 ff ff 00 00 c0 00 20 ff` ❌ |
| `TriforceRoomId` (`$6BAE`) | 48 | matches all 9 ✅ | ❌ |
| `SubmenuMapRotation` (`$6BAB`) | 45 | matches all 9 ✅ | ❌ |
| `LevelNumber` (`$6BB1`) | 51 | `1 2 3 4 5 6 7 8 9` ✅ | garbage ❌ |

The record opens with its transfer-buffer descriptor (`3f 00 20` — PPU
palette RAM `$3F00`, length `$20`), which the 256-byte walk skipped
entirely. That skipped header is the whole 4-byte drift.

`FoeCounts` @36 reads `03 05 06 08` for **all nine dungeons** under the
corrected layout — so the committed value was right all along, and the
earlier suspicion that it was an L1 copy-paste was wrong. It is genuinely
uniform in Zelda 1.

Fix applied to `tools/extract_rooms.py`: advance the walk by 252 (the
real record size) while emitting 256 bytes per block, so the blob layout
and `level_info_install.c` are unchanged. Q1 LevelBlockAttrs verified
still byte-identical to `LevelBlockUW{1,2}Q1.dat` afterwards.

**The corrected data is NOT yet committed.** Regenerating changes what
the runtime installs at `$6B7E` for all nine dungeons — StartRoomId,
TriforceRoomId, BossRoomId, MapRotation, DeathPaletteSeries. Per RULE V1
that is a runtime change and needs a runtime probe, not a byte-diff
alone. Tree left at the known-good state: freshness 8/8, `Debug.md`
sha256 `0b176550...` unchanged.

This also explains why `uw_map_data.c` exists and says of itself
*"NOT derived from data/rooms/dungeons.c (whose ... regen diverges from
live NES)"*, and why `RoomRom/data/levelinfo_start_rooms.c` exists. Both
are workarounds for this single off-by-four. Fixing it at the source
should let both be retired.

### Status after the 2026-08-03 ROM runs

`python tools/builder/build.py <rom>` now regenerates every ROM-derived
asset, and the output matches the committed tree except for one file.

| File | Divergence |
|---|---|
| `data/rooms/dungeons.c` | **none** — LevelInfo fix committed (`542a5ea1`), reproduces exactly |
| `data/rooms/overworld.c` | **0 bytes** — line-ending churn only |
| `data/text/MANIFEST.json` | **none** — block set identical; key-ordering churn only |
| `data/misc/palettes.c` | **84 bytes** — the CRAM override cutover, below |

Fixed along the way, each verified against the real ROM:

- `extract_rooms.py` LevelInfo record size (`b5582ffb`, runtime-probed in
  `542a5ea1`).
- `extract_misc.py` now carries the three verified CRAM overrides
  (`32463018`) instead of losing them on every regeneration.
- `extract_frontend.py` / `extract_demo_text.py` merge the shared text
  manifest instead of clobbering it (`10c1dd48`) — that was the −319
  lines; a full run left 2 blocks of 47.

### The one remaining blocker — palette LUT cutover

`build.py` exits 3 on a single freshness sentinel, `bg_palette_blob`,
downstream of `data/misc/palettes.c`.

The generator is correct; the data is not cut over. The override applies
the three verified corrections everywhere the colors appear, not only the
two triforce entries that were patched by hand in `5f909fda`:

| Committed | Corrected | Occurrences |
|---|---|---|
| `$026C` blue-tint | `$004E` (`$17` brown) | 22 |
| `$0ACE` | `$046E` (`$36` orange) | 17 |
| `$0ACE` | `$08EE` (`$37` yellow) | 3 |

Why this is gated rather than just committed:
`tools/parity/cave_golden/cave_byte_diff.py` maps NES PALRAM to Genesis
CRAM **through this LUT**, so the 20/20 cave and 171/171 dungeon BG
byte-exact results were computed against the current values. Changing 42
colour words invalidates that evidence until the sweep is re-run, and the
NES goldens are not cached — it needs fresh captures across 20 caves and
171 rooms.

Closing it: re-run `tools/parity/cave_golden/run_full_diff.py` for caves
and UW with the override applied, require the same 20/20 and 171/171,
regenerate the `bg_palette_blob` sentinel, then commit the data. If the
sweep degrades, the override is wrong somewhere and the per-colour
evidence in `5f909fda` needs revisiting.

### Remaining to close PLAYABLE

1. Cut over the corrected LevelInfo data: regenerate `dungeons.c` +
   `overworld.c`, regen the `uw_collision` / `redux_roomrom` /
   `bg_sparse` sentinels, then **probe the runtime in BizHawk** to
   confirm all nine dungeons still load, start in the right room, and
   spawn the right boss. Only then commit the data.
2. Retire `levelinfo_start_rooms.c` and the `uw_map_data.c` StartRoomId
   workaround if the probe confirms the source is now correct.
3. Preserve the `fix_dungeons_q1_lba.py` header provenance comment in
   `extract_rooms.py`'s own output, so the generator documents its own
   guarantees instead of relying on a post-hoc patch.
4. Reconcile `extract_misc.py` output with `data/misc/palettes.c`
   (4 bytes).
5. Reconcile the text extractor with `data/text/MANIFEST.json` (319
   lines dropped — determine whether the manifest gained entries the
   extractor does not know about).
6. Re-run `python tools/builder/build.py <rom>`; require exit 0 and
   `check_generated_freshness` 8/8.
7. Then `from_scratch_gate.py <rom>` for byte-identical A/B.

Also found while probing: `fix_dungeons_q1_lba.py:39` parses the blob
with `text[text.find("{")+1:]`, but the header it writes itself contains
`LevelBlockUW{1,2}Q1.dat`. The first `{` is therefore inside a comment,
so the script cannot be re-run on its own output — it is documented
"Re-runnable" and is not.

This is the single highest-value gap in the project: until it closes,
"drag in your ROM and get a Genesis ROM" produces a *worse* ROM than the
repo builds, and no third party can reproduce `Debug.md` at all.

### CODE — CLOSED 2026-08-03.

Was RED: `build.py` wired 1 extractor of 12, and passed `--rom` to it —
a flag only `extract_nes_banks.py` accepts. The argparse-less scripts
silently ignored it and fell back to their own lookup, so the user's ROM
never reached them. `build.py:112` called its own dispatch a
"placeholder".

Fixed:

- All 11 ROM-relevant extractors wired, each with the calling convention
  probed from its source rather than assumed. Three conventions exist:
  `ZELDA_NES_ROM` env (8), `sys.argv[1]` (1), `--rom` (1), plus one that
  needs no ROM and reads the committed disassembly tree.
- `run_extractors()` sets `ZELDA_NES_ROM` for the subprocess environment,
  so the env-convention extractors see the ROM the user actually supplied
  instead of whatever sits at the repo-root fallback path.
- Four extractors that only had the hardcoded fallback
  (`extract_dat_sidecars`, `extract_demo_text`, `extract_frontend`,
  `extract_misc`) now honour `ZELDA_NES_ROM` like the rest.
- `extract_nes_banks.py:12` defaulted to an absolute path on one
  developer's machine — impossible in a shipped builder. Now env-then-
  repo-root.
- `extract_fs_assets.py` is documented as manual: it needs a live CHR-RAM
  dump from Zelda Redux, not the base ROM, so it cannot run unattended.
- `extractor_coverage_gate.py` guards against recurrence. Adding
  `tools/extract_foo.py` without wiring it turns the cell RED. Verified
  by adding a canary extractor: gate exited 1, naming it.

The CODE evidence hashes all 11 extractors plus `build.py`, so editing
any of them drops the cell to RED until re-verified.

### Still open beyond this system

`strict_build_check.py` has not been run against a tree with the
generated assets deleted. That belongs to PLAYABLE, since it needs a
real ROM to regenerate them.

## Tolerance

BEHAVIOR accepts zero deltas: the two builds must be byte-identical.
There is no accepted-divergence list for this system.
