# RoomRom S3 — Walk Animation + 4-Facing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Link animates while walking. Tracks 4 cardinal facings across input releases. Tile data sourced from `common_chr` at NES tile IDs captured live from BizHawk.

**Architecture:** Sprite module pre-uploads 32 tiles (4 facings × 2 frames × 4 tiles), per-tile hflip baked at upload time so render-side sprite attr always has `hflip=0`. main.c tracks face/frame/anim-tick; idle holds frame 0; period 8.

**Tech Stack:** SGDK 2.00, C, M68K, BizHawk Lua probes for tile-ID capture.

**Spec:** [2026-04-30-roomrom-s3-walk-animation-design.md](../specs/2026-04-30-roomrom-s3-walk-animation-design.md)

---

## File structure

| File | Status | Responsibility |
|---|---|---|
| `RoomRom/probe_nes_link_dirs.lua` | **create** (T1) | Drive Link in each direction in NES Zelda 1, dump OAM |
| `RoomRom/src/roomrom_sprites.h` | modify | + `link_face_t`, + `_set_link_pose` decl |
| `RoomRom/src/roomrom_sprites.c` | modify | + pose table, + `chr_upload_maybe_flip`, expand `_upload_chr`, + `_set_link_pose` |
| `RoomRom/src/main.c` | modify | + facing/frame state, anim-aware WALK body |
| `RoomRom/probe_roomrom_link_visible.lua` | modify | capture each facing |

---

## Task 1: Capture up/left/right tile IDs from live NES

**Files:**
- Create: `C:/tmp/probe_nes_link_dirs.lua` (staged probe; do not commit)

**Why:** Down already known. Need authoritative up/left/right tile IDs (and per-tile hflip pattern) to fill the spec's pose table.

- [ ] **Step 1: Write probe `C:/tmp/probe_nes_link_dirs.lua`.**

```lua
-- probe_nes_link_dirs.lua: boot Z1 to overworld, walk Link in each
-- direction for ~30 frames, dump OAM[16..23] (Link's slots) at each
-- frame so we can identify per-direction tile IDs and hflip flags.

local OUT = "C:/tmp"
local f = io.open(OUT .. "/nes_link_dirs.txt", "w")
local function logln(s) f:write(s .. "\n"); f:flush() end
local function logf(fmt, ...)
    local args = {...}
    for i = 1, select("#", ...) do if args[i] == nil then args[i] = "<nil>" end end
    local ok, m = pcall(string.format, fmt, table.unpack(args))
    f:write(ok and m or ("[fmt-err: "..tostring(m).."]"))
    f:flush()
end

local function read_dom(d, a)
    local ok = pcall(memory.usememorydomain, d); if not ok then return nil end
    local ok2, v = pcall(memory.read_u8, a); return ok2 and v or nil
end
local function u8sb(a) return read_dom("System Bus", a & 0xFFFF) or 0 end

local ROOM_ID, CUR_LEVEL, GAME_MODE = 0x00EB, 0x0010, 0x0012
local CUR_SAVE_SLOT, NAME_PROGRESS, ROOM_TRANS = 0x0016, 0x0421, 0x004C
local SAVE_ACTIVE0 = 0x0633

local function safe_set(p) local ok = pcall(function() joypad.set(p or {}, 1) end); if not ok then pcall(joypad.set, p or {}) end end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }
local function schedule(b, h, r) if input_state.hold_left>0 or input_state.release_left>0 then return end
    input_state.button=b; input_state.hold_left=h or 1; input_state.release_left=0; input_state.release_after=r or 4 end
local function build_pad()
    local p = {}
    if input_state.hold_left>0 and input_state.button then
        p[input_state.button]=true; p["P1 "..input_state.button]=true
        input_state.hold_left=input_state.hold_left-1
        if input_state.hold_left==0 then input_state.release_left=input_state.release_after end
    elseif input_state.release_left>0 then input_state.release_left=input_state.release_left-1 end
    return p
end

local function boot_to_overworld()
    local s = 1
    local last_name = u8sb(NAME_PROGRESS); local name_events = 0
    for _ = 1, 20000 do
        local mode = u8sb(GAME_MODE); local slot = u8sb(CUR_SAVE_SLOT); local name = u8sb(NAME_PROGRESS)
        if s == 1 then if mode == 0x01 then s = 2 else schedule("Start", 2, 3) end
        elseif s == 2 then if slot == 0x03 then s = 3 else schedule("Down", 1, 10) end
        elseif s == 3 then if mode == 0x0E then s = 4; last_name = name elseif mode == 0x01 then schedule("Start", 2, 14) end
        elseif s == 4 then if name ~= last_name then name_events = name_events + 1; last_name = name end
            if name_events >= 5 then s = 5 else schedule("A", 1, 10) end
        elseif s == 5 then if mode ~= 0x0E then s = 6 elseif slot ~= 0x03 then schedule("Select", 1, 10) else schedule("Start", 2, 14) end
        elseif s == 6 then if mode == 0x01 then s = 7 end
        elseif s == 7 then if mode ~= 0x01 then s = 6 else schedule("Start", 2, 14) end
        end
        safe_set(build_pad()); emu.frameadvance()
        if u8sb(CUR_LEVEL) == 0 and u8sb(GAME_MODE) == 0x05 and u8sb(ROOM_ID) == 0x77 and u8sb(ROOM_TRANS) == 0 then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

logln("=== NES Z1 Link direction tile dump ===")
local boot_ok = boot_to_overworld()
logf("boot_ok=%s frame=%d\n", tostring(boot_ok), emu.framecount())
if not boot_ok then f:close(); client.exit(); return end
for _ = 1, 60 do safe_set({}); emu.frameadvance() end
client.screenshot(OUT .. "/nes_link_dirs_spawn.png")

local function dump_oam(label)
    logf("\n--- %s ---\n", label)
    for s = 0, 63 do
        local y = read_dom("OAM", s*4) or 0xFF
        if y < 240 then
            local t = read_dom("OAM", s*4 + 1) or 0
            local a = read_dom("OAM", s*4 + 2) or 0
            local x = read_dom("OAM", s*4 + 3) or 0
            logf("  spr%02d Y=%3d X=%3d tile=$%02X attr=$%02X pal=%d hflip=%d vflip=%d\n",
                 s, y, x, t, a, a%4, math.floor(a/64)%2, math.floor(a/128)%2)
        end
    end
end

local function walk(dir, frames)
    for _ = 1, frames do
        local p = {}; p[dir] = true; p["P1 "..dir] = true
        safe_set(p); emu.frameadvance()
    end
    safe_set({})
end

-- Down (already known but confirm)
walk("Down", 24); dump_oam("WALK DOWN frame A")
walk("Down", 8);  dump_oam("WALK DOWN frame B")
client.screenshot(OUT .. "/nes_link_dirs_down.png")

-- Up
walk("Up", 24); dump_oam("WALK UP frame A")
walk("Up", 8);  dump_oam("WALK UP frame B")
client.screenshot(OUT .. "/nes_link_dirs_up.png")

-- Right
walk("Right", 24); dump_oam("WALK RIGHT frame A")
walk("Right", 8);  dump_oam("WALK RIGHT frame B")
client.screenshot(OUT .. "/nes_link_dirs_right.png")

-- Left
walk("Left", 24); dump_oam("WALK LEFT frame A")
walk("Left", 8);  dump_oam("WALK LEFT frame B")
client.screenshot(OUT .. "/nes_link_dirs_left.png")

logln("\nDONE")
f:close()
client.exit()
```

- [ ] **Step 2: Run the probe.**

```bash
cp "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/Legend of Zelda, The (USA).nes" /c/tmp/zelda1.nes
rm -f /c/tmp/nes_link_dirs_*
powershell -Command "Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList '--lua=C:\tmp\probe_nes_link_dirs.lua','C:\tmp\zelda1.nes' -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'"
sleep 60
```

- [ ] **Step 3: Read the dump and identify Link's OAM slots in each direction.**

`Read C:/tmp/nes_link_dirs.txt`. Expect 8 sections (4 dirs × 2 frames). For each, find the two adjacent sprites at the same Y (or Y+8 for 8x16 mode) — those are Link's two visible halves.

- [ ] **Step 4: Fill the pose table values.**

For each direction × frame, record:
- 4 NES tile IDs (TL, BL, TR, BR — by inferring 8x16 sprite mode: tile and tile+1 are paired)
- Per-tile hflip mask: any sprite with attr bit 6 set on a particular half implies that half's right-column tiles need pre-hflip at upload.

Output: an updated `link_poses[8]` array literal ready to paste into roomrom_sprites.c. Save it to `/c/tmp/link_poses_filled.c.txt` for the next task.

- [ ] **Step 5: No commit (probe is staged-only, dumps in /c/tmp).**

---

## Task 2: Update header

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.h`

- [ ] **Step 1: Add the enum + new decl.**

Replace:
```c
void roomrom_sprites_upload_chr(void);    /* one-shot at boot */
void roomrom_sprites_load_palette(void);  /* call after every load_room() */
void roomrom_sprites_spawn_link(short x, short y);
void roomrom_sprites_set_link_pos(short x, short y);
```
with:
```c
typedef enum {
    LINK_FACE_DOWN  = 0,
    LINK_FACE_UP    = 1,
    LINK_FACE_LEFT  = 2,
    LINK_FACE_RIGHT = 3
} link_face_t;

void roomrom_sprites_upload_chr(void);    /* one-shot at boot */
void roomrom_sprites_load_palette(void);  /* call after every load_room() */
void roomrom_sprites_spawn_link(short x, short y);
void roomrom_sprites_set_link_pos(short x, short y);
void roomrom_sprites_set_link_pose(short x, short y,
                                   link_face_t face, unsigned char frame);
```

- [ ] **Step 2: Commit.**

```
git -C "<worktree>" add RoomRom/src/roomrom_sprites.h
git -C "<worktree>" commit -m "RoomRom: add link_face_t + _set_link_pose decl"
```

(HEREDOC + Co-Authored-By trailer.)

---

## Task 3: Sprite module — pose table + multi-tile upload + pose setter

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c`

- [ ] **Step 1: Replace the existing constants + upload + setter with the pose-aware version.**

Read the current file end-to-end first.

Replace the section from `#define LINK_VRAM_TILE ...` through end-of-file with this complete replacement:

```c
#define LINK_VRAM_TILE          (COMMON_VRAM_TILE_BASE + COMMON_BLOCK_TILE_COUNT)
#define LINK_TILES_PER_POSE     4u
#define LINK_POSE_COUNT         8u   /* 4 facings x 2 frames */

typedef struct {
    unsigned char nes_ids[4];     /* TL, BL, TR, BR (Genesis 2x2 column-major) */
    unsigned char per_tile_hflip; /* bitmask: bit i = flip tile i at upload */
} link_pose_def_t;

/* Pose definitions. Down values ground-truth from S1 /spritefix OAM dump.
 * Up/left/right values from S3 T1 NES live capture (see plan).
 *
 * NES walk-down right column is achieved by per-sprite hflip on the right
 * half (tiles $08/$09 horizontally flipped). On Genesis we bake the flip
 * into the tile bytes at upload, so render-side hflip is always 0. */
static const link_pose_def_t link_poses[LINK_POSE_COUNT] = {
    /* DOWN  frame 0 */ { {0x58u, 0x59u, 0x0Au, 0x0Bu}, 0x0u },
    /* DOWN  frame 1 */ { {0x5Au, 0x5Bu, 0x08u, 0x09u}, 0xCu },
    /* UP    frame 0 */ { {/* T1 */}, /* T1 */ },
    /* UP    frame 1 */ { {/* T1 */}, /* T1 */ },
    /* LEFT  frame 0 */ { {/* T1 */}, /* T1 */ },
    /* LEFT  frame 1 */ { {/* T1 */}, /* T1 */ },
    /* RIGHT frame 0 */ { {/* T1 */}, /* T1 */ },
    /* RIGHT frame 1 */ { {/* T1 */}, /* T1 */ },
};

static unsigned short nes_to_cram(unsigned char nes_idx)
{
    unsigned short off = (unsigned short)(nes_idx & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

/* Horizontally flip a single Genesis 4bpp 8x8 tile (32 bytes) in place. */
static void hflip_tile_inplace(unsigned char *t)
{
    unsigned char r;
    for (r = 0; r < 8; r++) {
        unsigned char b0 = t[r*4 + 0], b1 = t[r*4 + 1],
                      b2 = t[r*4 + 2], b3 = t[r*4 + 3];
        /* swap nibbles within each byte AND reverse byte order across the row */
        t[r*4 + 0] = (unsigned char)(((b3 & 0xF0u) >> 4) | ((b3 & 0x0Fu) << 4));
        t[r*4 + 1] = (unsigned char)(((b2 & 0xF0u) >> 4) | ((b2 & 0x0Fu) << 4));
        t[r*4 + 2] = (unsigned char)(((b1 & 0xF0u) >> 4) | ((b1 & 0x0Fu) << 4));
        t[r*4 + 3] = (unsigned char)(((b0 & 0xF0u) >> 4) | ((b0 & 0x0Fu) << 4));
    }
}

void roomrom_sprites_upload_chr(void)
{
    /* OW enemy sprite block (kept for later S-slices). */
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);

    /* Common gameplay sprite block (Link, sword, hearts). */
    render_chr_upload((unsigned short)(COMMON_VRAM_TILE_BASE * 32u),
                      common_chr, COMMON_CHR_BYTES);

    /* Pre-upload all 8 Link poses (32 tiles) into LINK_VRAM_TILE region.
     * Per-tile hflip baked here so render-side never needs sprite hflip. */
    {
        unsigned char p, t;
        unsigned char buf[32];
        for (p = 0; p < LINK_POSE_COUNT; p++) {
            for (t = 0; t < LINK_TILES_PER_POSE; t++) {
                unsigned short nes_off = (unsigned short)link_poses[p].nes_ids[t] * 32u;
                unsigned char i;
                for (i = 0; i < 32; i++) buf[i] = common_chr[nes_off + i];
                if (link_poses[p].per_tile_hflip & (1u << t)) {
                    hflip_tile_inplace(buf);
                }
                render_chr_upload((unsigned short)((LINK_VRAM_TILE + p*LINK_TILES_PER_POSE + t) * 32u),
                                  buf, 32u);
            }
        }
    }
}

void roomrom_sprites_load_palette(void)
{
    unsigned short pal16[16];
    unsigned char i;
    for (i = 0; i < 16; i++) pal16[i] = 0;
    pal16[0] = nes_to_cram(0x0Fu);
    pal16[1] = nes_to_cram(0x29u);
    pal16[2] = nes_to_cram(0x27u);
    pal16[3] = nes_to_cram(0x17u);
    render_load_palette(3 /* PAL3 */, pal16);
}

void roomrom_sprites_set_link_pose(short x, short y,
                                   link_face_t face, unsigned char frame)
{
    unsigned short pose_idx = (unsigned short)face * 2u + (unsigned short)frame;
    unsigned short tile = LINK_VRAM_TILE + pose_idx * LINK_TILES_PER_POSE;
    VDP_setSpriteFull(0,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 1, 0, 0, tile),
                      0);
    VDP_updateSprites(1, DMA);
}

void roomrom_sprites_spawn_link(short x, short y)
{
    roomrom_sprites_set_link_pose(x, y, LINK_FACE_DOWN, 0u);
}

void roomrom_sprites_set_link_pos(short x, short y)
{
    roomrom_sprites_set_link_pose(x, y, LINK_FACE_DOWN, 0u);
}
```

- [ ] **Step 2: Substitute the T1-captured pose values.**

Open `/c/tmp/link_poses_filled.c.txt` (from T1 step 4). Paste the 6 missing pose entries into the array, replacing the `/* T1 */` placeholders. Each entry should be `{ {0xXX, 0xXX, 0xXX, 0xXX}, 0x_ }`.

- [ ] **Step 3: Build.**

`cmd.exe /c "cd /d \"...\\RoomRom\" && build.bat"`. Expected clean.

If build fails, fix narrowly.

- [ ] **Step 4: Commit.**

```
git -C "..." add RoomRom/src/roomrom_sprites.c
git -C "..." commit -m "$(cat <<'EOF'
RoomRom S3: pose-aware sprite module (8 poses, 32 VRAM tiles)

Pre-uploads 4 facings x 2 frames into LINK_VRAM_TILE..+31, with per-tile
hflip baked at upload time so render is a single sprite-cache write
(hflip=0). Pose table indices: face*2 + frame. _spawn_link and
_set_link_pos delegate to (DOWN, 0).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Anim-aware main loop

**Files:**
- Modify: `RoomRom/src/main.c`

- [ ] **Step 1: Add facing/frame/tick state.**

Find:
```c
static short s_link_x = 128;
static short s_link_y =  88;
```
Add immediately after:
```c
static link_face_t s_link_face = LINK_FACE_DOWN;
static u8          s_link_frame = 0u;
static u8          s_link_anim_tick = 0u;
#define LINK_ANIM_PERIOD 8u
```

- [ ] **Step 2: Replace the WALK-mode body in the main loop.**

Find:
```c
        } else {
            /* WALK: D-pad held -> 1 px/frame motion with playfield clamp. */
            if (joy & BUTTON_LEFT)  s_link_x--;
            if (joy & BUTTON_RIGHT) s_link_x++;
            if (joy & BUTTON_UP)    s_link_y--;
            if (joy & BUTTON_DOWN)  s_link_y++;
            if (s_link_x < 0)   s_link_x = 0;
            if (s_link_x > 240) s_link_x = 240;
            if (s_link_y < 56)  s_link_y = 56;
            if (s_link_y > 208) s_link_y = 208;
            roomrom_sprites_set_link_pos(s_link_x, s_link_y);
        }
```

Replace with:
```c
        } else {
            /* WALK: D-pad held -> 1 px/frame motion + facing + anim tick. */
            u16 dir = joy & (BUTTON_LEFT|BUTTON_RIGHT|BUTTON_UP|BUTTON_DOWN);

            /* Facing: H wins over V when both pressed. */
            if      (dir & BUTTON_LEFT)  s_link_face = LINK_FACE_LEFT;
            else if (dir & BUTTON_RIGHT) s_link_face = LINK_FACE_RIGHT;
            else if (dir & BUTTON_UP)    s_link_face = LINK_FACE_UP;
            else if (dir & BUTTON_DOWN)  s_link_face = LINK_FACE_DOWN;

            if (dir) {
                if (++s_link_anim_tick >= LINK_ANIM_PERIOD) {
                    s_link_frame ^= 1u;
                    s_link_anim_tick = 0u;
                }
            } else {
                s_link_frame = 0u;
                s_link_anim_tick = 0u;
            }

            if (joy & BUTTON_LEFT)  s_link_x--;
            if (joy & BUTTON_RIGHT) s_link_x++;
            if (joy & BUTTON_UP)    s_link_y--;
            if (joy & BUTTON_DOWN)  s_link_y++;
            if (s_link_x < 0)   s_link_x = 0;
            if (s_link_x > 240) s_link_x = 240;
            if (s_link_y < 56)  s_link_y = 56;
            if (s_link_y > 208) s_link_y = 208;

            roomrom_sprites_set_link_pose(s_link_x, s_link_y,
                                          s_link_face, s_link_frame);
        }
```

- [ ] **Step 3: Build.**

Expected clean.

- [ ] **Step 4: Commit.**

```
git -C "..." add RoomRom/src/main.c
git -C "..." commit -m "$(cat <<'EOF'
RoomRom S3: main loop tracks facing + anim tick

WALK mode now tracks s_link_face (sticky across input release),
s_link_frame (0/1 alternating every 8 frames while moving), and
s_link_anim_tick. Idle holds frame 0 of last facing. Diagonal D-pad =
H over V priority. set_link_pose replaces set_link_pos in the WALK
path. TELEPORT mode unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Probe extension

**Files:**
- Modify: `RoomRom/probe_roomrom_link_visible.lua`

- [ ] **Step 1: Replace probe contents to capture each facing in turn.**

```lua
-- probe_roomrom_link_visible.lua: verify S3 walk anim across 4 facings.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or ""
if OUT == "" or OUT == nil then OUT = "." end
local OUTDIR = OUT .. "/RoomRom/out"

local function wait(n) for _=1,n do emu.frameadvance() end end
local function hold(btn, frames)
    for _=1,frames do joypad.set({[btn]=true},1); emu.frameadvance() end
    joypad.set({},1); wait(10)
end
local function press(btn)
    for _=1,3 do joypad.set({[btn]=true},1); emu.frameadvance() end
    joypad.set({},1); wait(60)
end

wait(180)
client.screenshot(OUTDIR .. "/probe_s3_00_idle_down.png")

hold("Right", 24); client.screenshot(OUTDIR .. "/probe_s3_01_walk_right_a.png")
hold("Right",  8); client.screenshot(OUTDIR .. "/probe_s3_02_walk_right_b.png")
wait(40);          client.screenshot(OUTDIR .. "/probe_s3_03_idle_right.png")

hold("Down",  24); client.screenshot(OUTDIR .. "/probe_s3_04_walk_down.png")
hold("Up",    24); client.screenshot(OUTDIR .. "/probe_s3_05_walk_up.png")
hold("Left",  24); client.screenshot(OUTDIR .. "/probe_s3_06_walk_left.png")
wait(40);          client.screenshot(OUTDIR .. "/probe_s3_07_idle_left.png")

press("X");                              -- toggle to TELEPORT
press("Right"); client.screenshot(OUTDIR .. "/probe_s3_08_teleport.png")

print("S3 probe done")
client.exit()
```

- [ ] **Step 2: Commit.**

```
git -C "..." add RoomRom/probe_roomrom_link_visible.lua
git -C "..." commit -m "RoomRom S3: probe captures each facing + idle face + TELEPORT"
```

---

## Task 6: Run probe + visual verify

**Files:** none modified.

- [ ] **Step 1: Stage ROM + probe to /c/tmp, launch BizHawk per bizhawkScript skill.**

- [ ] **Step 2: Read each screenshot, confirm:**
  - `00_idle_down.png` — Link facing down standstill
  - `01_walk_right_a.png` — Link mid-walk facing right (frame A)
  - `02_walk_right_b.png` — Link facing right, alternate frame (legs swapped)
  - `03_idle_right.png` — Link standstill facing right (last facing held)
  - `04_walk_down.png` — Link facing down, walking
  - `05_walk_up.png` — Link facing up
  - `06_walk_left.png` — Link facing left, walking (mirrored)
  - `07_idle_left.png` — standstill facing left
  - `08_teleport.png` — TELEPORT mode jumped Link's room

- [ ] **Step 3: Cross-check vs `/c/tmp/nes_link_dirs_*.png` from T1 — same shape, allowing CRAM color quantization.**

- [ ] **Step 4: If any failure, fix narrowly and re-run.**

Common failures:
- Wrong tile shows for a facing → pose table value from T1 was wrong; re-check OAM dump and update.
- Hflip wrong (mirror inverted) → flip the `per_tile_hflip` bit for the offending tile.
- Anim too fast/slow → tweak `LINK_ANIM_PERIOD`.
- Link disappears after pose change → confirm `_set_link_pose` writes to sprite slot 0 and DMAs.

---

## Task 7: Tag s3-closed + final review

- [ ] **Step 1: Tag.**

```
git -C "..." tag -a roomrom-s3-closed -m "RoomRom S3 closed: walk anim + 4-facing"
```

- [ ] **Step 2: Dispatch code-reviewer over `roomrom-s2-closed..HEAD`.**

---

## Self-review

**Spec coverage:**
- Spec § Pose model → Tasks 2, 3
- Spec § VRAM layout → Task 3
- Spec § Per-tile hflip baked → Task 3 (`hflip_tile_inplace` + `link_poses[].per_tile_hflip`)
- Spec § main.c additions → Task 4
- Spec § Verification → Tasks 5, 6

**Placeholder scan:**
- Pose table cells `/* T1 */` are placeholders by design — Task 1 fills them. They are explicitly resolved in Task 3 step 2 before the build attempt. No silent placeholders.

**Type/symbol consistency:**
- `link_face_t` declared in Task 2, used in Task 3 (`_set_link_pose` impl) and Task 4 (`s_link_face`). Match.
- `LINK_TILES_PER_POSE = 4`, `LINK_POSE_COUNT = 8` used consistently across upload loop, pose-index calc, and VRAM allocation (32 tiles total).
- `LINK_ANIM_PERIOD = 8u` matches spec § Architecture cadence.

No issues.
