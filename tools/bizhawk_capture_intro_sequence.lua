-- bizhawk_capture_intro_sequence.lua
-- Captures a screenshot + per-frame trace line across the post-fade intro
-- story scroll window, for paired NES vs Genesis diffing.
--
-- ROM-agnostic: uses whatever BizHawk currently has loaded.
-- Label defaults from the active system unless INTRO_LABEL is set.

-- ============ CONFIG ============
local LABEL       = "gen"   -- "nes" or "gen" — change per run
local OUT_DIR     = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/intro_" .. LABEL
local START_FRAME = tonumber(os.getenv("INTRO_START_FRAME") or "850") or 850
local END_FRAME   = tonumber(os.getenv("INTRO_END_FRAME") or "3000") or 3000
-- ================================

local trace_path = OUT_DIR .. "/" .. LABEL .. "_trace.txt"
local trace_lines = {}

-- Detect system so we can decide which memory reads are valid.
-- On NES we only have NES RAM. On Genesis we additionally read VSRAM and 68K RAM.
local system = emu.getsystemid() or "?"
local is_genesis = (system == "GEN" or system == "SAT")  -- "GEN" for Genesis core
local ram_domain = nil
if is_genesis then
    local domains = {}
    for _, name in ipairs(memory.getmemorydomainlist()) do
        domains[name] = true
    end
    if domains["68K RAM"] then
        ram_domain = "68K RAM"
    elseif domains["M68K RAM"] then
        ram_domain = "M68K RAM"
    elseif domains["M68K BUS"] then
        ram_domain = "M68K BUS"
    end
end
local intro_label = os.getenv("INTRO_LABEL")
if intro_label and intro_label ~= "" then
    LABEL = intro_label
elseif LABEL == "gen" then
    LABEL = is_genesis and "gen" or "nes"
end
local intro_out_dir = os.getenv("INTRO_OUT_DIR")
if intro_out_dir and intro_out_dir ~= "" then
    OUT_DIR = intro_out_dir
else
    OUT_DIR = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/intro_" .. LABEL
end
trace_path = OUT_DIR .. "/" .. LABEL .. "_trace.txt"

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
    if not ram_domain then return 0xFF end
    if ram_domain == "M68K BUS" then
        off = addr
    end
    local ok, v = pcall(function() return memory.read_u8(off, ram_domain) end)
    return ok and v or 0xFF
end

local function rd_shared(addr)
    if is_genesis then
        return rd_68k(0xFF0000 + addr)
    end
    return rd_nes(addr)
end

local function rd_vsram_w0()
    local ok, v = pcall(function() return memory.read_u16_be(0, "VSRAM") end)
    return ok and v or 0xFFFF
end

local function emu_frame()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

-- Header
table.insert(trace_lines, string.format("# label=%s system=%s start=%d end=%d",
    LABEL, system, START_FRAME, END_FRAME))
table.insert(trace_lines, "# frame,gameMode,phase,subphase,curVScroll,curHScroll,ppuCtrl,switchReq,vsram0,ppuScrlX,ppuScrlY,demoLineTextIndex,demoNTWraps,lineCounter,lineAttrIndex,lineDstLo,lineDstHi,attrDstLo,attrDstHi,phase0Cycle,phase0Timer,transferBufSel,demoBusy,vsAddrHi58,vsAddrLoE2,sprite0Act,vsram40,hintQCount,hintQ0Ctr,hintQ0Vsram,hintPendSplit,introScrollMode,stagedMode,stagedHintCtr,stagedBase,stagedEvent,activeHintCtr,stagedSegment,activeSegment,activeBase,activeEvent")

while emu_frame() < END_FRAME do
    emu.frameadvance()
    local frame = emu_frame()

    if frame >= START_FRAME and frame <= END_FRAME then
        -- NES-side mirrors (valid on both NES core and on Genesis build since
        -- the transpiler preserves NES zero-page at the same offsets via the
        -- 6502 address map — if it doesn't, these read as 0xFF and the pixel
        -- diff still works).
        local gameMode  = rd_shared(0x12)
        local phase     = rd_shared(0x42C)
        local subphase  = rd_shared(0x42D)
        local curV      = rd_shared(0xFC)
        local curH      = rd_shared(0xFD)
        local ppuCtrl   = rd_shared(0xFF)
        local switchReq = rd_shared(0x5C)
        local demoText  = rd_shared(0x42E)
        local ntWraps   = rd_shared(0x415)
        local lineCount = rd_shared(0x41B)
        local lineAttr  = rd_shared(0x419)
        local lineDstLo = rd_shared(0x41C)
        local lineDstHi = rd_shared(0x41D)
        local attrDstLo = rd_shared(0x417)
        local attrDstHi = rd_shared(0x418)
        local phase0Cyc = rd_shared(0x437)
        local phase0Tmr = rd_shared(0x438)
        local bufSel    = rd_shared(0x14)
        local demoBusy  = rd_shared(0x11)
        local vsHi58    = rd_shared(0x58)   -- VScrollAddrHi (sprite-0 split bottom band)
        local vsLoE2    = rd_shared(0xE2)   -- VScrollAddrLo
        local spr0Act   = rd_shared(0xE3)   -- IsSprite0CheckActive

        -- Genesis-only extras.
        local vsram0   = -1
        local ppuScrlX = -1
        local ppuScrlY = -1
        local vsram40  = -1
        local hintQCnt = -1
        local hintQ0Ctr = -1
        local hintQ0Vsram = -1
        local hintPend = -1
        local introMode = -1
        local stagedMode = -1
        local stagedHint = -1
        local stagedBase = -1
        local stagedEvent = -1
        local activeHint = -1
        local stagedSegment = -1
        local activeSegment = -1
        local activeBase = -1
        local activeEvent = -1
        if is_genesis then
            vsram0   = rd_vsram_w0()
            ppuScrlX = rd_68k(0xFF0806)
            ppuScrlY = rd_68k(0xFF0807)
            -- Also read the 2nd VSRAM entry (for PLANE B or debug)
            local ok, v = pcall(function() return memory.read_u16_be(2, "VSRAM") end)
            vsram40 = ok and v or -1
            hintQCnt = rd_68k(0xFF0816)
            hintQ0Ctr = rd_68k(0xFF0817)
            local q0_addr = (ram_domain == "M68K BUS") and 0xFF0818 or 0x0818
            local sb_addr = (ram_domain == "M68K BUS") and 0xFF080C or 0x080C
            local se_addr = (ram_domain == "M68K BUS") and 0xFF080E or 0x080E
            local ab_addr = (ram_domain == "M68K BUS") and 0xFF0836 or 0x0836
            local ae_addr = (ram_domain == "M68K BUS") and 0xFF0838 or 0x0838
            local ok_q0, q0 = pcall(function() return memory.read_u16_be(q0_addr, ram_domain) end)
            hintQ0Vsram = ok_q0 and q0 or -1
            hintPend = rd_68k(0xFF081E)
            introMode = rd_68k(0xFF081F)
            stagedMode = rd_68k(0xFF080A)
            stagedHint = rd_68k(0xFF080B)
            local ok_sb, sb = pcall(function() return memory.read_u16_be(sb_addr, ram_domain) end)
            stagedBase = ok_sb and sb or -1
            local ok_se, se = pcall(function() return memory.read_u16_be(se_addr, ram_domain) end)
            stagedEvent = ok_se and se or -1
            activeHint = rd_68k(0xFF083A)
            stagedSegment = rd_68k(0xFF083B)
            activeSegment = rd_68k(0xFF083C)
            local ok_ab, ab = pcall(function() return memory.read_u16_be(ab_addr, ram_domain) end)
            activeBase = ok_ab and ab or -1
            local ok_ae, ae = pcall(function() return memory.read_u16_be(ae_addr, ram_domain) end)
            activeEvent = ok_ae and ae or -1
        end

        table.insert(trace_lines, string.format(
            "%d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%04X,%02X,%02X,%04X,%02X,%02X,%02X,%02X,%04X,%04X,%02X,%02X,%02X,%04X,%04X",
            frame, gameMode, phase, subphase, curV, curH, ppuCtrl, switchReq,
            vsram0 & 0xFFFF, ppuScrlX & 0xFF, ppuScrlY & 0xFF,
            demoText, ntWraps, lineCount, lineAttr, lineDstLo, lineDstHi,
            attrDstLo, attrDstHi, phase0Cyc, phase0Tmr, bufSel, demoBusy,
            vsHi58, vsLoE2, spr0Act, vsram40 & 0xFFFF,
            hintQCnt & 0xFF, hintQ0Ctr & 0xFF, hintQ0Vsram & 0xFFFF,
            hintPend & 0xFF, introMode & 0xFF, stagedMode & 0xFF,
            stagedHint & 0xFF, stagedBase & 0xFFFF, stagedEvent & 0xFFFF,
            activeHint & 0xFF, stagedSegment & 0xFF, activeSegment & 0xFF,
            activeBase & 0xFFFF, activeEvent & 0xFFFF
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
