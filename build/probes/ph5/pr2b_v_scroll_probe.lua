-- pr2b_v_scroll_probe.lua
-- Verify PR-2b 64x32 + BG_B V scroll staging on CombinedDebug.
-- Boot path: A+B+C chord during frames 60-80 -> RoomRom UW.
-- Then idle until Link reachable, hold Down for ~60 frames to
-- trigger N/S V scroll, capture before/mid/after screenshots.

local out_dir = "C:\\tmp\\pr2b_proof"
os.execute("mkdir " .. out_dir .. " 2>nul")

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then memory.usememorydomain("Main RAM") end
end

local function dump_vram_word(byte_addr)
    local hi = memory.read_u8(byte_addr,     "VRAM")
    local lo = memory.read_u8(byte_addr + 1, "VRAM")
    return (hi * 256) + lo
end

local fcount = 0
local snapshots = {}
local snap_log = {}

local function log_snapshot(name)
    local entry = {
        name = name,
        frame = fcount,
        bg_a = dump_vram_word(0xC000),
        bg_b = dump_vram_word(0xE000),
        bg_a_mid = dump_vram_word(0xC000 + 32 * 14 * 2 + 16),  -- middle-ish row
    }
    snapshots[#snapshots + 1] = entry
    table.insert(snap_log, string.format(
        "[pr2b] %-12s f=%d  BG_A[0,0]=$%04X  BG_B[0,0]=$%04X  BG_A[mid]=$%04X",
        name, entry.frame, entry.bg_a, entry.bg_b, entry.bg_a_mid))
    print(snap_log[#snap_log])
    client.screenshot(out_dir .. "\\" .. name .. ".png")
end

while fcount < 400 do
    local input = {}
    -- Frames 60..80: A+B+C chord to skip Title -> RoomRom.
    if fcount >= 60 and fcount < 80 then
        input.A = true; input.B = true; input.C = true
    end
    -- Frames 200..240: hold Down to trigger V scroll south.
    if fcount >= 200 and fcount < 245 then
        input["P1 Down"] = true
        input.Down = true
    end
    joypad.set(input, 1)

    if fcount == 90 then  log_snapshot("post_boot") end
    if fcount == 180 then log_snapshot("uw_idle") end
    if fcount == 215 then log_snapshot("v_scroll_mid") end
    if fcount == 280 then log_snapshot("v_scroll_done") end

    fcount = fcount + 1
    emu.frameadvance()
end

local rep = io.open(out_dir .. "\\report.json", "w")
if rep then
    rep:write("{\n  \"snapshots\": [\n")
    for i, s in ipairs(snapshots) do
        rep:write(string.format(
            "    {\"name\":\"%s\",\"frame\":%d,\"bg_a\":\"0x%04X\",\"bg_b\":\"0x%04X\",\"bg_a_mid\":\"0x%04X\"}%s\n",
            s.name, s.frame, s.bg_a, s.bg_b, s.bg_a_mid,
            i == #snapshots and "" or ","))
    end
    rep:write("  ]\n}\n")
    rep:close()
end
print("[pr2b] DONE")
