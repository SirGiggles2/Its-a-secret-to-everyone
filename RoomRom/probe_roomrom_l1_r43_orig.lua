-- Genesis-side probe: nav to L1 room $43 in ORIG map; screenshot for compare.
local OUT_PNG = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\roomrom_l1_r43_orig.png"

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end
local function press(button, hold, release)
    hold = hold or 2; release = release or 8
    for _ = 1, hold do
        safe_set({[button] = true, ["P1 " .. button] = true}); emu.frameadvance()
    end
    for _ = 1, release do safe_set({}); emu.frameadvance() end
end
local function settle(frames)
    for _ = 1, (frames or 30) do safe_set({}); emu.frameadvance() end
end

settle(120)
press("B", 2, 30)            -- SCENE_OW -> UW; map stays ORIG
press("Right", 2, 12)
press("Right", 2, 12)
press("Right", 2, 12)
press("Down",  2, 12)
press("Down",  2, 12)
press("Down",  2, 12)
press("Down",  2, 12)
settle(60)
client.screenshot(OUT_PNG)
client.exit()
