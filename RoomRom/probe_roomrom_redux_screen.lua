local png = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\roomrom_redux_screen.png"

local function frame(pad)
    joypad.set(pad or {}, 1)
    emu.frameadvance()
end

local pad = { C = true, ["P1 C"] = true }
for _ = 1, 120 do frame({}) end
for _ = 1, 8 do frame(pad) end
for _ = 1, 30 do frame({}) end
client.screenshot(png)
client.exit()
