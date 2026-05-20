-- Phase D2: Genesis VRAM + CRAM capture for Goriya tile diagnosis.
-- Spawns $05 Blue Goriya, dumps VRAM tile slots for Goriya + Octorok
-- + paired bottom halves, plus CRAM PAL1 sprite sub-palette.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function VRAM(o) return memory.read_u8(o, "VRAM") end
local function CRAM(o) return memory.read_u8(o, "CRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

-- Boot through to ROOMROM mode.
idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

-- Spawn Goriya at slot 1.
W(0x77D0, 0x46) W(0x77D1, 0x58)
W(0x77D2, 0x05) W(0x77D3, 0x80) W(0x77D4, 0x78)
W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
emu.frameadvance()
idle(20)

local f = io.open("C:/tmp/audit_chr_gen.txt", "w")

f:write("# Genesis CHR/VRAM/CRAM diagnostic\n")
f:write(string.format("# slot 1 type=$%02X X=$%02X Y=$%02X\n",
    R(0x834F+1), R(0x8070+1), R(0x8084+1)))
f:write("\n")

-- Compute VRAM byte offset per tile (32 bytes/tile, 4bpp Genesis).
local function tile_offset(tile_idx) return tile_idx * 32 end

-- Tiles we want to inspect.
-- Goriya frame 0 NES tile = $B8 → VRAM = 1069 + ($B8-$8E) = 1111
-- Bottom half (NES 8x16 pair) = $B9 → VRAM = 1112 in Genesis remap.
-- Octorok frame 0 NES tile = $B4 → VRAM = 1069 + ($B4-$8E) = 1107
-- Octorok bottom = $B5 → VRAM = 1108
local tiles_to_dump = {
    {name="VRAM 1107 (NES $B4 - Octorok top)",   vram=1107},
    {name="VRAM 1108 (NES $B5 - Octorok bot)",   vram=1108},
    {name="VRAM 1111 (NES $B8 - Goriya top)",    vram=1111},
    {name="VRAM 1112 (NES $B9 - Goriya bot)",    vram=1112},
    {name="VRAM 1069 (NES $8E - OWSP first)",    vram=1069},
    {name="VRAM 1182 (NES $FF - OWSP last)",     vram=1182},
}

for _, t in ipairs(tiles_to_dump) do
    f:write(string.format("=== %s ===\n", t.name))
    local base = tile_offset(t.vram)
    for row = 0, 7 do
        local line = string.format("row%d:", row)
        for col = 0, 3 do
            line = line .. string.format(" %02X", VRAM(base + row*4 + col))
        end
        f:write(line .. "\n")
    end
    f:write("\n")
end

-- CRAM PAL1 (sprite palette) — entries 16..31 (PAL1 starts at index 16 = byte 32).
f:write("=== CRAM PAL1 (sprite palette) entries 0..15 ===\n")
for i = 0, 15 do
    local lo = CRAM(32 + i*2)
    local hi = CRAM(32 + i*2 + 1)
    f:write(string.format("PAL1[%2d] = %02X%02X\n", i, hi, lo))
end

-- SAT slot inspection. Genesis SAT at $F800 in VRAM.
-- Each entry: 8 bytes (Y, sizeLinkAddr, attr, X).
f:write("\n=== Genesis SAT slots 1..10 ===\n")
for s = 1, 10 do
    local sat_off = 0xF800 + s*8
    local y_hi = VRAM(sat_off)
    local y_lo = VRAM(sat_off + 1)
    local size_link = VRAM(sat_off + 2)
    local link_lo = VRAM(sat_off + 3)
    local attr_hi = VRAM(sat_off + 4)
    local attr_lo = VRAM(sat_off + 5)
    local x_hi = VRAM(sat_off + 6)
    local x_lo = VRAM(sat_off + 7)
    local tile_id = ((attr_hi & 0x07) << 8) | attr_lo
    f:write(string.format("SAT[%2d] Y=%04X sz/link=%02X/%02X attr=%02X tile=%4d X=%04X\n",
        s, (y_hi<<8)|y_lo, size_link, link_lo, attr_hi, tile_id, (x_hi<<8)|x_lo))
end

client.screenshot("C:/tmp/audit_chr_gen.png")
f:close()
client.exit()
