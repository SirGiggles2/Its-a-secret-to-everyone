-- Same dump for Gen at room $75. NES RAM mirror at $FF0000.
local OUT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms\\_gen_colheap_75.txt"
local STATE_FILE = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms\\_gen_state.State"
local BUS = 0xFF0000
local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

pcall(function() savestate.load(STATE_FILE) end)
for _=1,60 do emu.frameadvance() end

local log = {}
local function P(s) log[#log+1]=s end

P(string.format("RoomId($EB)=%02X", u8(BUS+0xEB)))
P(string.format("zp $00-$0F: %s", table.concat((function() local t={} for i=0,15 do t[#t+1]=string.format("%02X",u8(BUS+i)) end return t end)(), " ")))
P(string.format("zp $00E0-$00EF: %s", table.concat((function() local t={} for i=0xE0,0xEF do t[#t+1]=string.format("%02X",u8(BUS+i)) end return t end)(), " ")))

local p23 = u8(BUS+0x02) | (u8(BUS+0x03) << 8)
local p45 = u8(BUS+0x04) | (u8(BUS+0x05) << 8)
P(string.format("$02:$03 ptr (NES-space) = $%04X", p23))
P(string.format("$04:$05 ptr (NES-space) = $%04X", p45))

-- Gen caches P34h OW column ptr at $FF1106 and layout base at $FF1102.
-- 68K stored these via `move.l A_,(addr).l` (big-endian).
local function u32be(a)
    memory.usememorydomain("M68K BUS")
    return (memory.read_u8(a) << 24) | (memory.read_u8(a+1) << 16) | (memory.read_u8(a+2) << 8) | memory.read_u8(a+3)
end
local c1102 = u32be(BUS+0x1102)
local c1106 = u32be(BUS+0x1106)
P(string.format("P34 $FF1102 cache = $%08X", c1102))
P(string.format("P34 $FF1106 cache = $%08X", c1106))

P("")
P("Playmap rows 16-21 cols 2-15:")
for row = 16, 21 do
    local line = string.format("row%02d: ", row)
    for col = 2, 15 do
        line = line .. string.format("%02X ", u8(BUS + 0x6530 + row + col*22))
    end
    P(line)
end

-- Dump bytes from the column-ptr cache address (ROM or RAM).
local function dump_64(label, addr)
    P("")
    P(string.format("Bytes at %s ($%08X) + 0..63:", label, addr))
    for i = 0, 63, 16 do
        local line = string.format("  +%02X: ", i)
        for j = 0, 15 do
            line = line .. string.format("%02X ", u8(addr + i + j))
        end
        P(line)
    end
end
dump_64("P34 layout ptr ($FF1102)", c1102)
dump_64("P34 column ptr ($FF1106)", c1106)

local fh = io.open(OUT, "w")
fh:write(table.concat(log, "\n")); fh:write("\n")
fh:close()
client.exit()
