-- bizhawk_phantom_diag_probe.lua
-- Hooks _transfer_chr_block_fast and logs caller info when D2=$0040
-- Also logs DynTileBuf sentinel ($0302) and buffer pointer

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_phantom_diag_probe.txt"
local M68K = "M68K BUS"
local FRAMES_TO_RUN = 200

-- ROM addresses (from whatif.lst, current build)
local ADDR_FTCB_ENTRY  = 0x0009E4   -- _transfer_chr_block_fast (movem.l)
local ADDR_ISR_NMI     = 0x017F54   -- IsrNmi
local NES_RAM          = 0xFF0000

local lines = {}
local function log(s) lines[#lines+1] = s end

log("=================================================================")
log("Phantom D2=$40 Diagnostic Probe — " .. FRAMES_TO_RUN .. " frames")
log("=================================================================")

local nmi_count = 0
local frame_count = 0
local phantom_count = 0
local legit_count = 0
local phantom_log_limit = 60
local legit_log_limit = 15

-- Per-NMI stats
local cur_nmi_phantoms = 0
local cur_nmi_legit = 0
local nmi_summaries = {}

local function rb(off) return memory.read_u8(NES_RAM + off, M68K) end

local function close_nmi()
    if nmi_count > 0 and (cur_nmi_phantoms > 0 or cur_nmi_legit > 0) then
        nmi_summaries[#nmi_summaries+1] = string.format(
            "  NMI#%d (ended ~f%d): %d legit blocks, %d phantom blocks",
            nmi_count, frame_count, cur_nmi_legit, cur_nmi_phantoms)
    end
end

-- Hook IsrNmi
local function on_isrnmi()
    close_nmi()
    nmi_count = nmi_count + 1
    cur_nmi_phantoms = 0
    cur_nmi_legit = 0
    log(string.format("--- NMI #%d at frame %d ---", nmi_count, frame_count))
end

-- Hook _transfer_chr_block_fast entry
local function on_ftcb_entry()
    local d2 = emu.getregister("M68K D2")
    local a0 = emu.getregister("M68K A0")
    local sp = emu.getregister("M68K A7")

    -- Return address is at top of stack (before movem pushes)
    -- Actually, at entry we're AT the movem, BSR already pushed return addr
    -- But movem hasn't executed yet, so SP still points to return address
    -- Wait: we're hooked at the movem instruction, but BSR pushed the return
    -- address before we got here. So (SP) = return address.
    local ret_addr = memory.read_u32_be(sp, M68K)

    local sentinel = rb(0x0302)
    local buf_idx = rb(0x0014)
    local buf_ptr = rb(0x0001) * 256 + rb(0x0000)

    if d2 == 0x0040 or d2 == 0x00000040 then
        phantom_count = phantom_count + 1
        cur_nmi_phantoms = cur_nmi_phantoms + 1
        if phantom_count <= phantom_log_limit then
            log(string.format(
                "  PHANTOM #%03d f%03d NMI#%d  D2=$%08X  A0=$%08X  ret=$%06X  sent=$%02X  idx=$%02X  ptr=$%04X",
                phantom_count, frame_count, nmi_count, d2, a0, ret_addr, sentinel, buf_idx, buf_ptr))
        end
    else
        legit_count = legit_count + 1
        cur_nmi_legit = cur_nmi_legit + 1
        if legit_count <= legit_log_limit then
            log(string.format(
                "  LEGIT   f%03d NMI#%d  D2=$%08X  A0=$%08X  ret=$%06X  sent=$%02X  idx=$%02X  ptr=$%04X",
                frame_count, nmi_count, d2, a0, ret_addr, sentinel, buf_idx, buf_ptr))
        end
    end
end

event.onmemoryexecute(on_isrnmi, ADDR_ISR_NMI, "nmi_hook", M68K)
event.onmemoryexecute(on_ftcb_entry, ADDR_FTCB_ENTRY, "ftcb_hook", M68K)

local function on_frame()
    frame_count = frame_count + 1
    if frame_count >= FRAMES_TO_RUN then
        close_nmi()

        log("")
        log("=================================================================")
        log("SUMMARY")
        log("=================================================================")
        log(string.format("  Total NMIs: %d", nmi_count))
        log(string.format("  Total legit calls: %d", legit_count))
        log(string.format("  Total phantom D2=$40 calls: %d", phantom_count))
        log(string.format("  Frames: %d", frame_count))
        log("")
        for _, s in ipairs(nmi_summaries) do log(s) end

        -- Dump DynTileBuf
        log("")
        log("DynTileBuf ($0302) dump at frame " .. frame_count .. ":")
        local hex = "  "
        for i = 0, 31 do
            hex = hex .. string.format("%02X ", rb(0x0302 + i))
            if i % 16 == 15 then
                log(hex)
                hex = "  "
            end
        end

        local fh = io.open(REPORT, "w")
        for _, line in ipairs(lines) do fh:write(line .. "\n") end
        fh:close()
        print("Phantom diag probe written to: " .. REPORT)
        client.exit()
    end
end

event.onframeend(on_frame)

-- Keep alive
while true do
    emu.frameadvance()
end
