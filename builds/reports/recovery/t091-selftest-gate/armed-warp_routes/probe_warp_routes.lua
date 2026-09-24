-- T-091: boot self-tests in roomrom_debug_enter run only when armed:
-- $FF73F8 'R','P', flags $FF73FA |= ROOMROM_DEBUG_PROBE_SELFTEST ($08)
-- (RoomRom/src/roomrom_debug_runtime.h). Re-armed every frame because
-- SGDK startup clears work RAM.
event.onframestart(function()
    pcall(memory.write_u8, 0xFF73F8, 0x52, "M68K BUS")
    pcall(memory.write_u8, 0xFF73F9, 0x50, "M68K BUS")
    pcall(memory.write_u8, 0xFF73FA, 0x08, "M68K BUS")
end, "t091_selftest_arm")

-- probe_warp_routes.lua — Phase E warp routes static dispatch reader.
--
-- Reads the 136-byte result block published by warp_routes_probe_run() at
-- $FF7800 + writes to tools/parity/warp_routes_gen_dump.txt. The Python
-- differ in tools/parity/diff_warp_routes.py then byte-diffs against
-- tools/parity/warp_routes_expected.json (the NES-extracted oracle).
--
-- USAGE:
--   1. Build Debug.md (Phase E probe TU compiles + boot-time call wired
--      in RoomRom/src/main.c after level_info_install_ow runs).
--   2. Boot Debug.md in BizHawk genplus-gx core. At title, hit A+B+C to
--      enter the Debug gameplay loop. Probe block fills during init
--      before gameplay tick. This script auto-detects the magic bytes
--      and dumps once. No further user input needed.
--   3. Confirm output at tools/parity/warp_routes_gen_dump.txt.
--   4. Run python tools/parity/diff_warp_routes.py to score the sweep.

local PROBE_BASE       = 0x7C00   -- $FF7C00 in 68K RAM domain
local PROBE_HEADER_LEN = 8
local PROBE_ROOMS      = 128
local PROBE_TOTAL      = PROBE_HEADER_LEN + PROBE_ROOMS * 3  -- cid + diff + direct
local ATTR_B_OFFSET    = PROBE_HEADER_LEN + PROBE_ROOMS       -- 136 = diff
local DIRECT_OFFSET    = 264                                  -- 264 = direct blob byte
local OUT_PATH         = "C:\\tmp\\warp_routes_gen_dump.txt"
local MAGIC_W          = 0x57    -- 'W'
local MAGIC_R          = 0x52    -- 'R'

local function read_block()
    memory.usememorydomain("68K RAM")
    local bytes = {}
    for i = 0, PROBE_TOTAL - 1 do
        bytes[i + 1] = memory.read_u8(PROBE_BASE + i)
    end
    return bytes
end

local function magic_present(bytes)
    return bytes[1] == MAGIC_W and bytes[2] == MAGIC_R
end

-- Wait up to 900 frames (15 s at 60 fps) for the probe to publish.
-- Press A+B+C every 30 frames for the first 300 frames to navigate
-- title -> debug entry regardless of which exact frame the title accepts.
local published = false
local final_frame = 0
for frame = 1, 900 do
    -- Press chord every 30 frames between frame 30 and 300 (300 frames =
    -- 5 s; covers any title-screen variation). Release on other frames.
    if frame >= 30 and frame <= 300 and (frame % 30) == 0 then
        joypad.set({["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true})
    end
    emu.frameadvance()
    local b = read_block()
    if magic_present(b) then
        published = true
        final_frame = frame
        break
    end
end

local b = read_block()
final_frame = final_frame == 0 and 900 or final_frame
local out = io.open(OUT_PATH, "w")
out:write(string.format("# warp_routes_probe dump — Phase E Genesis-side\n"))
out:write(string.format("# published_at_frame: %d  (published=%s)\n",
                       final_frame, tostring(published)))
out:write(string.format("# magic:        $%02X $%02X (expect $57 $52 = 'WR')\n",
                       b[1], b[2]))
out:write(string.format("# version:      $%02X\n", b[3]))
out:write(string.format("# no_warp_count:$%02X (%d)\n", b[4], b[4]))
out:write(string.format("# dungeon_count:$%02X (%d)\n", b[5], b[5]))
out:write(string.format("# cave_count:   $%02X (%d)\n", b[6], b[6]))
out:write(string.format("# reserved:     $%02X $%02X\n", b[7], b[8]))
out:write("#\n")
out:write("# Per-room results (1 byte per OW room id 0x00..0x7F):\n")
out:write("# value 0   = no_warp OR dungeon (caller falls through)\n")
out:write("# value !=0 = cave_id ($6A..$7D)\n")
out:write("#\n")
for room = 0, 127 do
    local cid    = b[PROBE_HEADER_LEN + 1 + room]
    local diff   = b[ATTR_B_OFFSET    + 1 + room]
    local direct = b[DIRECT_OFFSET    + 1 + room]
    -- ow_meta value = direct XOR diff
    local meta   = direct ~ diff
    out:write(string.format("room $%02X direct=$%02X meta=$%02X diff=$%02X cid=$%02X\n",
                            room, direct, meta, diff, cid))
end
out:close()
print(string.format("warp_routes_probe dump -> %s (no_warp=%d dungeon=%d cave=%d)",
                    OUT_PATH, b[4], b[5], b[6]))
client.exit()
