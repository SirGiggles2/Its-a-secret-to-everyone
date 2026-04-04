-- bizhawk_capture_intro_sequence.lua
-- Captures a screenshot + per-frame trace line across the post-fade intro
-- story scroll window, for paired NES vs Genesis diffing.
--
-- ROM-agnostic: uses whatever BizHawk currently has loaded.
-- Set LABEL/OUT_DIR per run (one NES run, one Genesis run).

-- ============ CONFIG ============
local LABEL       = "gen"   -- "nes" or "gen" — change per run
local OUT_DIR     = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/intro_" .. LABEL
local START_FRAME = 850
local END_FRAME   = 1500
-- ================================

local trace_path = OUT_DIR .. "/" .. LABEL .. "_trace.txt"
local trace_lines = {}
local frame = 0

-- Detect system so we can decide which memory reads are valid.
-- On NES we only have NES RAM. On Genesis we additionally read VSRAM and 68K RAM.
local system = emu.getsystemid() or "?"
local is_genesis = (system == "GEN" or system == "SAT")  -- "GEN" for Genesis core

local function rd_nes(addr)
    -- NES WRAM via mainmemory (zero-page + WRAM).
    local ok, v = pcall(function() return mainmemory.read_u8(addr) end)
    return ok and v or 0xFF
end

local function rd_68k(addr)
    -- Genesis 68K RAM domain covers $FF0000-$FFFFFF mapped as offsets
    -- 0..0xFFFF. PPU_STATE_BASE lives at $FF0800 → offset $0800.
    local off = addr - 0xFF0000
    if off < 0 or off > 0xFFFF then return 0xFF end
    local ok, v = pcall(function() return memory.read_u8(off, "68K RAM") end)
    return ok and v or 0xFF
end

local function rd_vsram_w0()
    local ok, v = pcall(function() return memory.read_u16_be(0, "VSRAM") end)
    return ok and v or 0xFFFF
end

-- Header
table.insert(trace_lines, string.format("# label=%s system=%s start=%d end=%d",
    LABEL, system, START_FRAME, END_FRAME))
table.insert(trace_lines, "# frame,gameMode,phase,subphase,curVScroll,curHScroll,ppuCtrl,switchReq,vsram0,ppuScrlX,ppuScrlY")

while frame <= END_FRAME do
    emu.frameadvance()
    frame = frame + 1

    if frame >= START_FRAME and frame <= END_FRAME then
        -- NES-side mirrors (valid on both NES core and on Genesis build since
        -- the transpiler preserves NES zero-page at the same offsets via the
        -- 6502 address map — if it doesn't, these read as 0xFF and the pixel
        -- diff still works).
        local gameMode  = rd_nes(0x12)
        local phase     = rd_nes(0x42C)
        local subphase  = rd_nes(0x42D)
        local curV      = rd_nes(0xFC)
        local curH      = rd_nes(0xFD)
        local ppuCtrl   = rd_nes(0xFF)
        local switchReq = rd_nes(0x5C)

        -- Genesis-only extras.
        local vsram0   = -1
        local ppuScrlX = -1
        local ppuScrlY = -1
        if is_genesis then
            vsram0   = rd_vsram_w0()
            ppuScrlX = rd_68k(0xFF0806)
            ppuScrlY = rd_68k(0xFF0807)
        end

        table.insert(trace_lines, string.format(
            "%d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%02X,%02X",
            frame, gameMode, phase, subphase, curV, curH, ppuCtrl, switchReq,
            vsram0 & 0xFFFF, ppuScrlX & 0xFF, ppuScrlY & 0xFF
        ))

        client.screenshot(OUT_DIR .. "/" .. LABEL .. "_f" .. string.format("%05d", frame) .. ".png")
    end
end

-- Write trace.
local f = io.open(trace_path, "w")
if f then
    f:write(table.concat(trace_lines, "\n") .. "\n")
    f:close()
end

client.exit()
