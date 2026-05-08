-- probe_combined_debug_candle.lua
-- Auto-probe: A+B+C chord at boot to enter RoomRom, cycle Z 3x to
-- CANDLE, press B, watch $FF7280-3 diagnostic bytes.
-- Outputs C:\tmp\cd_candle_log.txt

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then memory.usememorydomain("Main RAM") end
end

local DBG = 0x7280
local fcount = 0
local out = "C:\\tmp\\cd_candle_log.txt"
local f = io.open(out, "w")
if f then f:write("frame,arrow_active,fire_active,s_b_item\n"); f:close() end

while true do
    local input = {}
    -- Frames 60..70: hold A+B+C to enter RoomRom from Title.
    if fcount >= 60 and fcount < 80 then
        input.A = true; input.B = true; input.C = true
    end
    -- Frames 200..205, 230..235, 260..265: press Z to cycle BOOMERANG
    -- -> ARROW -> BOMB -> CANDLE.
    if fcount == 200 or fcount == 201 then input.Z = true end
    if fcount == 230 or fcount == 231 then input.Z = true end
    if fcount == 260 or fcount == 261 then input.Z = true end
    -- Frame 320+: press B every 60 frames.
    if fcount >= 320 and ((fcount - 320) % 60) == 0 then input.B = true end
    if fcount >= 320 and ((fcount - 320) % 60) == 1 then input.B = true end
    joypad.set(input, 1)

    -- Log every 30 frames.
    if fcount % 30 == 0 then
        local arrow = memory.read_u8(DBG)
        local fire = memory.read_u8(DBG + 1)
        local b_item = memory.read_u8(DBG + 2)
        local f2 = io.open(out, "a")
        if f2 then
            f2:write(string.format("%d,%d,%d,%d\n", fcount, arrow, fire, b_item))
            f2:close()
        end
    end

    fcount = fcount + 1
    emu.frameadvance()
end
