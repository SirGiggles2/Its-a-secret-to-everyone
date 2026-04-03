-- bizhawk_nmi3_diag_probe.lua
-- Diagnose NMI #3 slowdown: where are the 64 frames going?
-- Uses exec hooks on key function entries to measure time per phase.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_nmi3_diag_probe.txt"

-- Key addresses from whatif.lst
local ADDR_ISRNMI           = 0x017A68   -- IsrNmi entry
local ADDR_TRANSFER_CUR_TB  = nil        -- TransferCurTileBuf (resolve below)
local ADDR_FTCB_ENTRY       = 0x0009DE   -- _transfer_chr_block_fast entry
local ADDR_TTF_ENTRY        = 0x000A9C   -- _transfer_tilebuf_fast entry
local ADDR_ENABLE_NMI       = nil        -- _L_z07_IsrNmi_EnableNMI (resolve below)

-- We'll use PC sampling to build a histogram per NMI
local CAPTURE_END = 300
local M68K = "M68K BUS"

local lines = {}
local function log(s) lines[#lines + 1] = s end

-- State tracking
local frame_count = 0
local nmi_count = 0
local nmi_entry_frame = 0
local current_nmi_pc_histogram = {}  -- PC_bucket -> frame_count
local nmi_logs = {}

-- PC range names for histogram
local function pc_range_name(pc)
    if pc >= 0x0009DE and pc < 0x000A9C then return "chr_block_fast" end
    if pc >= 0x000A9C and pc < 0x000C00 then return "tilebuf_fast" end
    if pc >= 0x000C00 and pc < 0x001000 then return "nes_io_other" end
    if pc >= 0x001000 and pc < 0x018000 then
        -- Zelda code ranges
        if pc >= 0x015000 and pc < 0x016000 then return "z_00_audio" end
        if pc >= 0x016000 and pc < 0x017000 then return "z_01" end
        if pc >= 0x017000 and pc < 0x017800 then return "z_02" end
        if pc >= 0x017800 and pc < 0x018000 then return "z_07_nmi" end
        return string.format("zelda_%04X", pc & 0xF000)
    end
    return string.format("other_%06X", pc)
end

-- Read helpers
local function rb(off) return memory.read_u8(0xFF0000 + off, M68K) end
local function rw(addr) return memory.read_u16_be(addr, M68K) end

-- NMI exec hook
local function on_isrnmi()
    -- Close previous NMI histogram
    if nmi_count > 0 and current_nmi_pc_histogram then
        local duration = frame_count - nmi_entry_frame
        local hist_str = ""
        -- Sort by frame count descending
        local sorted = {}
        for name, count in pairs(current_nmi_pc_histogram) do
            sorted[#sorted + 1] = { name = name, count = count }
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)
        for _, entry in ipairs(sorted) do
            hist_str = hist_str .. string.format("    %-20s %d frames (%.1f%%)\n",
                entry.name, entry.count, entry.count * 100.0 / math.max(duration, 1))
        end
        nmi_logs[#nmi_logs + 1] = string.format(
            "NMI #%d: frames %d-%d (%d frames)\n  F5=$%02X F6=$%02X initGame=$%02X mode=$%02X sub=$%02X isUpd=$%02X dynBuf0=$%02X tileBufSel=%d blk=%d\n  PC histogram:\n%s",
            nmi_count, nmi_entry_frame, frame_count - 1, duration,
            rb(0x00F5), rb(0x00F6), rb(0x00F4), rb(0x0012), rb(0x0013),
            rb(0x0011), rb(0x0302), rb(0x0014), rb(0x051D), hist_str
        )
    end

    nmi_count = nmi_count + 1
    nmi_entry_frame = frame_count
    current_nmi_pc_histogram = {}
end

event.onmemoryexecute(on_isrnmi, ADDR_ISRNMI, "isrnmi_hook", M68K)

-- Frame callback: sample PC and build histogram
local function on_frame()
    frame_count = frame_count + 1

    if nmi_count > 0 and current_nmi_pc_histogram then
        local ok, pc = pcall(function() return emu.getregister("M68K PC") end)
        if ok and pc then
            local range = pc_range_name(pc)
            current_nmi_pc_histogram[range] = (current_nmi_pc_histogram[range] or 0) + 1
        end
    end

    -- Also log raw PC for first few frames of each NMI for NMI #2 and #3
    if nmi_count >= 2 and nmi_count <= 3 then
        local age = frame_count - nmi_entry_frame
        if age <= 10 or age % 5 == 0 then
            local ok, pc = pcall(function() return emu.getregister("M68K PC") end)
            if ok and pc then
                log(string.format("  NMI#%d +%df: PC=$%06X F5=$%02X F6=$%02X dyn=$%02X blk=%d",
                    nmi_count, age, pc, rb(0x00F5), rb(0x00F6), rb(0x0302), rb(0x051D)))
            end
        end
    end

    if frame_count == CAPTURE_END then
        -- Close last NMI
        on_isrnmi()  -- triggers close of current histogram
        nmi_count = nmi_count - 1  -- undo the increment from the fake call

        log("=================================================================")
        log("NMI #3 Diagnostic Probe — " .. CAPTURE_END .. " frames")
        log("=================================================================")
        log("")
        log(string.format("Total NMI entries: %d", nmi_count))
        log("")

        for _, entry in ipairs(nmi_logs) do
            log(entry)
            log("")
        end

        log("--- Raw PC trace for NMI #2 and #3 ---")
        -- The raw logs are already in the lines table from the per-frame logging above

        log("")
        log("=================================================================")
        log("NMI3 DIAG PROBE COMPLETE")
        log("=================================================================")

        -- Write report
        local f = io.open(REPORT, "w")
        if f then
            f:write(table.concat(lines, "\n") .. "\n")
            f:close()
        end

        client.exit()
    end
end

event.onframeend(on_frame)
