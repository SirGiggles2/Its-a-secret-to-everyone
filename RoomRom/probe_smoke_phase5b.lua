-- Phase 5 OW + UW smoke: capture UW default, then MODE+B for OW.
local OUT_UW   = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY-roomrom-s1\\RoomRom\\out\\phase5_uw_orig.png"
local OUT_OW   = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY-roomrom-s1\\RoomRom\\out\\phase5_ow_orig.png"
local OUT_DONE = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY-roomrom-s1\\RoomRom\\out\\phase5_done.txt"

local function settle(n)
    for _ = 1, n do joypad.set({}, 1); emu.frameadvance() end
end

local function press_combo(buttons, hold, release)
    local pad = {}
    for _, b in ipairs(buttons) do
        pad[b] = true
        pad["P1 " .. b] = true
    end
    for _ = 1, hold do joypad.set(pad, 1); emu.frameadvance() end
    settle(release or 8)
end

settle(180)
client.screenshot(OUT_UW)

-- MODE+B = scene toggle UW -> OW
press_combo({"Mode", "B"}, 4, 30)
settle(30)
client.screenshot(OUT_OW)

local f = io.open(OUT_DONE, "w")
if f then f:write("done"); f:close() end
client.exit()
