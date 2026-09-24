-- T-091: boot self-tests in roomrom_debug_enter run only when armed:
-- $FF73F8 'R','P', flags $FF73FA |= ROOMROM_DEBUG_PROBE_SELFTEST ($08)
-- (RoomRom/src/roomrom_debug_runtime.h). Re-armed every frame because
-- SGDK startup clears work RAM.
event.onframestart(function()
    pcall(memory.write_u8, 0xFF73F8, 0x52, "M68K BUS")
    pcall(memory.write_u8, 0xFF73F9, 0x50, "M68K BUS")
    pcall(memory.write_u8, 0xFF73FA, 0x08, "M68K BUS")
end, "t091_selftest_arm")

-- probe_dungeon_roundtrip.lua — Phase F reader.
--
-- Waits for magic 'WF' at $FF7DB0, then dumps the 80-byte block to
-- C:\tmp\dungeon_roundtrip_gen_dump.txt and exits. The dungeon
-- round-trip probe TU (src/game/world/probes/dungeon_roundtrip_probe.c)
-- publishes its results during the RoomRom debug-enter boot path
-- after enemy/options probes; this reader auto-presses A+B+C every
-- 30 frames to advance past title.
--
-- Output schema (see dungeon_roundtrip_probe.h):
--   $FF7DB0..$FF7DB1  magic 'W' 'F'
--   $FF7DB2           version = 1
--   $FF7DB3           rows_ok count
--   $FF7DB4..$FF7DB7  reserved
--   $FF7DB8..$FF7DFF  18 rows × 4 bytes (dest_scene, dest_level,
--                                       dest_room_id, pass_flags)

local PROBE_BASE       = 0x7DB0     -- $FF7DB0 in 68K RAM domain
local PROBE_HEADER_LEN = 8
local PROBE_ROWS       = 18
local PROBE_ROW_BYTES  = 4
local PROBE_TOTAL      = PROBE_HEADER_LEN + PROBE_ROWS * PROBE_ROW_BYTES
local OUT_PATH         = "C:\\tmp\\dungeon_roundtrip_gen_dump.txt"
local MAGIC_W          = 0x57    -- 'W'
local MAGIC_F          = 0x46    -- 'F'

local function read_block()
    memory.usememorydomain("68K RAM")
    local bytes = {}
    for i = 0, PROBE_TOTAL - 1 do
        bytes[i + 1] = memory.read_u8(PROBE_BASE + i)
    end
    return bytes
end

local function magic_present(bytes)
    return bytes[1] == MAGIC_W and bytes[2] == MAGIC_F
end

local published = false
local final_frame = 0
for frame = 1, 900 do
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
out:write(string.format("# dungeon_roundtrip_probe dump — Phase F\n"))
out:write(string.format("# published_at_frame: %d  (published=%s)\n",
                       final_frame, tostring(published)))
out:write(string.format("# magic:    $%02X $%02X (expect $57 $46 = 'WF')\n",
                       b[1], b[2]))
out:write(string.format("# version:  $%02X\n", b[3]))
out:write(string.format("# rows_ok:  $%02X (%d of 18)\n", b[4], b[4]))
out:write(string.format("# reserved: $%02X $%02X $%02X $%02X\n",
                       b[5], b[6], b[7], b[8]))
out:write("#\n")
out:write("# Per-row (level, quest) results. row_idx = (level-1)*2 + (quest-1):\n")
out:write("# flags bit 0=manifest_hit bit 1=stair_found bit 2=detect_fired bit 3=dest_match\n")
out:write("#\n")
out:write("# L Q  dest_scene dest_level dest_room  flags\n")
for row = 0, PROBE_ROWS - 1 do
    local off = PROBE_HEADER_LEN + 1 + row * PROBE_ROW_BYTES
    local dest_scene  = b[off + 0]
    local dest_level  = b[off + 1]
    local dest_room   = b[off + 2]
    local pass_flags  = b[off + 3]
    local level = math.floor(row / 2) + 1
    local quest = (row % 2) + 1
    out:write(string.format("  %d %d   $%02X        $%02X        $%02X       $%02X\n",
                            level, quest,
                            dest_scene, dest_level, dest_room, pass_flags))
end
out:close()
print(string.format("dungeon_roundtrip_probe dump -> %s (rows_ok=%d/18 frame=%d)",
                    OUT_PATH, b[4], final_frame))
client.exit()
