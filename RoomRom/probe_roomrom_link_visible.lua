-- probe_roomrom_link_visible.lua
-- Boot RoomRom.md, exercise D-pad movement + clamp + scene toggle.
-- BizHawk Genesis core uses unprefixed button names ("B" not "P1 B").

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or ""
if OUT == "" or OUT == nil then OUT = "." end
local OUTDIR = OUT .. "/RoomRom/out"

local function wait(n)
    for _ = 1, n do
        emu.frameadvance()
    end
end

local function press(btn)
    for _ = 1, 3 do
        joypad.set({[btn] = true}, 1)
        emu.frameadvance()
    end
    joypad.set({}, 1)
    wait(60)
end

local function hold(btn, frames)
    for _ = 1, frames do
        joypad.set({[btn] = true}, 1)
        emu.frameadvance()
    end
    joypad.set({}, 1)
    wait(10)
end

wait(180)
client.screenshot(OUTDIR .. "/probe_link_00_spawn.png")

hold("Right", 60); client.screenshot(OUTDIR .. "/probe_link_01_walk_right.png")
hold("Down",  60); client.screenshot(OUTDIR .. "/probe_link_02_walk_down.png")
hold("Down", 240); client.screenshot(OUTDIR .. "/probe_link_03_clamp_bottom.png")
hold("Up",  300);  client.screenshot(OUTDIR .. "/probe_link_04_clamp_top.png")
press("B");        client.screenshot(OUTDIR .. "/probe_link_05_uw.png")

print("probe done")
client.exit()
