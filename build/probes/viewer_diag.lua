-- Diagnostic viewer. Spawns $05 Goriya, displays ALL slot types,
-- saves a screenshot every 60 frames to C:\tmp\diag_NNN.png.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

-- Spawn $05 Blue Goriya at slot 1.
local function spawn()
    W(0x77D0, 0x46) W(0x77D1, 0x58)
    W(0x77D2, 0x05) W(0x77D3, 0x80) W(0x77D4, 0x78)
    W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
end
spawn()
emu.frameadvance()
W(0x77D0, 0); W(0x77D1, 0)

W(0x8018, 0x40)
for i = 1, 12 do W(0x8018 + i, 0x00) end

local frame = 0
local shot_taken = false
while true do
    -- HUD: all slot types.
    for s = 1, 11 do
        local t = R(0x834F + s)
        local x = R(0x8070 + s)
        local y = R(0x8084 + s)
        local st = R(0x80AC + s)
        gui.text(8, s * 10, string.format("s%2d T:%02X X:%02X Y:%02X St:%02X", s, t, x, y, st))
    end

    if frame == 30 and not shot_taken then
        client.screenshot("C:/tmp/diag_30.png")
    end
    if frame == 90 and frame > 0 then
        client.screenshot("C:/tmp/diag_90.png")
    end
    if frame == 180 then
        client.screenshot("C:/tmp/diag_180.png")
        shot_taken = true
    end

    -- Re-spawn if slot 1 emptied.
    if R(0x834F + 1) == 0 then
        spawn()
        emu.frameadvance()
        W(0x77D0, 0); W(0x77D1, 0)
    end

    emu.frameadvance()
    frame = frame + 1
end
