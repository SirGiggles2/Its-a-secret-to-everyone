-- check_enemies_present.lua — boot A+B+C, settle, dump NES enemy slot state + SAT.

local OUT = "C:\\tmp\\check_enemies"

local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end

local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end

idle(120)
press({A=true, B=true, C=true}, 30)
idle(600)  -- long settle so enemies are well-spawned

local f = io.open(OUT .. ".log", "w")
f:write("check_enemies_present — 2026-05-15\n")
f:write("====================================\n\n")
f:write("NES ENEMY slot state (slot 0 = Link, 1..11 = enemies):\n")
f:write("  slot  TYPE($034F+s)  ALIVE($0492+s)  X($0070+s)  Y($0084+s)\n")
local alive_count = 0
for s = 0, 11 do
    local t = nesram(0x034F + s)
    local a = nesram(0x0492 + s)
    local x = nesram(0x0070 + s)
    local y = nesram(0x0084 + s)
    f:write(string.format("  %2d    $%02X            $%02X             $%02X        $%02X\n", s, t, a, x, y))
    if a ~= 0 and s > 0 then alive_count = alive_count + 1 end
end
f:write(string.format("\nALIVE enemy count (slots 1..11): %d\n", alive_count))

-- SAT slot 10..30 entries that have on-playfield Y
f:write("\nSAT slots 10..30 (enemy bridge range):\n")
local sat_active = 0
for slot = 10, 30 do
    local base = 0xF400 + slot * 8
    local y_hi = memory.read_u8(base + 0, "VRAM")
    local y_lo = memory.read_u8(base + 1, "VRAM")
    local size = memory.read_u8(base + 2, "VRAM")
    local link = memory.read_u8(base + 3, "VRAM")
    local at_hi= memory.read_u8(base + 4, "VRAM")
    local at_lo= memory.read_u8(base + 5, "VRAM")
    local x_hi = memory.read_u8(base + 6, "VRAM")
    local x_lo = memory.read_u8(base + 7, "VRAM")
    local y = ((y_hi & 0x03) * 256) + y_lo
    local x = ((x_hi & 0x03) * 256) + x_lo
    local tile = ((at_hi & 0x07) * 256) + at_lo
    local active = (y > 32 and y < 240)
    f:write(string.format("  slot %2d  y=%4d x=%4d size=%02X link=%02X tile=%04X  %s\n",
        slot, y, x, size, link, tile, active and "ON-PLAYFIELD" or ""))
    if active then sat_active = sat_active + 1 end
end
f:write(string.format("\nSAT enemy slots with on-playfield Y: %d\n", sat_active))

-- room id
f:write(string.format("\nroom id ($00EB)  = $%02X\n", nesram(0x00EB)))
f:write(string.format("scene  ($0010)   = $%02X\n", nesram(0x0010)))

f:close()
client.screenshot(OUT .. ".png")
gui.text(8, 8, "check_enemies_present done")
client.exit()
