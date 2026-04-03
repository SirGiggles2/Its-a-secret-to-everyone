-- bizhawk_record_parse_probe.lua
-- Hooks the record header parser to log PPU address of every record
-- Key addresses:
--   $0AB0 = .ttf_next_record (start of record parsing)
--   $0AB6 = move.b (A0)+,D0 (read first byte)
--   $0AB8 = bmi .ttf_done (terminator check)
--   $0AC2 = after D5 = PPU addr assembled (lsl.w #8,D5 + move.b)
--   $0AC8 = move.b (A0)+,D6 (read control byte)
--   $0B10 = dispatch start (cmpi.w #$2000,D5)

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_record_parse_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function get_reg(name)
    local ok, v = pcall(function() return emu.getregister(name) end)
    return ok and v or 0
end

local function bus_read(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

-- Track every record parsed
local records = {}
local terminator_info = {}
local done_hits = 0

-- Hook: right after PPU address is fully assembled and masked
-- $0AC4 = andi.w #$3FFF,D5 (this is where D5 has the final PPU address)
-- Actually let's hook at $0AC8 which is right after andi, where D5 = final PPU addr
event.onmemoryexecute(function()
    local d5 = get_reg("D5") & 0xFFFF
    local a0 = get_reg("A0")
    records[#records+1] = string.format("rec#%d PPU=$%04X A0=$%08X", #records+1, d5, a0)
end, 0x0AC8, "record_ppu_addr")

-- Hook: dispatch point to see D5 value entering dispatch
event.onmemoryexecute(function()
    local d5 = get_reg("D5") & 0xFFFF
    -- Append dispatch info to last record
    if #records > 0 then
        records[#records] = records[#records] .. string.format(" dispatch_D5=$%04X", d5)
    end
end, 0x0B10, "dispatch_d5")

-- Hook: .ttf_done to see what triggers termination
event.onmemoryexecute(function()
    done_hits = done_hits + 1
    local d0 = get_reg("D0")
    local a0 = get_reg("A0")
    terminator_info[#terminator_info+1] = string.format(
        "done#%d D0=$%02X A0=$%08X", done_hits, d0 & 0xFF, a0)
end, 0x0D2E, "ttf_done")  -- need to find the actual .ttf_done address

-- Hook: the bmi .ttf_done instruction at $0AB8
local bmi_hits = 0
local bmi_taken = {}
event.onmemoryexecute(function()
    bmi_hits = bmi_hits + 1
    local d0 = get_reg("D0") & 0xFF
    if d0 >= 0x80 then
        bmi_taken[#bmi_taken+1] = string.format("bmi#%d D0=$%02X (TERMINATOR)", bmi_hits, d0)
    end
end, 0x0AB8, "bmi_check")

-- Run 300 frames
for i = 1, 300 do emu.frameadvance() end

log("=================================================================")
log("Record Parse Probe — frame 300")
log("=================================================================")
log("")
log(string.format("Total records parsed: %d", #records))
log(string.format("bmi terminator checks: %d (taken: %d)", bmi_hits, #bmi_taken))
log("")
log("--- All parsed records ---")
for _, r in ipairs(records) do log("  " .. r) end

log("")
log("--- BMI terminator events ---")
if #bmi_taken == 0 then
    log("  (none)")
else
    for _, t in ipairs(bmi_taken) do log("  " .. t) end
end

log("")
log("--- .ttf_done events ---")
if #terminator_info == 0 then
    log("  (none)")
else
    for _, t in ipairs(terminator_info) do log("  " .. t) end
end

-- Also dump the raw bytes at the GameTitleTransferBuf to see attribute records
-- Find the address of GameTitleTransferBuf from the buffer pointer
log("")
log("--- GameTitleTransferBuf last 40 bytes (check attr records) ---")
-- Check what TransferBufPtrs points to
-- TransferBufPtrs is in z_06 data. Let's read from where we know the data is.
-- CurTileBufIdx = $FF0300, the actual buffer pointer is looked up from table
local bufIdx = bus_read(0xFF0300)
log(string.format("  CurTileBufIdx = $%02X", bufIdx))

-- Write
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("Record parse probe written to: " .. REPORT)
client.exit()
