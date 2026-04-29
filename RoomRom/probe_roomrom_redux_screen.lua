local png = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\roomrom_redux_screen.png"

local function frame(pad)
    joypad.set(pad or {}, 1)
    emu.frameadvance()
end

local function tap(button)
    local pad = {}
    pad[button] = true
    pad["P1 " .. button] = true
    for _ = 1, 8 do frame(pad) end
    for _ = 1, 8 do frame({}) end
end

for _ = 1, 120 do frame({}) end
tap("C")
tap("Right")
tap("Up")
tap("Up")
tap("Up")
tap("Up")
tap("Up")
for _ = 1, 30 do frame({}) end
client.screenshot(png)
client.exit()
