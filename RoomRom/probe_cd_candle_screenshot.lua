-- Capture screenshot at frame 350 (mid candle fire active per probe).
-- Plus mirror dump for diagnostic.

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then memory.usememorydomain("Main RAM") end
end

local DBG = 0x7280
local MIRROR = 0x7200
local fcount = 0
local out_log = "C:\\tmp\\cd_candle_screenshot_log.txt"
local f = io.open(out_log, "w")
if f then f:write("frame,scene,link_x_lo,link_y_lo,arrow,fire,b_item\n"); f:close() end

while fcount < 600 do
    local input = {}
    if fcount >= 60 and fcount < 80 then
        input.A = true; input.B = true; input.C = true
    end
    if fcount == 200 or fcount == 201 then input.Z = true end
    if fcount == 230 or fcount == 231 then input.Z = true end
    if fcount == 260 or fcount == 261 then input.Z = true end
    if fcount == 320 or fcount == 321 then input.B = true end
    if fcount == 400 or fcount == 401 then input.B = true end
    joypad.set(input, 1)

    -- Snapshots at frames 100, 200, 300, 350, 400, 500.
    if fcount == 100 or fcount == 300 or fcount == 350 or fcount == 405 then
        client.screenshot(string.format("C:\\tmp\\cd_candle_f%d.png", fcount))
    end

    if fcount % 30 == 0 then
        local scene = memory.read_u8(MIRROR + 4)
        local lx = memory.read_u8(MIRROR + 7)
        local ly = memory.read_u8(MIRROR + 9)
        local arrow = memory.read_u8(DBG)
        local fire = memory.read_u8(DBG + 1)
        local bi = memory.read_u8(DBG + 2)
        local f2 = io.open(out_log, "a")
        if f2 then
            f2:write(string.format("%d,%d,%d,%d,%d,%d,%d\n", fcount, scene, lx, ly, arrow, fire, bi))
            f2:close()
        end
    end

    fcount = fcount + 1
    emu.frameadvance()
end
print("done")
