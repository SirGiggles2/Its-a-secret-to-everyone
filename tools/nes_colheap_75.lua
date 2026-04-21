-- Dump NES ColumnHeap bytes that LayoutRoomOrCaveOW reads for room $75.
-- Loads state, ensures we're at room $75, then reads:
--   * Unique room ID = NES_SRAM+$09FE+$75 (but that's SRAM — on NES
--     it lives at PPU/CPU $67FE area; let's read zp $00-$09 + working
--     ptrs $02:03 and $04:05 that LayoutRoomOrCaveOW uses).
--   * Pointers $02:$03 (room column directory) and $04:$05 (column ptr).
--
-- NES exposes WRAM + CHR + CIRAM. We want $02-$0F zp and then follow
-- the pointer into PRG ROM to dump ~64 bytes of column-heap data.

local OUT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms\\_nes_colheap_75.txt"
local STATE_FILE = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms\\_nes_state.State"

local function u8(a) memory.usememorydomain("System Bus"); return memory.read_u8(a) end

pcall(function() savestate.load(STATE_FILE) end)
for _=1,60 do emu.frameadvance() end

local log = {}
local function P(s) log[#log+1]=s end

P(string.format("RoomId($EB)=%02X  UniqueId($09FE+RID) in ROM", u8(0x00EB)))
P(string.format("zp $00-$0F: %s", table.concat((function() local t={} for i=0,15 do t[#t+1]=string.format("%02X",u8(i)) end return t end)(), " ")))
P(string.format("zp $00E0-$00EF: %s", table.concat((function() local t={} for i=0xE0,0xEF do t[#t+1]=string.format("%02X",u8(i)) end return t end)(), " ")))

-- Also dump $02:$03 ptr content from ROM. On NES, $02:$03 stores
-- room column directory address (16-bit). We can't easily follow a
-- PRG ROM pointer from Lua without mapper info, but at least log
-- the pointer value.
local p23 = u8(0x02) | (u8(0x03) << 8)
local p45 = u8(0x04) | (u8(0x05) << 8)
P(string.format("$02:$03 ptr = $%04X", p23))
P(string.format("$04:$05 ptr = $%04X", p45))

-- Dump playmap rows 16-19 cols 2-15 (where the bug shows up).
P("")
P("Playmap rows 16-19 cols 2-15 (col*22 + row):")
for row = 16, 21 do
    local line = string.format("row%02d: ", row)
    for col = 2, 15 do
        line = line .. string.format("%02X ", u8(0x6530 + row + col*22))
    end
    P(line)
end

local fh = io.open(OUT, "w")
fh:write(table.concat(log, "\n")); fh:write("\n")
fh:close()
client.exit()
