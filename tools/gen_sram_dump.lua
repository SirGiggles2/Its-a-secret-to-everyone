-- gen_sram_dump.lua — dump NES_SRAM contents after walking to $73, verify
-- LevelBlockAttrsF for rooms $70..$7F.

local OUT = "C:\\tmp\\_gen_sram_dump.txt"
local STATE_FILE = "C:\\tmp\\_gen_state.State"
pcall(function() savestate.load(STATE_FILE) end)

local NES_RAM = 0xFF0000
local NES_SRAM = 0xFF6000
local ROOM_ID = NES_RAM + 0xEB
local GAME_MODE = NES_RAM + 0x12

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local lines = {}
local function P(s) lines[#lines+1]=s; local fh=io.open(OUT,"w"); if fh then fh:write(table.concat(lines,"\n"));fh:write("\n");fh:close() end end

P("=== gen_sram_dump start ===")
local frame_n = 0
local dumped = false
while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local rid = u8(ROOM_ID)
    gui.text(10,10,string.format("room=$%02X frame=%d",rid,frame_n))
    if rid == 0x73 and not dumped then
        -- Wait for room $73 to settle
        if frame_n > 560 then
            P(string.format("[frame %d] At room $73, dumping SRAM regions:", frame_n))
            -- LevelBlockAttrsA at $687E, B at $68FE, C at $697E, D at $69FE, E at $6A7E, F at $6AFE
            -- Each is 128 bytes. Room $73 (index 115) within each is at offset $73.
            for tbl_idx, tbl_name in ipairs({"A","B","C","D","E","F"}) do
                local base = 0x687E + (tbl_idx-1)*128
                -- Dump the 16 bytes around room $73 (indices $70..$7F)
                local s = string.format("  LevelBlockAttrs_%s base=$%04X rooms $70..$7F:", tbl_name, base)
                for r = 0x70, 0x7F do
                    s = s .. string.format(" %02X", u8(NES_SRAM + (base - 0x6000) + r))
                end
                P(s)
            end
            -- Also dump raw SRAM $68xx-$6Bxx in 16-byte rows
            P("Raw SRAM $FF6A7E..$FF6B7E (LevelBlockAttrsE+F):")
            for off = 0x0A7E, 0x0B7E, 16 do
                local s = string.format("  $%04X:", off)
                for i = 0, 15 do s = s .. string.format(" %02X", u8(NES_SRAM + off + i)) end
                P(s)
            end
            dumped = true
        end
    end
    local joy = {}
    if rid ~= 0x73 and frame_n >= 40 then joy["Left"] = true end
    joypad.set(joy,1)
    if dumped and frame_n > 700 then break end
end
P("[done]")
