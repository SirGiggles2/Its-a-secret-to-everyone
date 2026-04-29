-- One-shot: load RoomRom.md, wait 120 frames, screenshot
local rom = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\RoomRom.md"
local png = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\roomrom_screen.png"

-- Wait for VDP to settle then capture
local frame = 0
event.onframeend(function()
    frame = frame + 1
    if frame == 120 then
        client.screenshot(png)
        print("Screenshot saved: " .. png)
        client.exit()
    end
end)
