-- Viewer: spawn Goriya $05, leave emulator open for user.
-- Re-arms force-spawn every 5 seconds so killed/scrolled-off Goriya
-- respawns. Overlays slot info.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

-- Boot.
idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

-- Initial spawn.
local function spawn_goriya()
    W(0x77D0, 0x46) W(0x77D1, 0x58)
    W(0x77D2, 0x05)         -- Blue Goriya
    W(0x77D3, 0x80)         -- X
    W(0x77D4, 0x78)         -- Y
    W(0x77D5, 0x01)         -- dir
    W(0x77D6, 0x01)         -- slot
    W(0x77D7, 0x00)         -- habitat OW
    W(0x77D8, 0x77)         -- room
end

spawn_goriya()
emu.frameadvance()
W(0x77D0, 0)
W(0x77D1, 0)

-- Random poke once.
W(0x8018, 0x40)
for i = 1, 12 do W(0x8018 + i, 0x00) end

-- Run forever, overlay state.
local frame_counter = 0
while true do
    -- HUD overlay.
    local g_type = R(0x834F + 1)
    if g_type == 0 then
        spawn_goriya()
        emu.frameadvance()
        W(0x77D0, 0)
        W(0x77D1, 0)
    end

    local boom_slot = 0
    for s = 2, 11 do
        if R(0x834F + s) == 0x5C then boom_slot = s; break end
    end

    gui.text(8, 8,  string.format("Goriya s1 T:%02X X:%02X Y:%02X D:%02X St:%02X",
        R(0x834F+1), R(0x8070+1), R(0x8084+1), R(0x8098+1), R(0x80AC+1)))
    if boom_slot > 0 then
        gui.text(8, 20, string.format("BOOMERANG s%d X:%02X Y:%02X State:%02X ML:%02X",
            boom_slot, R(0x8070+boom_slot), R(0x8084+boom_slot),
            R(0x80AC+boom_slot), R(0x8380+boom_slot)))
    else
        gui.text(8, 20, "no boomerang active")
    end

    emu.frameadvance()
    frame_counter = frame_counter + 1
end
