-- Focused Genesis probe for the real OW room $37 -> Level 1 entrance path.
-- Boots Debug.md, enters gameplay, teleports to OW $37, places Link on the
-- entrance tile, then verifies the natural coordinator routes to UW L1.

local OUT = "C:\\tmp\\l1_ow_entrance_probe.txt"

local OFF_SCENE = 0x0285       -- s_scene enum low byte
local OFF_MODE = 0x0281        -- s_mode enum low byte
local OFF_ROOM = 0x0041        -- s_room_id
local OFF_IN_GAMEPLAY = 0x0278
local OFF_GRID_OFFSET = 0x0272
local OFF_UET = 0x026E
local OFF_LINK_X = 0x15F8      -- players[0].x, current Debug.out
local OFF_LINK_Y = 0x15FA      -- players[0].y
local PROBE_CTRL = 0x73F8
local MIRROR = 0x7200

local SCENE_OW = 0
local SCENE_UW = 1
local L1_ENTRANCE_X = 120

local function r8(off) return memory.read_u8(off, "68K RAM") end
local function w8(off, v) memory.write_u8(off, v & 0xFF, "68K RAM") end
local function nes_r8(addr) return r8(0x8000 + addr) end

local function write_be16(off, v)
    w8(off, (v >> 8) & 0xFF)
    w8(off + 1, v & 0xFF)
end

local function read_scene() return r8(OFF_SCENE) end
local function read_mode() return r8(OFF_MODE) end
local function read_room() return r8(OFF_ROOM) end

local function press(buttons) joypad.set(buttons) end

local function step(n)
    for _ = 1, n do
        emu.frameadvance()
    end
end

local function press_for(buttons, frames)
    press(buttons)
    emu.frameadvance()
    press({})
    step(math.max(0, frames - 1))
end

local function boot_to_gameplay()
    for frame = 1, 1500 do
        if frame >= 30 and frame <= 600 and (frame % 30) == 0 then
            press({["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true})
        end
        emu.frameadvance()
        if r8(OFF_IN_GAMEPLAY) == 1 then
            press({})
            step(60)
            return true
        end
    end
    return false
end

local function ensure_teleport_mode(want_on)
    local want = want_on and 1 or 0
    if read_mode() ~= want then
        press_for({["P1 X"] = true}, 8)
    end
end

local function teleport_step(dir)
    local btn = ({left="P1 Left", right="P1 Right", up="P1 Up", down="P1 Down"})[dir]
    press_for({[btn] = true}, 16)
end

local function navigate_to_room(target)
    ensure_teleport_mode(true)
    for _ = 1, 64 do
        local cur = read_room()
        if cur == target then break end
        local cc, cr = cur & 0x0F, (cur >> 4) & 0x07
        local tc, tr = target & 0x0F, (target >> 4) & 0x07
        if cc > tc then teleport_step("left")
        elseif cc < tc then teleport_step("right")
        elseif cr > tr then teleport_step("up")
        elseif cr < tr then teleport_step("down")
        else break end
    end
    ensure_teleport_mode(false)
    step(60)
end

local function force_mode_walk()
    w8(OFF_MODE - 3, 0)
    w8(OFF_MODE - 2, 0)
    w8(OFF_MODE - 1, 0)
    w8(OFF_MODE, 0)
end

local function arm_heavy_mirror()
    w8(PROBE_CTRL, 0x52)
    w8(PROBE_CTRL + 1, 0x50)
    w8(PROBE_CTRL + 2, 0x01)
end

local function place_link_on_l1_entrance()
    write_be16(OFF_LINK_X, L1_ENTRANCE_X)
    write_be16(OFF_LINK_Y, 117)
    w8(OFF_GRID_OFFSET, 0)
    w8(OFF_UET, 0)
    force_mode_walk()
end

local function place_link_south_of_l1_entrance()
    write_be16(OFF_LINK_X, L1_ENTRANCE_X)
    write_be16(OFF_LINK_Y, 133)
    w8(OFF_GRID_OFFSET, 0)
    w8(OFF_UET, 0)
    force_mode_walk()
end

local function read_be16(off)
    local hi = r8(off)
    local lo = r8(off + 1)
    local v = (hi << 8) | lo
    if v >= 0x8000 then v = v - 0x10000 end
    return v
end

local function read_raw_tile(col, row)
    return nes_r8(0x6530 + col * 0x16 + row)
end

local function find_warp_tiles()
    local out = {}
    for row = 0, 21 do
        for col = 0, 31 do
            local t = read_raw_tile(col, row)
            if t == 0x24 or t == 0x88 or (t >= 0x70 and t <= 0x73) then
                out[#out + 1] = { col = col, row = row, tile = t }
            end
        end
    end
    return out
end

local function read_probe_summary()
    return {
        scene = read_scene(),
        scene_b0 = r8(OFF_SCENE - 3),
        scene_b1 = r8(OFF_SCENE - 2),
        scene_b2 = r8(OFF_SCENE - 1),
        scene_b3 = r8(OFF_SCENE),
        room = read_room(),
        gm = nes_r8(0x0012),
        dispatch_last_song = r8(0x0002),
        dispatch_last_scene = r8(0x0003),
        dispatch_last_gm = r8(0x0004),
        cur_level = nes_r8(0x0010),
        song = memory.read_u8(0xE000, "68K RAM"),
        song_req = memory.read_u8(0xE001, "68K RAM"),
        mirror_magic0 = r8(MIRROR),
        mirror_magic1 = r8(MIRROR + 1),
        mirror_scene = r8(MIRROR + 4),
        mirror_room = r8(MIRROR + 5),
        mirror_stable = r8(MIRROR + 18),
        mirror_tile = r8(MIRROR + 21),
        mirror_save_src = r8(MIRROR + 23),
        mirror_save_tile = r8(MIRROR + 25),
        mirror_dest_level = r8(MIRROR + 31),
        mirror_dest_room = r8(MIRROR + 33),
        xgm_owns = memory.read_u8(0xE02C, "68K RAM")
    }
end

local log = io.open(OUT, "w")
local function logf(fmt, ...)
    log:write(string.format(fmt, ...), "\n")
    log:flush()
end

if not boot_to_gameplay() then
    logf("FAIL boot scene=%02X room=%02X in_gameplay=%02X", read_scene(), read_room(), r8(OFF_IN_GAMEPLAY))
    log:close()
    client.exit()
    return
end

arm_heavy_mirror()
logf("boot scene=%02X room=%02X mode=%02X", read_scene(), read_room(), read_mode())
navigate_to_room(0x37)
force_mode_walk()
logf("after_nav scene=%02X room=%02X mode=%02X", read_scene(), read_room(), read_mode())

local warp_tiles = find_warp_tiles()
for i, wt in ipairs(warp_tiles) do
    logf("warp_tile[%d] col=%02X row=%02X tile=%02X", i, wt.col, wt.row, wt.tile)
end

local walk_triggered = false
local trigger_frame = 0

place_link_south_of_l1_entrance()
logf("walk_start scene=%02X room=%02X mode=%02X x=%d y=%d",
    read_scene(), read_room(), read_mode(), read_be16(OFF_LINK_X), read_be16(OFF_LINK_Y))

for f = 1, 240 do
    arm_heavy_mirror()
    press({["P1 Up"] = true})
    emu.frameadvance()
    local s = read_probe_summary()
    if f <= 10 or s.scene == SCENE_UW or (f % 15) == 0 then
        logf("walk_f=%03d scene=%02X room=%02X level=%02X x=%d y=%d grid=%02X tile=%02X destL=%02X destR=%02X",
            f, s.scene, s.room, s.cur_level, read_be16(OFF_LINK_X),
            read_be16(OFF_LINK_Y), r8(OFF_GRID_OFFSET), s.mirror_tile,
            s.mirror_dest_level, s.mirror_dest_room)
    end
    if s.scene == SCENE_UW then
        walk_triggered = true
        trigger_frame = f
        break
    end
end
press({})
if read_scene() ~= SCENE_UW then
    logf("walk_attempt_failed; retrying direct aligned entrance tile")
    place_link_on_l1_entrance()
    for f = 1, 180 do
        arm_heavy_mirror()
        place_link_on_l1_entrance()
        emu.frameadvance()
        local s = read_probe_summary()
        if f <= 5 or s.scene == SCENE_UW or (f % 30) == 0 then
            logf("snap_f=%03d scene=%02X room=%02X level=%02X tile=%02X src=%02X destL=%02X destR=%02X song=%02X req=%02X owns=%02X",
                f, s.scene, s.room, s.cur_level, s.mirror_tile, s.mirror_save_src,
                s.mirror_dest_level, s.mirror_dest_room, s.song, s.song_req, s.xgm_owns)
        end
        if s.scene == SCENE_UW then break end
    end
end
for f = 1, 30 do
    arm_heavy_mirror()
    emu.frameadvance()
    local s = read_probe_summary()
    if f <= 10 or (f % 10) == 0 then
        logf("post_f=%03d scene=%02X gm=%02X room=%02X song=%02X req=%02X owns=%02X lastSong=%02X lastScene=%02X lastGm=%02X",
            f, s.scene, s.gm, s.room, s.song, s.song_req, s.xgm_owns,
            s.dispatch_last_song, s.dispatch_last_scene, s.dispatch_last_gm)
    end
end
local final = read_probe_summary()
local ok = walk_triggered and trigger_frame <= 60 and final.scene == SCENE_UW and final.room == 0x73 and final.cur_level == 0x01
logf("FINAL verdict=%s trigger_frame=%03d scene=%02X room=%02X level=%02X song=%02X req=%02X owns=%02X save_src=%02X save_tile=%02X destL=%02X destR=%02X",
    ok and "PASS" or "FAIL", trigger_frame, final.scene, final.room, final.cur_level,
    final.song, final.song_req, final.xgm_owns, final.mirror_save_src,
    final.mirror_save_tile, final.mirror_dest_level, final.mirror_dest_room)
logf("FINAL scene_bytes=%02X %02X %02X %02X",
    final.scene_b0, final.scene_b1, final.scene_b2, final.scene_b3)
log:close()
client.exit()
