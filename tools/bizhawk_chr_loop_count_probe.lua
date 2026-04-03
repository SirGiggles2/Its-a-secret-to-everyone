-- bizhawk_chr_loop_count_probe.lua
-- Count actual loop iterations in _transfer_chr_block_fast per NMI
-- to detect if tile/row count is wildly wrong.

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_chr_loop_count_probe.txt"
local M68K = "M68K BUS"

-- Addresses from whatif.lst
local ADDR_ISRNMI      = 0x017A68  -- IsrNmi entry
local ADDR_FTCB_ENTRY  = 0x0009DE  -- _transfer_chr_block_fast entry (movem.l push)
local ADDR_FTCB_TILE   = 0x0009EA  -- .ftcb_tile (tst.l D2)
local ADDR_FTCB_ROW    = 0x000A08  -- .ftcb_row (moveq #0,D3)
local ADDR_FTCB_DONE   = 0x000A70  -- .ftcb_done (move.w D1,(PPU_VADDR).l)
local ADDR_FTCB_RTS    = 0x000A7A  -- rts of _transfer_chr_block_fast

local CAPTURE_END = 200

local lines = {}
local function log(s) lines[#lines + 1] = s end

local frame_count = 0
local nmi_count = 0
local ftcb_call_count = 0     -- how many times _transfer_chr_block_fast is called per NMI
local ftcb_tile_count = 0     -- .ftcb_tile iterations per NMI
local ftcb_row_count = 0      -- .ftcb_row iterations per NMI
local ftcb_done_count = 0     -- .ftcb_done exits per NMI
local nmi_entry_frame = 0

local function rb(off) return memory.read_u8(0xFF0000 + off, M68K) end

-- Log NMI stats
local function close_nmi()
    if nmi_count > 0 then
        local duration = frame_count - nmi_entry_frame
        local tiles_per_frame = (ftcb_tile_count > 0 and duration > 0)
            and string.format("%.1f", ftcb_tile_count / duration) or "N/A"
        log(string.format(
            "NMI #%d: frames %d-%d (%d frames)  F5=$%02X F6=$%02X blk=%d",
            nmi_count, nmi_entry_frame, frame_count - 1, duration,
            rb(0x00F5), rb(0x00F6), rb(0x051D)))
        log(string.format(
            "  ftcb calls=%d  tile_iters=%d  row_iters=%d  done_exits=%d  tiles/frame=%s",
            ftcb_call_count, ftcb_tile_count, ftcb_row_count, ftcb_done_count, tiles_per_frame))
        if ftcb_tile_count > 0 then
            local expected_rows = ftcb_tile_count * 8
            log(string.format(
                "  rows/tile=%.2f (expected 8.0)  expected_tiles_274=%s",
                ftcb_row_count / ftcb_tile_count,
                ftcb_tile_count == 274 and "MATCH" or "MISMATCH"))
        end
        log("")
    end
end

-- Hooks
local function on_isrnmi()
    close_nmi()
    nmi_count = nmi_count + 1
    nmi_entry_frame = frame_count
    ftcb_call_count = 0
    ftcb_tile_count = 0
    ftcb_row_count = 0
    ftcb_done_count = 0
end

local function on_ftcb_entry()
    ftcb_call_count = ftcb_call_count + 1
    -- Log D2 (byte count) at entry
    local ok, d2 = pcall(function() return emu.getregister("M68K D2") end)
    if ok and d2 then
        log(string.format("  NMI#%d ftcb_entry: D2=$%08X (%d bytes, %d tiles) blk=%d frame=%d",
            nmi_count, d2, d2, math.floor(d2 / 16), rb(0x051D), frame_count))
    end
end

local function on_ftcb_tile() ftcb_tile_count = ftcb_tile_count + 1 end
local function on_ftcb_row()  ftcb_row_count = ftcb_row_count + 1 end
local function on_ftcb_done() ftcb_done_count = ftcb_done_count + 1 end

event.onmemoryexecute(on_isrnmi, ADDR_ISRNMI, "nmi_hook", M68K)
event.onmemoryexecute(on_ftcb_entry, ADDR_FTCB_ENTRY, "ftcb_entry", M68K)
event.onmemoryexecute(on_ftcb_tile, ADDR_FTCB_TILE, "ftcb_tile", M68K)
event.onmemoryexecute(on_ftcb_row, ADDR_FTCB_ROW, "ftcb_row", M68K)
event.onmemoryexecute(on_ftcb_done, ADDR_FTCB_DONE, "ftcb_done", M68K)

local function on_frame()
    frame_count = frame_count + 1
    if frame_count == CAPTURE_END then
        close_nmi()

        -- Write header
        table.insert(lines, 1, "=================================================================")
        table.insert(lines, 2, "CHR Loop Count Probe — " .. CAPTURE_END .. " frames")
        table.insert(lines, 3, "=================================================================")
        table.insert(lines, 4, string.format("Total NMI entries: %d", nmi_count))
        table.insert(lines, 5, "")

        lines[#lines + 1] = ""
        lines[#lines + 1] = "================================================================="
        lines[#lines + 1] = "CHR LOOP COUNT PROBE COMPLETE"
        lines[#lines + 1] = "================================================================="

        local f = io.open(REPORT, "w")
        if f then
            f:write(table.concat(lines, "\n") .. "\n")
            f:close()
        end
        client.exit()
    end
end

event.onframeend(on_frame)
